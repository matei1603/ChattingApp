import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';

class CryptoService {
  static final _secureStorage = FlutterSecureStorage();
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> initializeKeys(String userId) async {
    print('🔐 Called initializeKeys for $userId');

    final privateKey = await _secureStorage.read(key: 'privateKey');
    final publicKey = await _secureStorage.read(key: 'publicKey');
    final doc = await _firestore.collection('users').doc(userId).get();
    final firestoreKey = doc.data()?['rsaPublicKey'];

    print('🔍 Keys exist? Private: ${privateKey != null}, Public: ${publicKey != null}, Firestore: ${firestoreKey != null}');

    if (privateKey == null || publicKey == null) {
      final pair = CryptoUtils.generateRSAKeyPair();
      final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(pair.privateKey as RSAPrivateKey);
      final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(pair.publicKey as RSAPublicKey);

      await _secureStorage.write(key: 'privateKey', value: privatePem);
      await _secureStorage.write(key: 'publicKey', value: publicPem);

      try {
        await _firestore.collection('users').doc(userId).set({
          'rsaPublicKey': publicPem,
        }, SetOptions(merge: true));
        print('✅ RSA public key saved to Firestore for $userId');
      } catch (e) {
        print('❌ Failed to save RSA key: $e');
      }
    } else if (firestoreKey == null && publicKey != null) {
      try {
        await _firestore.collection('users').doc(userId).set({
          'rsaPublicKey': publicKey,
        }, SetOptions(merge: true));
        print('✅ Missing RSA public key re-added to Firestore');
      } catch (e) {
        print('❌ Failed to re-sync RSA key: $e');
      }
    } else {
      print('✅ All RSA keys are present');
    }
  }

  static Future<String> encrypt(String plaintext, String recipientId) async {
    try {
      final aesKey = Key.fromSecureRandom(32);
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(aesKey));
      final encryptedData = encrypter.encrypt(plaintext, iv: iv).base64;

      final doc = await _firestore.collection('users').doc(recipientId).get();
      final publicKeyPem = doc.data()?['rsaPublicKey'];
      if (publicKeyPem == null || publicKeyPem.trim().isEmpty) {
        throw Exception('Recipient public key not found');
      }

      final rsaPublic = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
      final encryptedKey = base64Encode(_rsaEncryptToBytes(aesKey.base64, rsaPublic));
      final encryptedIv = base64Encode(_rsaEncryptToBytes(iv.base64, rsaPublic));

      final payload = {
        'key': encryptedKey,
        'iv': encryptedIv,
        'data': encryptedData,
      };

      return base64Encode(utf8.encode(jsonEncode(payload)));
    } catch (e) {
      print("❌ Encryption failed: $e");
      throw Exception("Encryption failed");
    }
  }

  static Future<Map<String, dynamic>> encryptForGroup(String plaintext, List<String> memberIds) async {
    print("🧪 encryptForGroup called with members: $memberIds");
    final aesKey = Key.fromSecureRandom(32);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(aesKey));
    final encryptedMessage = encrypter.encrypt(plaintext, iv: iv).base64;

    final Map<String, Map<String, String>> keysMap = {};

    for (final memberId in memberIds) {
      final doc = await _firestore.collection('users').doc(memberId).get();
      final publicKeyPem = doc.data()?['rsaPublicKey'];
      if (publicKeyPem == null || publicKeyPem.trim().isEmpty) {
        print("❌ RSA key missing for $memberId");
        continue; // Skip encryption for this user
      }

      final rsaPublic = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
      final encryptedKey = base64Encode(_rsaEncryptToBytes(aesKey.base64, rsaPublic));
      final encryptedIv = base64Encode(_rsaEncryptToBytes(iv.base64, rsaPublic));

      keysMap[memberId] = {
        'key': encryptedKey,
        'iv': encryptedIv,
      };
    }

    return {
      'data': encryptedMessage,
      'keys': keysMap,
    };
  }

  static Future<String> decryptText(String encryptedBase64) async {
    try {
      final jsonString = utf8.decode(base64Decode(encryptedBase64));
      final Map<String, dynamic> payload = jsonDecode(jsonString);

      final encryptedKey = payload['key'];
      final encryptedIv = payload['iv'];
      final encryptedData = payload['data'];

      final privateKeyPem = await _secureStorage.read(key: 'privateKey');
      if (privateKeyPem == null) throw Exception("Private RSA key not found");

      final rsaPrivate = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
      final decryptedKey = _rsaDecryptFromBytes(base64Decode(encryptedKey), rsaPrivate);
      final decryptedIv = _rsaDecryptFromBytes(base64Decode(encryptedIv), rsaPrivate);

      final aesKey = Key.fromBase64(decryptedKey);
      final iv = IV.fromBase64(decryptedIv);
      final encrypter = Encrypter(AES(aesKey));
      return encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      print("❌ Decryption failed: $e");
      return '[Invalid Encrypted Text]';
    }
  }

  static Future<String> decryptGroupMessage(Map<String, dynamic> wrapper, String userId) async {
    try {
      final encryptedBase64 = wrapper['data'];
      final keys = wrapper['keys'];
      final userKey = keys[userId];

      if (userKey == null) throw Exception("No encryption key for user $userId");

      final encryptedKeyB64 = userKey['key'];
      final encryptedIvB64 = userKey['iv'];

      final privateKeyPem = await _secureStorage.read(key: 'privateKey');
      if (privateKeyPem == null) throw Exception("Private key not found");

      final rsaPrivate = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
      final decryptedKey = _rsaDecryptFromBytes(base64Decode(encryptedKeyB64), rsaPrivate);
      final decryptedIv = _rsaDecryptFromBytes(base64Decode(encryptedIvB64), rsaPrivate);

      final aesKey = Key.fromBase64(decryptedKey);
      final iv = IV.fromBase64(decryptedIv);
      final encrypter = Encrypter(AES(aesKey));
      return encrypter.decrypt64(encryptedBase64, iv: iv);
    } catch (e) {
      print("❌ Decryption failed: $e");
      return '[Invalid Encrypted Text]';
    }
  }

  static Uint8List _rsaEncryptToBytes(String data, RSAPublicKey publicKey) {
    final encryptor = RSAEngine()
      ..init(true, pc.PublicKeyParameter<RSAPublicKey>(publicKey));
    return Uint8List.fromList(encryptor.process(utf8.encode(data)));
  }

  static String _rsaDecryptFromBytes(Uint8List cipherBytes, RSAPrivateKey privateKey) {
    final decryptor = RSAEngine()
      ..init(false, pc.PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return utf8.decode(decryptor.process(cipherBytes));
  }

  static bool isProbablyEncrypted(String text) {
    final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    return base64Regex.hasMatch(text) && text.length > 100;
  }
}

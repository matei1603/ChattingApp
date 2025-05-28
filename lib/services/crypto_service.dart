import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pointycastle/asymmetric/api.dart';

class CryptoService {
  static final _secureStorage = FlutterSecureStorage();
  static final _firestore = FirebaseFirestore.instance;

  /// Call this after sign-up or login to ensure keys exist
  static Future<void> initializeKeys(String userId) async {
    print(' Called initializeKeys for $userId');

    final privateKey = await _secureStorage.read(key: 'privateKey');
    final publicKey = await _secureStorage.read(key: 'publicKey');
    final doc = await _firestore.collection('users').doc(userId).get();
    final firestoreKey = doc.data()?['rsaPublicKey'];

    print(' Keys exist? Private: ${privateKey != null}, Public: ${publicKey != null}, Firestore: ${firestoreKey != null}');

    // Regenerate if missing locally or in Firestore
    if (privateKey == null || publicKey == null || firestoreKey == null) {
      final pair = CryptoUtils.generateRSAKeyPair();
      final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(pair.privateKey as RSAPrivateKey);
      final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(pair.publicKey as RSAPublicKey);

      await _secureStorage.write(key: 'privateKey', value: privatePem);
      await _secureStorage.write(key: 'publicKey', value: publicPem);

      try {
        await _firestore.collection('users').doc(userId).set({
          'rsaPublicKey': publicPem,
        }, SetOptions(merge: true));
        print(' RSA public key saved to Firestore for $userId');
      } catch (e) {
        print(' Failed to save RSA key: $e');
      }
    }
  }

  /// Encrypts a message using AES and encrypts the AES key/IV using RSA
  static Future<String> encrypt(String plaintext, String recipientId) async {
    final aesKey = Key.fromSecureRandom(32); // 256-bit
    final iv = IV.fromSecureRandom(16); // 128-bit
    final encrypter = Encrypter(AES(aesKey));
    final encryptedData = encrypter.encrypt(plaintext, iv: iv).base64;

    final doc = await _firestore.collection('users').doc(recipientId).get();
    final publicKeyPem = doc.data()?['rsaPublicKey'];
    if (publicKeyPem == null) throw Exception('Recipient public key not found');

    final rsaPublic = CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);
    final encryptedKey = CryptoUtils.rsaEncrypt(aesKey.base64, rsaPublic);
    final encryptedIv = CryptoUtils.rsaEncrypt(iv.base64, rsaPublic);

    final payload = {
      'key': encryptedKey,
      'iv': encryptedIv,
      'data': encryptedData,
    };

    return base64Encode(utf8.encode(jsonEncode(payload)));
  }

  /// Decrypts a hybrid-encrypted payload using private RSA key and AES
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
      final decryptedKey = CryptoUtils.rsaDecrypt(encryptedKey, rsaPrivate);
      final decryptedIv = CryptoUtils.rsaDecrypt(encryptedIv, rsaPrivate);

      final aesKey = Key.fromBase64(decryptedKey);
      final iv = IV.fromBase64(decryptedIv);
      final encrypter = Encrypter(AES(aesKey));

      return encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      print("Decryption failed: $e");
      return '[Invalid Encrypted Text]';
    }
  }

  /// Helps determine whether a message is encrypted
  static bool isProbablyEncrypted(String text) {
    final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    return base64Regex.hasMatch(text) && text.length > 100;
  }
}

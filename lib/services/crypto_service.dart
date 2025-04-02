import 'package:encrypt/encrypt.dart';

class CryptoService {
  static final _key = Key.fromUtf8('12345678901234567890123456789012'); // 32 chars for AES-256
  static final _iv = IV.fromUtf8('1234567890123456'); // 16 chars for AES

  static final _encrypter = Encrypter(AES(_key));

  static String encrypt(String input) {
    return _encrypter.encrypt(input, iv: _iv).base64;
  }

  static String decryptText(String encrypted) {
    try {
      // Skip empty or obviously unencrypted values
      if (encrypted.trim().isEmpty || !isProbablyEncrypted(encrypted)) {
        return encrypted;
      }

      return _encrypter.decrypt64(encrypted, iv: _iv);
    } catch (e) {
      return '[Invalid Encrypted Text]';
    }
  }
  static bool isProbablyEncrypted(String text) {
    final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    return base64Regex.hasMatch(text) && text.length >= 24;
  }
}

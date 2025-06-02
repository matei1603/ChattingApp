import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'crypto_service.dart';

Future<void> _saveUserToFirestore(User user, String name) async {
  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

  await userRef.set({
    "name": name,
    "email": user.email,
    "profilePicture": user.photoURL ?? "",
    "contacts": [],
    "createdAt": FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String getCurrentUserEmail() {
    return _auth.currentUser?.email ?? '';
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      if (user != null) {
        try {
          // Try to restore private key from cloud
          await CryptoService.restorePrivateKeyFromCloud(user.uid, password);
        } catch (e) {
          print("❌ Failed to restore private key: $e");
          rethrow; // or handle fallback if you want
        }

        await CryptoService.initializeKeys(user.uid);
      }

      return user;
    } catch (e) {
      throw e;
    }
  }

  // Register with email and password
  Future<User?> signUp(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await _saveUserToFirestore(user, name);

        // Generate and store RSA keys (and upload encrypted private key)
        await CryptoService.generateAndStoreKeys(user.uid, password);
      }

      return user;
    } catch (e) {
      throw e;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's email
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
      return userCredential.user;
    } catch (e) {
      throw e; // Re-throw the error to handle it in the UI
    }
  }

  // Register with email and password
  Future<User?> signUp(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      return userCredential.user;
    } catch (e) {
      throw e; // Re-throw the error to handle it in the UI
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

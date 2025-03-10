import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> _saveUserToFirestore(User user, String name) async {
  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

  await userRef.set({
    "name": name,
    "email": user.email,
    "profilePicture": user.photoURL ?? "", // Store profile picture if available
    "contacts": [], // Empty list at first
    "createdAt": FieldValue.serverTimestamp(),
  });
}

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

      // Save to Firestore
      await _saveUserToFirestore(userCredential.user!, name);

      return userCredential.user;
    } catch (e) {
      throw e;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

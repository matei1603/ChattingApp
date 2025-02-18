import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      print('Error updating user data: $e');
      throw Exception('Failed to update profile.');
    }
  }
  Future<String> uploadProfileImage(String userId, File image) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('$userId.jpg');
    await storageRef.putFile(image);
    return await storageRef.getDownloadURL();
  }
}

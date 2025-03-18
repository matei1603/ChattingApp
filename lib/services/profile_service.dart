import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

      // If the update includes name or profile image, update in all conversations
      if (data.containsKey('name') || data.containsKey('profileImage')) {
        await _updateUserInConversations(userId, data);
      }
    } catch (e) {
      print('Error updating user data: $e');
      throw Exception('Failed to update profile.');
    }
  }

  Future<void> _updateUserInConversations(String userId, Map<String, dynamic> data) async {
    try {
      QuerySnapshot conversations = await _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .get();

      for (var conversation in conversations.docs) {
        String contactId = conversation.id;

        await _firestore
            .collection('users')
            .doc(contactId)
            .collection('conversations')
            .doc(userId)
            .update({
          if (data.containsKey('name')) 'contactName': data['name'],
          if (data.containsKey('profileImage')) 'contactImage': data['profileImage'],
        });
      }
    } catch (e) {
      print('Error updating conversations: $e');
    }
  }

  Future<String> uploadProfileImage(String userId, File image) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      // Upload file with metadata
      UploadTask uploadTask = storageRef.putFile(
        image,
        SettableMetadata(contentType: "image/jpeg"),
      );

      TaskSnapshot snapshot = await uploadTask;

      // 🔥 Get the download URL as a String
      final String imageUrl = await snapshot.ref.getDownloadURL();

      // 🔥 Update Firestore profile with the String URL
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profileImage': imageUrl, // ✅ Ensuring it's stored as String
      });

      return imageUrl; // ✅ Return the String URL
    } catch (e) {
      print('🔥 Error uploading profile image: $e');
      throw Exception('Failed to upload profile image.');
    }
  }
}

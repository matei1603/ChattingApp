import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class GroupChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createGroupChat(String adminUserId, List<String> memberIds, String groupName) async {
    try {
      if (!memberIds.contains(adminUserId)) {
        memberIds.add(adminUserId);
      }

      String chatId = _firestore.collection('chats').doc().id;

      await _firestore.collection('chats').doc(chatId).set({
        'name': groupName,
        'image': '',
        'members': memberIds,
        'createdBy': adminUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'senderId': 'system',
        'message': "$groupName was created",
        'timestamp': FieldValue.serverTimestamp(),
      });

      for (String memberId in memberIds) {
        await _firestore.collection('users').doc(memberId).collection('conversations').doc(chatId).set({
          'contactName': groupName,
          'contactImage': '',
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'isGroup': true,
          'seen': true,
        });
      }
    } catch (e) {
      print("Error creating group chat: $e");
    }
  }

  Future<Map<String, dynamic>?> getGroupData(String groupId) async {
    try {
      final doc = await _firestore.collection('chats').doc(groupId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print("Error fetching group data: $e");
      return null;
    }
  }

  Stream<QuerySnapshot> getMessages(String groupId) {
    return _firestore
        .collection('chats')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> sendMessage(String groupId, String senderId, String message) async {
    try {
      await _firestore.collection('chats').doc(groupId).collection('messages').add({
        'senderId': senderId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'seenBy': [senderId],
      });

      final groupDoc = await _firestore.collection('chats').doc(groupId).get();
      if (groupDoc.exists) {
        final members = List<String>.from(groupDoc.data()?['members'] ?? []);
        for (String memberId in members) {
          await _firestore.collection('users').doc(memberId).collection('conversations').doc(groupId).update({
            'lastMessage': message,
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print("Error sending group message: $e");
    }
  }

  Future<void> markMessageAsSeen(String groupId, String messageId, String userId) async {
    try {
      final messageRef = _firestore.collection('chats').doc(groupId).collection('messages').doc(messageId);
      await messageRef.update({
        'seenBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print("Error marking message as seen: $e");
    }
  }

  Future<String> uploadGroupImage(String groupId, File image) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('group_images').child('$groupId.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading group image: $e");
      throw Exception("Failed to upload image.");
    }
  }

  Future<void> updateGroupChat(String groupId, String updatedById, String? newName, String? newImage) async {
    try {
      Map<String, dynamic> updates = {};
      String systemMessage = "";

      final userDoc = await _firestore.collection('users').doc(updatedById).get();
      final userName = userDoc.data()?['name'] ?? "Someone";

      if (newName != null) {
        updates['name'] = newName;
        systemMessage = "$userName changed the group name to $newName";
      }
      if (newImage != null) {
        updates['image'] = newImage;
        systemMessage = "$userName changed the group photo";
      }

      await _firestore.collection('chats').doc(groupId).update(updates);

      final groupDoc = await _firestore.collection('chats').doc(groupId).get();
      final members = List<String>.from(groupDoc.data()?['members'] ?? []);

      for (String memberId in members) {
        await _firestore.collection('users').doc(memberId).collection('conversations').doc(groupId).update({
          if (newName != null) 'contactName': newName,
          if (newImage != null) 'contactImage': newImage,
        });
      }

      if (systemMessage.isNotEmpty) {
        await _firestore.collection('chats').doc(groupId).collection('messages').add({
          'senderId': 'system',
          'message': systemMessage,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Error updating group chat: $e");
    }
  }

  Future<List<String>> getSeenUserNames(String groupId, String messageId) async {
    try {
      final messageDoc = await _firestore.collection('chats').doc(groupId).collection('messages').doc(messageId).get();
      final seenIds = List<String>.from(messageDoc.data()?['seenBy'] ?? []);

      List<String> names = [];
      for (String id in seenIds) {
        final userDoc = await _firestore.collection('users').doc(id).get();
        names.add(userDoc.data()?['name'] ?? "Unknown");
      }

      return names;
    } catch (e) {
      print("Error fetching seen users: $e");
      return [];
    }
  }

  Future<void> addMembersToGroup(String groupId, List<String> newMembers, String addedBy) async {
    try {
      final groupRef = _firestore.collection('chats').doc(groupId);
      final groupSnapshot = await groupRef.get();
      if (!groupSnapshot.exists) return;

      List<String> currentMembers = List<String>.from(groupSnapshot.data()?['members'] ?? []);
      List<String> updatedMembers = [...currentMembers, ...newMembers];

      await groupRef.update({'members': updatedMembers});

      for (String userId in newMembers) {
        await _firestore.collection('users').doc(userId).collection('conversations').doc(groupId).set({
          'contactName': groupSnapshot.data()?['name'],
          'contactImage': groupSnapshot.data()?['image'] ?? '',
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'isGroup': true,
        });
      }

      for (String userId in newMembers) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userName = userDoc.data()?['name'] ?? "Someone";

        await _firestore.collection('chats').doc(groupId).collection('messages').add({
          'senderId': 'system',
          'message': '$userName was added to the group',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Error adding members: $e");
    }
  }
}

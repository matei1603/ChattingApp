import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:chatting_app/services/crypto_service.dart';

class GroupChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createGroupChat(String adminUserId, List<String> memberIds, String groupName) async {
    try {
      if (!memberIds.contains(adminUserId)) {
        memberIds.add(adminUserId);
      }
      //generate a unique chat id
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
      //add group chat entry to each member's conv
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
  //returns a stream of group messages ordered by timestamp
  Stream<QuerySnapshot> getMessages(String groupId) {
    return _firestore
        .collection('chats')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
  //encrypt and send a text message to the group
  Future<void> sendMessage(String groupId, String senderId, String message) async {
    try {
      print("📨 sendMessage called for groupId: $groupId");

      final groupDoc = await _firestore.collection('chats').doc(groupId).get();

      if (!groupDoc.exists) {
        print("!!!!! Group does not exist.");
        return;
      }

      final members = List<String>.from(groupDoc.data()?['members'] ?? []);
      print("🧪 Members for group $groupId: $members");

      if (members.isEmpty) {
        print("!!!!! No members found in group.");
        return;
      }

      final encrypted = await CryptoService.encryptForGroup(message, members);
      print("Message encrypted for group.");

      await _firestore.collection('chats').doc(groupId).collection('messages').add({
        'senderId': senderId,
        'message': encrypted['data'],
        'keys': encrypted['keys'],
        'imageUrl': null,
        'documentUrl': null,
        'timestamp': FieldValue.serverTimestamp(),
        'seenBy': [senderId],
      });

      await _updateLastMessage(groupId, encrypted['data']);
      print(" Message saved to Firestore.");
    } catch (e) {
      print(" Error sending group message: $e");
    }
  }
  //upload an image encrypt the url and sends it in the group
  Future<void> sendImageMessage(String groupId, String senderId, File imageFile) async {
    try {
      final groupDoc = await _firestore.collection('chats').doc(groupId).get();
      final members = List<String>.from(groupDoc.data()?['members'] ?? []);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_images/$groupId/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(imageFile);
      final imageUrl = await storageRef.getDownloadURL();

      final encrypted = await CryptoService.encryptForGroup(imageUrl, members);

      await _firestore.collection('chats').doc(groupId).collection('messages').add({
        'senderId': senderId,
        'message': '',
        'imageUrl': encrypted['data'],
        'keys': encrypted['keys'],
        'documentUrl': null,
        'timestamp': FieldValue.serverTimestamp(),
        'seenBy': [senderId],
      });

      final preview = await CryptoService.encryptForGroup('[Image]', members);
      await _updateLastMessage(groupId, preview['data']);
    } catch (e) {
      print("!!!!!! Error sending image message: $e");
    }
  }



  Future<void> sendDocumentMessage(String groupId, String senderId, File documentFile) async {
    try {
      final groupDoc = await _firestore.collection('chats').doc(groupId).get();
      final members = List<String>.from(groupDoc.data()?['members'] ?? []);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_documents/$groupId/${DateTime.now().millisecondsSinceEpoch}_${documentFile.path.split('/').last}');

      await storageRef.putFile(documentFile);
      final documentUrl = await storageRef.getDownloadURL();

      final encrypted = await CryptoService.encryptForGroup(documentUrl, members);

      await _firestore.collection('chats').doc(groupId).collection('messages').add({
        'senderId': senderId,
        'message': '',
        'imageUrl': null,
        'documentUrl': encrypted['data'],
        'keys': encrypted['keys'],
        'timestamp': FieldValue.serverTimestamp(),
        'seenBy': [senderId],
      });

      final preview = await CryptoService.encryptForGroup('[Document]', members);
      await _updateLastMessage(groupId, preview['data']);
    } catch (e) {
      print("!!!!!Error sending document: $e");
    }
  }


  Future<void> _updateLastMessage(String groupId, String lastMessage) async {
    final groupDoc = await _firestore.collection('chats').doc(groupId).get();
    final members = List<String>.from(groupDoc.data()?['members'] ?? []);

    for (String memberId in members) {
      await _firestore.collection('users').doc(memberId).collection('conversations').doc(groupId).update({
        'lastMessage': lastMessage,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    }
  }
  //mark a message as seen by a specific user
  Future<void> markMessageAsSeen(String groupId, String messageId, String userId) async {
    try {
      final messageRef = _firestore.collection('chats').doc(groupId).collection('messages').doc(messageId);
      await messageRef.update({
        'seenBy': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      print("!!!!Error marking message as seen: $e");
    }
  }

  Future<String> uploadGroupImage(String groupId, File image) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('group_images').child('$groupId.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print("!!!!Error uploading group image: $e");
      throw Exception("!!!Failed to upload image.");
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

  Future<void> leaveGroup(String groupId, String userId, String userName) async {
    try {
      final groupRef = _firestore.collection('chats').doc(groupId);

      await groupRef.update({
        'members': FieldValue.arrayRemove([userId]),
      });

      await _firestore.collection('users').doc(userId).collection('conversations').doc(groupId).delete();

      await groupRef.collection('messages').add({
        'senderId': 'system',
        'message': '$userName left the group',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("!!!!!!Error leaving group: $e");
    }
  }
  //add new members to the group and update all relevant collections
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
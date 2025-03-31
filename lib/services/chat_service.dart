import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate a consistent chat ID based on user IDs
  String getChatId(String userId, String contactId) {
    return (userId.hashCode <= contactId.hashCode)
        ? "$userId-$contactId"
        : "$contactId-$userId";
  }

  //  Send text message
  Future<void> sendMessage(String chatId, String senderId, String receiverId, String message) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    await messagesRef.add({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'imageUrl': null,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
      'seenTimestamp': null,
    });

    await _updateConversations(senderId, receiverId, message);
    await _removeDeletedFlag(receiverId, chatId);
  }

  //  Send image message
  Future<void> sendImageMessage(String chatId, String senderId, String receiverId, File imageFile) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    final imageUrl = await _uploadChatImage(chatId, imageFile);

    await messagesRef.add({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': '',
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
      'seenTimestamp': null,
    });

    await _updateConversations(senderId, receiverId, '[Image]');
    await _removeDeletedFlag(receiverId, chatId);
  }

  //  Upload image to Firebase Storage
  Future<String> _uploadChatImage(String chatId, File image) async {
    final storageRef = FirebaseStorage.instance.ref().child('chat_images/$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await storageRef.putFile(image);
    return await storageRef.getDownloadURL();
  }

  // Update both users' conversations
  Future<void> _updateConversations(String senderId, String receiverId, String lastMessage) async {
    final senderDoc = await _firestore.collection('users').doc(senderId).get();
    final receiverDoc = await _firestore.collection('users').doc(receiverId).get();

    final senderName = senderDoc.data()?['name'] ?? 'Unknown';
    final senderImage = senderDoc.data()?['profilePicture'] ?? '';
    final receiverName = receiverDoc.data()?['name'] ?? 'Unknown';
    final receiverImage = receiverDoc.data()?['profilePicture'] ?? '';

    await _firestore.collection('users').doc(senderId).collection('conversations').doc(receiverId).set({
      "lastMessage": lastMessage,
      "lastMessageTimestamp": FieldValue.serverTimestamp(),
      "seen": true,
      "contactName": receiverName,
      "contactImage": receiverImage,
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(receiverId).collection('conversations').doc(senderId).set({
      "lastMessage": lastMessage,
      "lastMessageTimestamp": FieldValue.serverTimestamp(),
      "seen": false,
      "contactName": senderName,
      "contactImage": senderImage,
    }, SetOptions(merge: true));
  }

  //  Mark messages as seen
  Future<void> markMessagesAsSeen(String chatId, String currentUserId) async {
    final messagesRef = _firestore.collection('chats').doc(chatId).collection('messages');

    final querySnapshot = await messagesRef
        .where('receiverId', isEqualTo: currentUserId)
        .where('seen', isEqualTo: false)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.update({
        'seen': true,
        'seenTimestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  //  Get message stream and auto-mark as seen
  Stream<QuerySnapshot> getMessages(String chatId, String currentUserId) {
    final chatRef = _firestore.collection('chats').doc(chatId);

    return chatRef.collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((querySnapshot) {
      List<Future<void>> updates = [];

      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['receiverId'] == currentUserId && !(data['seen'] ?? false)) {
          updates.add(doc.reference.update({
            'seen': true,
            'seenTimestamp': FieldValue.serverTimestamp(),
          }));
        }
      }

      Future.wait(updates);
      return querySnapshot;
    });
  }

  //  Remove from deletedConversations
  Future<void> _removeDeletedFlag(String userId, String chatId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('deletedConversations')
        .doc(chatId)
        .delete()
        .catchError((_) {});
  }
}

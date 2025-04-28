import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:chatting_app/services/crypto_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChatId(String userId, String contactId) {
    return (userId.hashCode <= contactId.hashCode)
        ? "$userId-$contactId"
        : "$contactId-$userId";
  }

  Future<void> sendMessage(
      String chatId,
      String senderId,
      String receiverId,
      String message, {
        String visibility = 'public',
      }) async {
    final encryptedMessage = CryptoService.encrypt(message);

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    await messagesRef.add({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': encryptedMessage,
      'imageUrl': null,
      'documentUrl': null,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
      'seenTimestamp': null,
      'visibility': visibility,
    });

    await _updateConversations(senderId, receiverId, encryptedMessage);
    await _removeDeletedFlag(receiverId, chatId);
  }

  Future<void> sendImageMessage(
      String chatId,
      String senderId,
      String receiverId,
      File imageFile, {
        String visibility = 'public',
      }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    final imageUrl = await _uploadFile(chatId, imageFile, folder: 'chat_images');
    final encryptedUrl = CryptoService.encrypt(imageUrl);

    await messagesRef.add({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': '',
      'imageUrl': encryptedUrl,
      'documentUrl': null,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
      'seenTimestamp': null,
      'visibility': visibility,
    });

    final preview = CryptoService.encrypt('[Image]');
    await _updateConversations(senderId, receiverId, preview);
    await _removeDeletedFlag(receiverId, chatId);
  }

  Future<void> sendDocumentMessage(
      String chatId,
      String senderId,
      String receiverId,
      File documentFile, {
        String visibility = 'public',
      }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    final documentUrl = await _uploadFile(chatId, documentFile, folder: 'chat_documents');
    final encryptedUrl = CryptoService.encrypt(documentUrl);

    await messagesRef.add({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': '',
      'imageUrl': null,
      'documentUrl': encryptedUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
      'seenTimestamp': null,
      'visibility': visibility,
    });

    final preview = CryptoService.encrypt('[Document]');
    await _updateConversations(senderId, receiverId, preview);
    await _removeDeletedFlag(receiverId, chatId);
  }

  Future<String> _uploadFile(String chatId, File file, {required String folder}) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('$folder/$chatId/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');
    await storageRef.putFile(file);
    return await storageRef.getDownloadURL();
  }

  Future<void> _updateConversations(
      String senderId,
      String receiverId,
      String encryptedLastMessage,
      ) async {
    final senderDoc = await _firestore.collection('users').doc(senderId).get();
    final receiverDoc = await _firestore.collection('users').doc(receiverId).get();

    final senderName = senderDoc.data()?['name'] ?? 'Unknown';
    final senderImage = senderDoc.data()?['profilePicture'] ?? '';
    final receiverName = receiverDoc.data()?['name'] ?? 'Unknown';
    final receiverImage = receiverDoc.data()?['profilePicture'] ?? '';

    await _firestore
        .collection('users')
        .doc(senderId)
        .collection('conversations')
        .doc(receiverId)
        .set({
      "lastMessage": encryptedLastMessage,
      "lastMessageTimestamp": FieldValue.serverTimestamp(),
      "seen": true,
      "contactName": receiverName,
      "contactImage": receiverImage,
    }, SetOptions(merge: true));

    await _firestore
        .collection('users')
        .doc(receiverId)
        .collection('conversations')
        .doc(senderId)
        .set({
      "lastMessage": encryptedLastMessage,
      "lastMessageTimestamp": FieldValue.serverTimestamp(),
      "seen": false,
      "contactName": senderName,
      "contactImage": senderImage,
    }, SetOptions(merge: true));
  }

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

  Stream<QuerySnapshot> getMessages(String chatId, String currentUserId) {
    final chatRef = _firestore.collection('chats').doc(chatId);

    return chatRef
        .collection('messages')
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

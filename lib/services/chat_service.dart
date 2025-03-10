import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a message
  Future<void> sendMessage(String chatId, String senderId, String receiverId, String message) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    await messagesRef.add({
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final senderChatRef = _firestore.collection('users').doc(senderId).collection('conversations').doc(receiverId);
    final receiverChatRef = _firestore.collection('users').doc(receiverId).collection('conversations').doc(senderId);

    await senderChatRef.set({
      "lastMessage": message,
      "lastMessageTimestamp": FieldValue.serverTimestamp(),
      "seen": true,
    }, SetOptions(merge: true));

    await receiverChatRef.set({
      "lastMessage": message,
      "lastMessageTimestamp": FieldValue.serverTimestamp(),
      "seen": false,
    }, SetOptions(merge: true));
  }

  // Stream chat messages
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore.collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Mark messages as seen
  Future<void> markMessagesAsSeen(String chatId, String currentUserId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.update({
      'seenBy.$currentUserId': true,
    });

    final conversationRef = _firestore.collection('users')
        .doc(currentUserId)
        .collection('conversations')
        .doc(chatId.replaceAll(currentUserId, '').replaceAll('-', ''));

    await conversationRef.update({'seen': true});
  }

  // Generate chat ID
  String getChatId(String userId, String contactId) {
    return (userId.hashCode <= contactId.hashCode) ? "$userId-$contactId" : "$contactId-$userId";
  }
}

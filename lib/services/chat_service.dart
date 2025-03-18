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
      'seen': false,
      'seenTimestamp': null,
    });

    // 🔥 Update last message for both users
    await _firestore.collection('users').doc(senderId).collection('conversations').doc(receiverId).set({
      "lastMessage": message,
      "lastMessageTimestamp": FieldValue.serverTimestamp(),
      "seen": true,
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(receiverId).collection('conversations').doc(senderId).set({
      "lastMessage": message,
      "lastMessageTimestamp": FieldValue.serverTimestamp(),
      "seen": false, // Receiver hasn't seen the message
    }, SetOptions(merge: true));
  }


  Stream<QuerySnapshot> getMessages(String chatId, String currentUserId) {
    final chatRef = _firestore.collection('chats').doc(chatId);

    return chatRef.collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((querySnapshot) {
      List<Future<void>> updates = [];

      for (var doc in querySnapshot.docs) {
        var messageData = doc.data() as Map<String, dynamic>;

        // ✅ Ensure every message that was sent to the current user is marked as seen
        if (messageData['receiverId'] == currentUserId && !messageData.containsKey('seen')) {
          updates.add(doc.reference.update({
            'seen': true,
            'seenTimestamp': FieldValue.serverTimestamp(),
          }));
        }
      }

      // ✅ Apply all updates at once
      Future.wait(updates);
      return querySnapshot;
    });
  }



  // Mark messages as seen
  Future<void> markMessagesAsSeen(String chatId, String currentUserId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('messages');

    final querySnapshot = await messagesRef
        .where('receiverId', isEqualTo: currentUserId)
        .where('seen', isEqualTo: false) // Only update unseen messages
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.update({
        'seen': true,
        'seenTimestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // Generate chat ID
  String getChatId(String userId, String contactId) {
    return (userId.hashCode <= contactId.hashCode) ? "$userId-$contactId" : "$contactId-$userId";
  }
}

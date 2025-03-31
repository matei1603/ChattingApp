import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_request_dialog.dart';

class ChatPage extends StatefulWidget {
  final String currentUserId;
  final String contactId;
  final String contactName;
  final String contactImage;

  ChatPage({
    required this.currentUserId,
    required this.contactId,
    required this.contactName,
    required this.contactImage,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  late String chatId;
  bool isBlocked = false;
  Timestamp? deletedAt;

  @override
  void initState() {
    super.initState();
    chatId = _chatService.getChatId(widget.currentUserId, widget.contactId);
    _loadDeletedAt();
    _checkIfRequestExists();
    _checkIfBlocked();
    _markMessagesAsSeen();
  }

  void _loadDeletedAt() async {
    final deletedDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('deletedConversations')
        .doc(chatId)
        .get();

    if (deletedDoc.exists) {
      setState(() {
        deletedAt = deletedDoc['deletedAt'];
      });
    }
  }

  void _checkIfRequestExists() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('conversations')
        .doc(widget.contactId)
        .get();

    if (doc.exists &&
        doc.data()?['accepted'] == false &&
        doc.data()?['requestReceiver'] == widget.currentUserId) {
      showDialog(
        context: context,
        builder: (context) => MessageRequestDialog(
          currentUserId: widget.currentUserId,
          contactId: widget.contactId,
          contactName: widget.contactName,
        ),
      );
    }
  }

  void _checkIfBlocked() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.contactId)
        .collection('blocked')
        .doc(widget.currentUserId)
        .get();

    if (doc.exists) {
      setState(() => isBlocked = true);
    }
  }

  void _markMessagesAsSeen() async {
    await _chatService.markMessagesAsSeen(chatId, widget.currentUserId);
  }

  void _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isNotEmpty) {
      await _chatService.sendMessage(chatId, widget.currentUserId, widget.contactId, msg);
      _messageController.clear();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('deletedConversations')
          .doc(chatId)
          .delete()
          .catchError((_) {});
    }
  }

  Future<void> _sendImageMessage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final imageFile = File(picked.path);
      await _chatService.sendImageMessage(chatId, widget.currentUserId, widget.contactId, imageFile);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('deletedConversations')
          .doc(chatId)
          .delete()
          .catchError((_) {});
    }
  }

  String _formatSeenTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Recently";
    final date = timestamp.toDate();
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.contactName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(chatId, widget.currentUserId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final allMessages = snapshot.data!.docs;

                final messages = allMessages.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ts = data['timestamp'] as Timestamp?;
                  return deletedAt == null || (ts != null && ts.toDate().isAfter(deletedAt!.toDate()));
                }).toList();

                int lastSeenIndex = -1;
                for (int i = messages.length - 1; i >= 0; i--) {
                  var data = messages[i].data() as Map<String, dynamic>;
                  if (data['seen'] == true && data['senderId'] == widget.currentUserId) {
                    lastSeenIndex = i;
                    break;
                  }
                }

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isCurrentUser = data['senderId'] == widget.currentUserId;
                    final seenTimestamp = data['seenTimestamp'] as Timestamp?;
                    final imageUrl = data['imageUrl'];
                    final text = data['message'];

                    return Column(
                      crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrentUser ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: imageUrl != null && imageUrl != ''
                              ? Image.network(imageUrl, height: 200)
                              : Text(
                            text ?? '',
                            style: TextStyle(
                              color: isCurrentUser ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (index == lastSeenIndex)
                          Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: Text(
                              "Seen ${_formatSeenTimestamp(seenTimestamp)}",
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (!isBlocked)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.image),
                    onPressed: _sendImageMessage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type your message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          if (isBlocked)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "You have been blocked by this user.",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

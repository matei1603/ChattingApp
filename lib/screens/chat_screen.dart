import 'package:flutter/material.dart';
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
  int _selectedMessageIndex = -1;

  @override
  void initState() {
    super.initState();
    chatId = _chatService.getChatId(widget.currentUserId, widget.contactId);
    _checkIfRequestExists();
    _checkIfBlocked();
    _markMessagesAsSeen();
  }

  void _checkIfRequestExists() async {
    final conversationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('conversations')
        .doc(widget.contactId);

    final doc = await conversationRef.get();

    if (doc.exists && doc.data()?['accepted'] == false) {
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
    final blockedRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.contactId)
        .collection('blocked')
        .doc(widget.currentUserId);

    final doc = await blockedRef.get();

    if (doc.exists) {
      setState(() {
        isBlocked = true;
      });
    }
  }

  void _markMessagesAsSeen() async {
    await _chatService.markMessagesAsSeen(chatId, widget.currentUserId);
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      await _chatService.sendMessage(
        chatId,
        widget.currentUserId,
        widget.contactId,
        _messageController.text.trim(),
      );
      _messageController.clear();
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

                final messages = snapshot.data!.docs;
                int lastSeenIndex = -1;

                for (int i = messages.length - 1; i >= 0; i--) {
                  var message = messages[i].data() as Map<String, dynamic>;
                  if (message['seen'] == true && message['senderId'] == widget.currentUserId) {
                    lastSeenIndex = i;
                    break;
                  }
                }

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isCurrentUser = message['senderId'] == widget.currentUserId;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final seenTimestamp = message['seenTimestamp'] as Timestamp?;

                    return Column(
                      crossAxisAlignment:
                      isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrentUser ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            message['message'],
                            style: TextStyle(color: isCurrentUser ? Colors.white : Colors.black),
                          ),
                        ),
                        if (index == lastSeenIndex)
                          Padding(
                            padding: EdgeInsets.only(right: 10.0),
                            child: Text(
                              "Seen ${_formatSeenTimestamp(seenTimestamp)}",
                              style: TextStyle(fontSize: 12, color: Colors.green),
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
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          if (isBlocked)
            Padding(
              padding: const EdgeInsets.all(8.0),
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

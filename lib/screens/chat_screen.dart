import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  int _selectedMessageIndex = -1;

  @override
  void initState() {
    super.initState();
    chatId = _chatService.getChatId(widget.currentUserId, widget.contactId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.contactName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isCurrentUser = message['senderId'] == widget.currentUserId;
                    final timestamp = message['timestamp'] as Timestamp?;
                    String formattedTime = timestamp != null
                        ? "${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}"
                        : "";

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMessageIndex = (_selectedMessageIndex == index) ? -1 : index;
                        });
                      },
                      child: Column(
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
                          if (_selectedMessageIndex == index)
                            Padding(
                              padding: EdgeInsets.only(left: 10, right: 10),
                              child: Text(
                                formattedTime,
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
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
        ],
      ),
    );
  }
}

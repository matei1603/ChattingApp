import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/group_chat_service.dart';
import 'group_chat_info_screen.dart';
import 'add_people_to_group_screen.dart';
import 'group_seen_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupChatScreen({
    Key? key,
    required this.groupId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final GroupChatService _groupChatService = GroupChatService();
  final TextEditingController _messageController = TextEditingController();
  Map<String, dynamic>? groupData;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchGroupData();
  }

  void _fetchGroupData() async {
    final data = await _groupChatService.getGroupData(widget.groupId);
    if (mounted) {
      setState(() {
        groupData = data;
      });
    }
  }

  void _sendTextMessage() async {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      await _groupChatService.sendMessage(
        widget.groupId,
        widget.currentUserId,
        message,
      );
      _messageController.clear();
    }
  }

  void _sendImageMessage(File imageFile) async {
    await _groupChatService.sendImageMessage(
      widget.groupId,
      widget.currentUserId,
      imageFile,
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File image = File(pickedFile.path);
      _sendImageMessage(image);
    }
  }

  Future<String> _getUserName(String userId) async {
    if (userId == 'system') return '';
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data()?['name'] ?? 'Unknown';
  }

  void _showSeenByDialog(String messageId) async {
    final userNames = await _groupChatService.getSeenUserNames(widget.groupId, messageId);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupSeenScreen(userNames: userNames),
        ),
      );
    }
  }

  Widget _buildMessageTile(Map<String, dynamic> message, bool isCurrentUser, String messageId) {
    final senderId = message['senderId'];
    final text = message['message'] ?? '';
    final imageUrl = message['imageUrl'] ?? null;
    final isSystem = senderId == 'system';

    return FutureBuilder<String>(
      future: _getUserName(senderId),
      builder: (context, snapshot) {
        final senderName = snapshot.data ?? '';

        if (isSystem) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Text(
                text,
                style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
              ),
            ),
          );
        }

        return GestureDetector(
          onLongPress: isCurrentUser ? () => _showSeenByDialog(messageId) : null,
          child: Column(
            crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 2),
                  child: Text(
                    senderName,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700]),
                  ),
                ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.blue : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                )
                    : Text(
                  text,
                  style: TextStyle(color: isCurrentUser ? Colors.white : Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupData?['name'] ?? 'Group'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            tooltip: "Edit Group",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupChatInfoScreen(
                    groupId: widget.groupId,
                    currentUserId: widget.currentUserId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person_add),
            tooltip: "Add People",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPeopleToGroupScreen(
                    groupId: widget.groupId,
                    currentUserId: widget.currentUserId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _groupChatService.getMessages(widget.groupId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msgDoc = messages[index];
                    final msgData = msgDoc.data() as Map<String, dynamic>;
                    final isCurrentUser = msgData['senderId'] == widget.currentUserId;
                    return _buildMessageTile(msgData, isCurrentUser, msgDoc.id);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendTextMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

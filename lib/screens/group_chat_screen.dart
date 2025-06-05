import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/crypto_service.dart';
import '../services/group_chat_service.dart';
import 'group_chat_info_screen.dart';
import 'add_people_to_group_screen.dart';
import 'group_seen_screen.dart';
import 'image_viewer_page.dart';

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
  final ScrollController _scrollController = ScrollController();
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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File image = File(pickedFile.path);
      await _groupChatService.sendImageMessage(
        widget.groupId,
        widget.currentUserId,
        image,
      );
    }
  }

  Future<void> _pickDocument() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'documents', extensions: ['pdf', 'doc', 'docx', 'txt']),
      ],
    );
    if (file != null) {
      File docFile = File(file.path);
      await _groupChatService.sendDocumentMessage(
        widget.groupId,
        widget.currentUserId,
        docFile,
      );
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

  Future<Map<String, String>> _decryptGroupMessage(Map<String, dynamic> message) async {
    final decrypted = <String, String>{};

    if (message['senderId'] == 'system') {
      decrypted['message'] = message['message'] ?? '';
      return decrypted;
    }

    try {
      final wrapper = {
        'data': message['message'],
        'keys': message['keys'],
      };
      decrypted['message'] = (message['message'] != null && message['message'] != '')
          ? await CryptoService.decryptGroupMessage(wrapper, widget.currentUserId)
          : '';

      final imageWrapper = {
        'data': message['imageUrl'],
        'keys': message['keys'],
      };
      decrypted['imageUrl'] = (message['imageUrl'] != null && message['imageUrl'] != '')
          ? await CryptoService.decryptGroupMessage(imageWrapper, widget.currentUserId)
          : '';

      final documentWrapper = {
        'data': message['documentUrl'],
        'keys': message['keys'],
      };
      decrypted['documentUrl'] = (message['documentUrl'] != null && message['documentUrl'] != '')
          ? await CryptoService.decryptGroupMessage(documentWrapper, widget.currentUserId)
          : '';
    } catch (e) {
      print(" !!!!!Group decryption failed: $e");
      decrypted['message'] = '[Group Decryption Failed]';
    }

    return decrypted;
  }




  Widget _buildMessageTile(Map<String, dynamic> message, bool isCurrentUser, String messageId) {
    final senderId = message['senderId'];
    final isSystem = senderId == 'system';

    return FutureBuilder<Map<String, String>>(
      future: _decryptGroupMessage(message),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final decrypted = snapshot.data!;
        final text = decrypted['message'] ?? '';
        final imageUrl = decrypted['imageUrl'];
        final documentUrl = decrypted['documentUrl'];

        return FutureBuilder<String>(
          future: _getUserName(senderId),
          builder: (context, userSnapshot) {
            final senderName = userSnapshot.data ?? '';

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
                crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 2),
                      child: Text(
                        senderName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ImageViewerPage(imageUrl: imageUrl)),
                              );
                            },
                            child: Image.network(
                              imageUrl,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (text.isNotEmpty)
                          Text(
                            text,
                            style: TextStyle(color: isCurrentUser ? Colors.white : Colors.black),
                          ),
                        if (documentUrl != null && documentUrl.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(documentUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open document')));
                              }
                            },
                            child: Text(
                              '📄 Open Document',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: isCurrentUser ? Colors.white : Colors.blueAccent,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
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
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: _pickDocument,
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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_service.dart';
import '../services/crypto_service.dart';
import '../services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_request_dialog.dart';
import 'image_viewer_page.dart';

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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  late String chatId;
  bool isBlocked = false;
  Timestamp? deletedAt;
  Map<String, dynamic>? currentUserData;

  String _visibility = 'public';
  final Map<String, String> visibilityEmoji = {
    'public': '🌍',
    'home': '🏠',
    'work': '💼',
  };

  void _toggleVisibility() {
    setState(() {
      if (_visibility == 'public') _visibility = 'home';
      else if (_visibility == 'home') _visibility = 'work';
      else _visibility = 'public';
    });
  }

  @override
  void initState() {
    super.initState();
    chatId = _chatService.getChatId(widget.currentUserId, widget.contactId);
    _loadDeletedAt();
    _loadCurrentUserData();
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

  void _loadCurrentUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserId).get();
    if (doc.exists) {
      setState(() {
        currentUserData = doc.data();
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

  void _toggleBlockStatus(BuildContext context) async {
    final action = isBlocked ? "Unblock" : "Block";

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$action ${widget.contactName}?"),
        content: Text("Are you sure you want to $action this user?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );

    if (confirmed != true) return;

    final blockRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.contactId)
        .collection('blocked')
        .doc(widget.currentUserId);

    if (isBlocked) {
      await blockRef.delete();
      setState(() => isBlocked = false);
    } else {
      await blockRef.set({'blockedAt': FieldValue.serverTimestamp()});
      setState(() => isBlocked = true);
    }
  }

  void _markMessagesAsSeen() async {
    await _chatService.markMessagesAsSeen(chatId, widget.currentUserId);
  }

  void _sendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isNotEmpty) {
      await _chatService.sendMessage(
        chatId,
        widget.currentUserId,
        widget.contactId,
        msg,
        visibility: _visibility,
      );
      _messageController.clear();
    }
  }

  Future<void> _sendImageMessage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final imageFile = File(picked.path);
      await _chatService.sendImageMessage(
        chatId,
        widget.currentUserId,
        widget.contactId,
        imageFile,
        visibility: _visibility,
      );
    }
  }

  Future<void> _sendDocumentMessage() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'documents', extensions: ['pdf', 'doc', 'docx', 'txt']),
      ],
    );
    if (file != null) {
      final pickedFile = File(file.path);
      await _chatService.sendDocumentMessage(
        chatId,
        widget.currentUserId,
        widget.contactId,
        pickedFile,
        visibility: _visibility,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _filterMessages(List<QueryDocumentSnapshot> allMessages) async {
    if (currentUserData == null) return [];

    List<Map<String, dynamic>> filtered = [];

    for (final doc in allMessages) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['timestamp'] as Timestamp?;
      final visibility = data['visibility'] ?? 'public';
      final isNotDeleted = deletedAt == null || (ts != null && ts.toDate().isAfter(deletedAt!.toDate()));

      if (!isNotDeleted) continue;

      final shouldShow = await LocationService.shouldShowMessage(
        currentUserId: widget.currentUserId,
        senderId: data['senderId'],
        locationType: visibility,
        currentUserData: currentUserData,
      );

      if (shouldShow || data['senderId'] == widget.currentUserId || visibility == 'public') {
        filtered.add({'data': data, 'restricted': false});
      } else {
        filtered.add({'data': data, 'restricted': true});
      }
    }

    return filtered;
  }

  Future<Map<String, String>> _decryptMessageData(Map<String, dynamic> data) async {
    final decrypted = <String, String>{};

    try {
      Future<String> tryDecrypt(String? input) async {
        if (input == null || input.isEmpty) return '';
        if (CryptoService.isProbablyEncrypted(input)) {
          try {
            return await CryptoService.decryptText(input);
          } catch (_) {
            return '[Decryption Failed]';
          }
        }
        return input;
      }

      decrypted['text'] = await tryDecrypt(data['message']);
      decrypted['imageUrl'] = await tryDecrypt(data['imageUrl']);
      decrypted['documentUrl'] = await tryDecrypt(data['documentUrl']);
    } catch (e) {
      decrypted['text'] = '[Decryption Error]';
      decrypted['imageUrl'] = '';
      decrypted['documentUrl'] = '';
    }

    return decrypted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactName),
        actions: [
          IconButton(
            icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
            tooltip: isBlocked ? "Unblock" : "Block",
            onPressed: () => _toggleBlockStatus(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(chatId, widget.currentUserId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final allMessages = snapshot.data!.docs;

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _filterMessages(allMessages),
                  builder: (context, filteredSnapshot) {
                    if (!filteredSnapshot.hasData) return Center(child: CircularProgressIndicator());
                    final messages = filteredSnapshot.data!;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index]['data'] as Map<String, dynamic>;
                        final restricted = messages[index]['restricted'] as bool;
                        final isCurrentUser = data['senderId'] == widget.currentUserId;
                        final visibility = data['visibility'] ?? 'public';

                        if (restricted) {
                          final msg = visibility == 'home'
                              ? "You can see this message when you are home"
                              : "You can see this message when you are at work";
                          return Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(msg, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          );
                        }

                        return FutureBuilder<Map<String, String>>(
                          future: _decryptMessageData(data),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return Padding(
                              padding: const EdgeInsets.all(10),
                              child: Center(child: CircularProgressIndicator()),
                            );

                            final decrypted = snapshot.data!;
                            final imageUrl = decrypted['imageUrl'];
                            final documentUrl = decrypted['documentUrl'];
                            final text = decrypted['text'];

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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (imageUrl != null && imageUrl.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ImageViewerPage(imageUrl: imageUrl),
                                              ),
                                            );
                                          },
                                          child: Image.network(imageUrl, height: 200),
                                        ),
                                      if (text != null && text.isNotEmpty)
                                        Text(text, style: TextStyle(color: isCurrentUser ? Colors.white : Colors.black)),
                                      if (documentUrl != null && documentUrl.isNotEmpty)
                                        GestureDetector(
                                          onTap: () async {
                                            final uri = Uri.parse(documentUrl);
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Could not open document')),
                                              );
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
                                      Text(visibilityEmoji[visibility] ?? '', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
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
                  GestureDetector(
                    onTap: _toggleVisibility,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(visibilityEmoji[_visibility]!, style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  IconButton(icon: Icon(Icons.image), onPressed: _sendImageMessage),
                  IconButton(icon: Icon(Icons.attach_file), onPressed: _sendDocumentMessage),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type your message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_contact_screen.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String currentUserId;

  const HomeScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  void _fetchBlockedUsers() async {
    final blockedSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('blocked')
        .get();

    setState(() {
      blockedUsers = blockedSnapshot.docs.map((doc) => doc.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add), // 🟢 Group chat creation icon
            tooltip: "Create Group",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateGroupScreen(currentUserId: widget.currentUserId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(currentUserId: widget.currentUserId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .collection('conversations')
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No conversations yet."));
          }

          final conversations = snapshot.data!.docs;

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final contactId = conversation.id;

              if (blockedUsers.contains(contactId)) {
                return SizedBox(); // Hide blocked users
              }

              final data = conversation.data() as Map<String, dynamic>?;
              final isGroup = data?['isGroup'] ?? false;
              final contactName = data?['contactName'] ?? 'Unknown';
              final contactImage = data?['contactImage'] ?? '';
              final lastMessage = data?['lastMessage'] ?? '';
              final lastMessageTimestamp = data?['lastMessageTimestamp'] as Timestamp?;
              final seen = data?['seen'] ?? true;

              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: contactImage.isNotEmpty
                      ? NetworkImage(contactImage)
                      : const AssetImage('assets/profile_pic.jpg') as ImageProvider,
                ),
                title: Text(
                  contactName,
                  style: TextStyle(fontWeight: seen ? FontWeight.normal : FontWeight.bold),
                ),
                subtitle: Text(
                  lastMessage.isNotEmpty ? lastMessage : "No messages yet",
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: seen ? Colors.black : Colors.blue),
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lastMessageTimestamp != null
                          ? _formatTimestamp(lastMessageTimestamp)
                          : "",
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (!seen)
                      const Icon(Icons.circle, color: Colors.red, size: 10),
                  ],
                ),
                onTap: () {
                  if (isGroup) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupChatScreen(
                          groupId: contactId,
                          currentUserId: widget.currentUserId,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          currentUserId: widget.currentUserId,
                          contactId: contactId,
                          contactName: contactName,
                          contactImage: contactImage,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        tooltip: "Add Contact",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddContactPage(currentUserId: widget.currentUserId),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }

    return "${date.day}/${date.month}/${date.year}";
  }
}

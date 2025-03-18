import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_contact_screen.dart';
import 'chat_screen.dart';
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

  void _unblockUser(String contactId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('blocked')
        .doc(contactId)
        .delete();

    setState(() {
      blockedUsers.remove(contactId);
    });

    // Restore conversation instantly
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(contactId).get();
    if (userDoc.exists) {
      final contactName = userDoc.data()?['name'] ?? 'Unknown';
      final contactImage = userDoc.data()?['profilePicture'] ?? '';

      // Restore conversation for the unblocking user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('conversations')
          .doc(contactId)
          .set({
        'contactName': contactName,
        'contactImage': contactImage,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'seen': true,
        'accepted': true,
      }, SetOptions(merge: true));

      // Restore conversation for the unblocked user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(contactId)
          .collection('conversations')
          .doc(widget.currentUserId)
          .set({
        'contactName': contactName,
        'contactImage': contactImage,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'seen': false, // Mark as unread for the other user
        'accepted': true,
      }, SetOptions(merge: true));

      // 🔄 Force UI update in real-time
      setState(() {});
    }
  }
  void _blockUser(String contactId) async {
    // Add the contact to the blocked list in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('blocked')
        .doc(contactId)
        .set({'email': contactId});

    setState(() {
      blockedUsers.add(contactId);
    });

    // Remove conversation from home screen
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('conversations')
        .doc(contactId)
        .delete();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        actions: [
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

              final data = conversation.data() as Map<String, dynamic>?; // Explicit casting
              final contactName = data?['contactName'] ?? 'Unknown';
              final contactImage = data?['contactImage'] ?? '';
              final lastMessage = data?['lastMessage'] ?? '';
              final lastMessageTimestamp = data?['lastMessageTimestamp'] as Timestamp?;
              final seen = data?['seen'] ?? true;

              return GestureDetector(
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text("Block $contactName?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            _blockUser(contactId);
                            Navigator.pop(ctx);
                          },
                          child: Text("Block"),
                        ),
                      ],
                    ),
                  );
                },
                child: ListTile(
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
                    // Mark messages as seen
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.currentUserId)
                        .collection('conversations')
                        .doc(contactId)
                        .update({'seen': true});

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
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
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

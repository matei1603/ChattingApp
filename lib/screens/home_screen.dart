import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_contact_screen.dart'; // AddContactPage import
import 'chat_screen.dart'; // ChatPage import
import 'profile_screen.dart'; // ProfileScreen import

class HomeScreen extends StatelessWidget {
  final String currentUserId;

  const HomeScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // Navigate to ProfileScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(currentUserId: currentUserId),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .collection('conversations')
              .orderBy('lastMessageTimestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No conversations yet."));
            }

            final conversations = snapshot.data!.docs;

            return ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final contactId = conversation.id;
                final contactName = conversation['contactName'] ?? 'Unknown';
                final contactImage = conversation['contactImage'] as String?;
                final lastMessage = conversation['lastMessage'] ?? '';
                final lastMessageTimestamp = conversation['lastMessageTimestamp'];
                final seen = conversation['seen'] ?? true;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: contactImage != null && contactImage.isNotEmpty
                        ? NetworkImage(contactImage)
                        : const AssetImage('assets/profile_pic.jpg') as ImageProvider,
                  ),
                  title: Text(contactName),
                  subtitle: Text(
                    lastMessage,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
                    // Navigate to ChatPage
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          currentUserId: currentUserId,
                          contactId: contactId,
                          contactName: contactName,
                          contactImage: contactImage ?? '',
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // Navigate to AddContactPage
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddContactPage(currentUserId: currentUserId),
            ),
          );
        },
      ),
    );
  }

  // Helper function to format the timestamp
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}"; // Format as HH:MM
    }

    return "${date.day}/${date.month}/${date.year}"; // Format as DD/MM/YYYY
  }
}

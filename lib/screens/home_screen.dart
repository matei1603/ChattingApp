import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_contact_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

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
                final data = conversation.data() as Map<String, dynamic>?; // Safe cast

                // Ensure 'contactName' exists
                final contactName = data != null && data.containsKey('contactName')
                    ? data['contactName']
                    : 'Unknown';

                final contactId = conversation.id;
                final contactImage = data != null && data.containsKey('contactImage')
                    ? data['contactImage']
                    : '';
                final lastMessage = data != null && data.containsKey('lastMessage')
                    ? data['lastMessage']
                    : '';
                final lastMessageTimestamp = data != null && data.containsKey('lastMessageTimestamp')
                    ? data['lastMessageTimestamp'] as Timestamp?
                    : null;
                final seen = data != null && data.containsKey('seen')
                    ? data['seen']
                    : true;

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
                    lastMessage,
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          currentUserId: currentUserId,
                          contactId: contactId,
                          contactName: contactName,
                          contactImage: contactImage,
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

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }

    return "${date.day}/${date.month}/${date.year}";
  }
}

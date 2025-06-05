import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedUsersScreen extends StatefulWidget {
  final String currentUserId;

  const BlockedUsersScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _BlockedUsersScreenState createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blocked Users")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .collection('blocked')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No blocked users."));
          }

          final blockedUsers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              final blockedUser = blockedUsers[index];
              final blockedUserId = blockedUser.id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(blockedUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(title: Text("Loading..."));
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  final blockedUserName = userData?['name'] ?? 'Unknown';
                  final blockedUserImage = userData?['profilePicture'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: blockedUserImage.isNotEmpty
                          ? NetworkImage(blockedUserImage)
                          : const AssetImage('assets/profile_pic.jpg') as ImageProvider,
                    ),
                    title: Text(blockedUserName),
                    trailing: ElevatedButton(
                      child: const Text("Unblock"),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.currentUserId)
                            .collection('blocked')
                            .doc(blockedUserId)
                            .delete();

                        final userDoc = await FirebaseFirestore.instance.collection('users').doc(blockedUserId).get();
                        if (userDoc.exists) {
                          final contactName = userDoc.data()?['name'] ?? 'Unknown';
                          final contactImage = userDoc.data()?['profilePicture'] ?? '';

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.currentUserId)
                              .collection('conversations')
                              .doc(blockedUserId)
                              .set({
                            'contactName': contactName,
                            'contactImage': contactImage,
                            'lastMessage': '',
                            'lastMessageTimestamp': FieldValue.serverTimestamp(),
                            'seen': true,
                            'accepted': true,
                          }, SetOptions(merge: true));
                        }
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/group_chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  final String currentUserId;

  const CreateGroupScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final GroupChatService _groupChatService = GroupChatService();
  List<String> selectedContacts = [];
  String groupName = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Group")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.currentUserId)
                  .collection('conversations')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final conversations = snapshot.data!.docs;

                // ✅ Filter to show only individual contacts (not group chats)
                final filteredContacts = conversations.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isGroup = data['group'] == true || data['isGroup'] == true;
                  return !isGroup;
                }).toList();

                if (filteredContacts.isEmpty) {
                  return Center(child: Text("You have no available contacts to add."));
                }

                return ListView.builder(
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final doc = filteredContacts[index];
                    final contactId = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    final contactName = data['contactName'] ?? "Unknown";
                    final email = data['email'] ?? "";

                    return CheckboxListTile(
                      title: Text(contactName),
                      subtitle: Text(email, style: TextStyle(color: Colors.grey)),
                      value: selectedContacts.contains(contactId),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedContacts.add(contactId);
                          } else {
                            selectedContacts.remove(contactId);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(labelText: "Group Name"),
                  onChanged: (val) => groupName = val,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (groupName.isNotEmpty && selectedContacts.length >= 2) {
                      await _groupChatService.createGroupChat(
                        widget.currentUserId,
                        selectedContacts,
                        groupName,
                      );
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Enter a group name and select at least 2 contacts.")),
                      );
                    }
                  },
                  child: Text("Create Group"),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

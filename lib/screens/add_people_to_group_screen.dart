import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/group_chat_service.dart';

class AddPeopleToGroupScreen extends StatefulWidget {
  final String currentUserId;
  final String groupId;

  const AddPeopleToGroupScreen({
    Key? key,
    required this.currentUserId,
    required this.groupId,
  }) : super(key: key);

  @override
  _AddPeopleToGroupScreenState createState() => _AddPeopleToGroupScreenState();
}

class _AddPeopleToGroupScreenState extends State<AddPeopleToGroupScreen> {
  final GroupChatService _groupChatService = GroupChatService();
  List<String> selectedContacts = [];
  List<String> existingMembers = [];

  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
  }

  Future<void> _loadGroupMembers() async {
    final groupData = await _groupChatService.getGroupData(widget.groupId);
    if (groupData != null && groupData.containsKey('members')) {
      setState(() {
        existingMembers = List<String>.from(groupData['members']);
      });
    }
  }

  Future<void> _addMembersToGroup() async {
    if (selectedContacts.isNotEmpty) {
      await _groupChatService.addMembersToGroup(
        widget.groupId,
        selectedContacts,
        widget.currentUserId,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add People")),
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


                final filtered = conversations.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isGroup = data['group'] == true || data['isGroup'] == true;
                  return !isGroup && !existingMembers.contains(doc.id);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(child: Text("No available contacts to add."));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    final contactId = contact.id;
                    final data = contact.data() as Map<String, dynamic>;
                    final name = data['contactName'] ?? "Unknown";
                    final email = data['email'] ?? "";

                    return CheckboxListTile(
                      title: Text(name),
                      subtitle: Text(email, style: TextStyle(color: Colors.grey)),
                      value: selectedContacts.contains(contactId),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
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
            padding: const EdgeInsets.all(10),
            child: ElevatedButton(
              onPressed: selectedContacts.isNotEmpty ? _addMembersToGroup : null,
              child: Text("Add to Group"),
            ),
          ),
        ],
      ),
    );
  }
}

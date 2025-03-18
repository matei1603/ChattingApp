import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'blocked_users_screen.dart';
import '../services/add_contact_service.dart';

class AddContactPage extends StatefulWidget {
  final String currentUserId;

  AddContactPage({required this.currentUserId});

  @override
  _AddContactPageState createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final ContactsService _contactsService = ContactsService();
  final _emailController = TextEditingController();

  void _addContact() async {
    try {
      await _contactsService.addContact(
        widget.currentUserId,
        _emailController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Contact added successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Error"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Contact")),
      body: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder()),
          ),
          ElevatedButton(
            onPressed: _addContact,
            child: Text("Add Contact"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => BlockedUsersScreen(currentUserId: widget.currentUserId),
              ));
            },
            child: Text("Blocked Users"),
          ),
        ],
      ),
    );
  }
}

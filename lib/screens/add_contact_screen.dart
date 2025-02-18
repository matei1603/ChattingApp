import 'package:flutter/material.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addContact,
              child: Text("Add Contact"),
            ),
          ],
        ),
      ),
    );
  }
}

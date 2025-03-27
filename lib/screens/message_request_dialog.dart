import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageRequestDialog extends StatelessWidget {
  final String currentUserId;
  final String contactId;
  final String contactName;

  const MessageRequestDialog({
    Key? key,
    required this.currentUserId,
    required this.contactId,
    required this.contactName,
  }) : super(key: key);

  void _acceptRequest(BuildContext context) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // ✅ Mark conversation as accepted
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(contactId)
          .update({'accepted': true});

      // ✅ Add the contact to both users' contact lists
      await firestore.collection('users').doc(currentUserId).update({
        'contacts': FieldValue.arrayUnion([contactId])
      });

      await firestore.collection('users').doc(contactId).update({
        'contacts': FieldValue.arrayUnion([currentUserId])
      });

      Navigator.pop(context); // ✅ Close the dialog
    } catch (e) {
      print("Error accepting request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to accept request. Try again!")),
      );
    }
  }

  void _blockUser(BuildContext context) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // ✅ Add the blocked user to the blocked list
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked')
          .doc(contactId)
          .set({'blockedAt': FieldValue.serverTimestamp()});

      // ✅ Remove the conversation request
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(contactId)
          .delete();

      Navigator.pop(context); // ✅ Close the dialog
    } catch (e) {
      print("Error blocking user: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to block user. Try again!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Message Request"),
      content: Text("$contactName wants to send you a message. Do you accept?"),
      actions: [
        TextButton(
          onPressed: () => _blockUser(context),
          child: const Text("Block", style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => _acceptRequest(context),
          child: const Text("Accept", style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }
}

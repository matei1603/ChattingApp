import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/group_chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupChatInfoScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupChatInfoScreen({
    Key? key,
    required this.groupId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _GroupChatInfoScreenState createState() => _GroupChatInfoScreenState();
}

class _GroupChatInfoScreenState extends State<GroupChatInfoScreen> {
  final GroupChatService _groupChatService = GroupChatService();
  final TextEditingController _groupNameController = TextEditingController();

  String? _groupImageUrl;
  File? _newImageFile;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    final groupData = await _groupChatService.getGroupData(widget.groupId);
    if (mounted) {
      setState(() {
        _groupNameController.text = groupData?['name'] ?? '';
        _groupImageUrl = groupData?['image'];
      });
    }
  }


  //change group photo
  Future<void> _pickNewImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    String? uploadedImageUrl;

    if (_newImageFile != null) {
      uploadedImageUrl = await _groupChatService.uploadGroupImage(widget.groupId, _newImageFile!);
    }

    await _groupChatService.updateGroupChat(
      widget.groupId,
      widget.currentUserId,
      _groupNameController.text.trim().isNotEmpty ? _groupNameController.text.trim() : null,
      uploadedImageUrl,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Group updated successfully!")),
    );
    Navigator.pop(context);
  }
//leave group
  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Leave Group"),
        content: Text("Are you sure you want to leave this group?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Leave")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .update({
        'members': FieldValue.arrayRemove([widget.currentUserId]),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .collection('conversations')
          .doc(widget.groupId)
          .delete();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'message': 'Someone left the group',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close info screen
        Navigator.pop(context); // Go back from chat screen
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit Group")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickNewImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _newImageFile != null
                    ? FileImage(_newImageFile!)
                    : (_groupImageUrl != null && _groupImageUrl!.isNotEmpty
                    ? NetworkImage(_groupImageUrl!)
                    : const AssetImage('assets/group_default.jpg')) as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(labelText: "Group Name"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveChanges,
              child: Text("Save Changes"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _leaveGroup,
              child: Text("Leave Group"),
            ),
          ],
        ),
      ),
    );
  }
}

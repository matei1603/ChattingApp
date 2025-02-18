import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart'; // Add for sign out functionality
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'login.dart';

class ProfileScreen extends StatefulWidget {
  final String currentUserId;

  const ProfileScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  late TextEditingController nameController;
  bool isEditing = false;
  String name = '';
  String? profileImageUrl;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await _profileService.getUserData(widget.currentUserId);
    if (userData != null) {
      setState(() {
        name = userData['name'] ?? '';
        profileImageUrl = userData['profileImage'];
        nameController.text = name;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });

      final imageUrl = await _profileService.uploadProfileImage(
          widget.currentUserId, _pickedImage!);
      await _profileService.updateUserData(
          widget.currentUserId, {'profileImage': imageUrl});
      setState(() {
        profileImageUrl = imageUrl;
      });
    }
  }

  Future<void> _saveProfile() async {
    try {
      await _profileService.updateUserData(
        widget.currentUserId,
        {'name': nameController.text},
      );
      setState(() {
        name = nameController.text;
        isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  void _toggleEditMode() {
    if (isEditing) {
      _saveProfile();
    } else {
      setState(() {
        isEditing = true;
      });
    }
  }

  void _signOut() async {
    await _authService.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 70,
                backgroundImage: _pickedImage != null
                    ? FileImage(_pickedImage!)
                    : (profileImageUrl != null
                    ? NetworkImage(profileImageUrl!)
                    : AssetImage('assets/profile_pic.jpg'))
                as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            isEditing
                ? TextField(
              controller: nameController,
              textAlign: TextAlign.center,
            )
                : Text(
              name,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _toggleEditMode,
              child: Text(isEditing ? 'Save' : 'Edit'),
            ),
            ElevatedButton(
              onPressed: _signOut,
              child: Text('Sign Out'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

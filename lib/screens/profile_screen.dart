import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import 'location_picker_screen.dart';
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

  GeoPoint? homeLocation;
  GeoPoint? workLocation;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    _loadUserData();  //load profile data from firestore
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
        homeLocation = userData['homeLocation'];
        workLocation = userData['workLocation'];
      });
    }
  }
  //user picks a profile image and uploads it
  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) return;

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _pickedImage = File(pickedFile.path));
      try {
        final imageUrl = await _profileService.uploadProfileImage(widget.currentUserId, _pickedImage!);
        await _profileService.updateUserData(widget.currentUserId, {'profileImage': imageUrl});
        setState(() => profileImageUrl = imageUrl);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile picture updated.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile image.')));
      }
    }
  }
  //opens location picker and saves the selected location
  Future<void> _chooseLocation(String type) async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location permission denied.")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          onLocationSelected: (latLng) async {
            GeoPoint location = GeoPoint(latLng.latitude, latLng.longitude);
            await _profileService.updateUserData(widget.currentUserId, {
              type == 'home' ? 'homeLocation': 'workLocation': location,
            });
            setState(() {
              if (type == 'home') homeLocation = location;
              if (type == 'work') workLocation = location;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type location saved!')));
          },
        ),
      ),
    );
  }
  //saves updated user name to firestore
  Future<void> _saveProfile() async {
    try {
      await _profileService.updateUserData(widget.currentUserId, {'name': nameController.text});
      setState(() {
        name = nameController.text;
        isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile.')));
    }
  }
  //toggles between editing and viewing mode
  void _toggleEditMode() {
    if (isEditing) {
      _saveProfile();
    } else {
      setState(() => isEditing = true);
    }
  }

  void _signOut() async {
    await _authService.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
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
                    : (profileImageUrl?.isNotEmpty ?? false)
                    ? NetworkImage(profileImageUrl!)
                    : AssetImage('assets/profile_pic.jpg') as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            isEditing
                ? TextField(
              controller: nameController,
              textAlign: TextAlign.center,
            )
                : Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton.icon( //buttons to pick home or work location
              onPressed: () => _chooseLocation('home'),
              icon: Icon(Icons.home),
              label: Text(homeLocation != null ? "Update Home Location" : "Set Home Location"),
            ),
            ElevatedButton.icon(
              onPressed: () => _chooseLocation('work'),
              icon: Icon(Icons.work),
              label: Text(workLocation != null ? "Update Work Location" : "Set Work Location"),
            ),
            const Spacer(),
            ElevatedButton(onPressed: _toggleEditMode, child: Text(isEditing ? 'Save' : 'Edit')),
            ElevatedButton(onPressed: _signOut, child: Text('Sign Out')),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addContact(String currentUserId, String contactEmail) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 🔥 Check if the user exists
      final querySnapshot = await firestore.collection('users').where('email', isEqualTo: contactEmail).limit(1).get();
      if (querySnapshot.docs.isEmpty) {
        throw Exception("User with this email doesn't exist.");
      }

      final contactData = querySnapshot.docs.first.data();
      final contactId = querySnapshot.docs.first.id;
      final contactName = contactData['name'] ?? 'Unknown';  // 🔥 Ensure we get the name
      final contactProfileImage = contactData['profilePicture'] ?? '';

      if (contactId == currentUserId) {
        throw Exception("You cannot add yourself as a contact.");
      }

      // 🔥 Check if the contact is already in the user's contacts
      final userDoc = await firestore.collection('users').doc(currentUserId).get();
      final contacts = userDoc.data()?['contacts'] ?? [];
      if (contacts.contains(contactId)) {
        throw Exception("This person is already in your contacts.");
      }

      // 🔥 Store the contact information correctly
      await firestore.collection('users').doc(currentUserId).collection('conversations').doc(contactId).set({
        "contactName": contactName,  // 🔥 Store the correct contact name
        "contactImage": contactProfileImage,
        "lastMessage": "Request Pending",
        "lastMessageTimestamp": FieldValue.serverTimestamp(),
        "accepted": false,
      });

      // 🔥 Send a request to the other person
      await firestore.collection('users').doc(contactId).collection('conversations').doc(currentUserId).set({
        "contactName": userDoc.data()?['name'] ?? 'Unknown',
        "contactImage": userDoc.data()?['profilePicture'] ?? '',
        "lastMessage": "Request Pending",
        "lastMessageTimestamp": FieldValue.serverTimestamp(),
        "accepted": false,
      });

    } catch (e) {
      throw e;
    }
  }


}

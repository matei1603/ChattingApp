import 'package:cloud_firestore/cloud_firestore.dart';

class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addContact(String currentUserId, String contactEmail) async {
    try {
      final firestore = FirebaseFirestore.instance;

      //we check if the user exists
      final querySnapshot = await firestore.collection('users').where('email', isEqualTo: contactEmail).limit(1).get();
      if (querySnapshot.docs.isEmpty) {
        throw Exception("User with this email doesn't exist.");
      }

      final contactData = querySnapshot.docs.first.data();
      final contactId = querySnapshot.docs.first.id;
      final contactName = contactData['name'] ?? 'Unknown';
      final contactProfileImage = contactData['profilePicture'] ?? '';

      if (contactId == currentUserId) {
        throw Exception("You cannot add yourself as a contact.");
      }

      //we heck if the contact is already in the user's contacts
      final userDoc = await firestore.collection('users').doc(currentUserId).get();
      final contacts = userDoc.data()?['contacts'] ?? [];
      if (contacts.contains(contactId)) {
        throw Exception("This person is already in your contacts.");
      }

      //we store the contact information correctly
      await firestore.collection('users').doc(currentUserId).collection('conversations').doc(contactId).set({
        "contactName": contactName,
        "contactImage": contactProfileImage,
        "lastMessage": "Request Pending",
        "lastMessageTimestamp": FieldValue.serverTimestamp(),
        "accepted": false,
      });

      //we send a request to the other person (receiver = contactId)
      await firestore.collection('users').doc(contactId).collection('conversations').doc(currentUserId).set({
        "contactName": userDoc.data()?['name'] ?? 'Unknown',
        "contactImage": userDoc.data()?['profilePicture'] ?? '',
        "lastMessage": "Request Pending",
        "lastMessageTimestamp": FieldValue.serverTimestamp(),
        "accepted": false,
        "requestReceiver": contactId,
      });

    } catch (e) {
      throw e;
    }
  }


}

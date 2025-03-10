import 'package:cloud_firestore/cloud_firestore.dart';

class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addContact(String currentUserId, String contactEmail) async {
    try {
      // Check if user with this email exists
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: contactEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("User with this email doesn't exist.");
      }

      final contactId = querySnapshot.docs.first.id;
      if (contactId == currentUserId) {
        throw Exception("You cannot add yourself as a contact.");
      }

      // Get the user's contacts
      final userDoc = await _firestore.collection('users').doc(currentUserId).get();
      final contacts = userDoc.data()?['contacts'] ?? [];

      if (contacts.contains(contactId)) {
        throw Exception("This person is already in your contacts.");
      }

      // Add the contact
      await _firestore.collection('users').doc(currentUserId).update({
        'contacts': FieldValue.arrayUnion([contactId]),
      });

      // Fetch contact details
      final contactDoc = await _firestore.collection('users').doc(contactId).get();
      final contactData = contactDoc.data();
      final contactName = contactData?['name'] ?? 'Unknown';
      final contactImage = contactData?['profilePicture'] ?? '';

      // Add entry in conversations to make the contact appear in the home screen
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(contactId)
          .set({
        'contactName': contactName,
        'contactImage': contactImage,
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'seen': true,
      }, SetOptions(merge: true));
    } catch (e) {
      throw e;
    }
  }
}

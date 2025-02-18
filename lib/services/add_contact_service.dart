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

      // Check if the contact already exists
      if (contacts.contains(contactId)) {
        throw Exception("This person is already in your contacts.");
      }

      // Add the contact (store the contact ID, not the email)
      await _firestore.collection('users').doc(currentUserId).update({
        'contacts': FieldValue.arrayUnion([contactId]),
      });
    } catch (e) {
      throw e; // Re-throw error for UI handling
    }
  }
}

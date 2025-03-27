import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseUpdater {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateFirebaseStructure() async {
    try {
      print(" Updating Firebase for Group Chat Support...");

      //  Step 1: Ensure `groups` collection exists
      String testGroupId = _firestore.collection('groups').doc().id;
      await _firestore.collection('groups').doc(testGroupId).set({
        'groupName': 'Test Group',
        'groupImage': 'https://example.com/default_group_image.jpg',
        'members': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('groups').doc(testGroupId).delete();

      print("✅ Groups collection added!");

      //  Step 2: Update all existing user conversations to support groups
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        String userId = userDoc.id;
        QuerySnapshot conversationsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('conversations')
            .get();

        for (var conversationDoc in conversationsSnapshot.docs) {
          String conversationId = conversationDoc.id;
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('conversations')
              .doc(conversationId)
              .set({
            'isGroup': false, // 🔥 Default to false for existing 1-on-1 chats
          }, SetOptions(merge: true));
        }
      }

      print(" User conversations updated for group chat support!");

      print(" Firebase is now ready for Group Chats!");

    } catch (e) {
      print(" Error updating Firebase structure: $e");
    }
  }
}

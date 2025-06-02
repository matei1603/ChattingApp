import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> patchAllUsersConversationsVisibility() async {
  final firestore = FirebaseFirestore.instance;

  final usersSnapshot = await firestore.collection('users').get();

  for (var userDoc in usersSnapshot.docs) {
    final userId = userDoc.id;
    final convRef = firestore
        .collection('users')
        .doc(userId)
        .collection('conversations');

    final convSnapshot = await convRef.get();

    for (var convDoc in convSnapshot.docs) {
      final data = convDoc.data();
      if (!data.containsKey('visibility')) {
        await convDoc.reference.update({'visibility': 'public'});
        print('✅ Patched $userId / ${convDoc.id}');
      }
    }
  }

  print('🎉 Migration complete: All users checked.');
}

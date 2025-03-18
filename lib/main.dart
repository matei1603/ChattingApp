import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_utilis.dart';
import 'screens/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
 // FirestoreUtils firestoreUtils = FirestoreUtils();
 // await firestoreUtils.updateExistingMessages();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

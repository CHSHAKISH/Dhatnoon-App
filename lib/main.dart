import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @Override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dhatnoon Assessment',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark, // Let's start with a dark theme for that attractive look
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Step 0 Complete!'),
        ),
      ),
    );
  }
}
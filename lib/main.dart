import 'package:dhatnoon_app/screens/auth/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dhatnoon App',

      // --- UPDATED THEME ---
      theme: ThemeData(
        // Set the main brightness to light
        brightness: Brightness.light,

        // Define the primary color (affects buttons, app bar, etc.)
        primaryColor: Colors.blueAccent,

        // A clean white background
        scaffoldBackgroundColor: Colors.white,

        // App bar styling
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueAccent, // A solid color app bar
          foregroundColor: Colors.white, // White title and icons
          elevation: 4.0,
        ),

        // Color scheme for other components
        colorScheme: const ColorScheme.light(
          primary: Colors.blueAccent,
          secondary: Colors.blueAccent,
          background: Colors.white,
          surface: Colors.white, // Card/dialog backgrounds
        ),

        // Update text field theme to look good in light mode
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F1F1), // Light grey fill
          prefixIconColor: Colors.grey[600],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // No border, just fill
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
        ),

        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}
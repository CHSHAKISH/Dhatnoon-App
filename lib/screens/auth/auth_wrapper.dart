import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../home/requester_home_screen.dart'; // Import the requester screen
import '../home/sender_dashboard_screen.dart'; // Import the sender screen

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        // Show loading circle while checking auth state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If user is logged in
        if (authSnapshot.hasData) {
          // User is logged in, now fetch their role from Firestore
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(authSnapshot.data!.uid)
                .snapshots(),
            builder: (context, userDocSnapshot) {

              // While fetching the user's document, show loading
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              // If we can't get the user doc, something is wrong
              if (!userDocSnapshot.hasData || userDocSnapshot.hasError) {
                // You could show an error, or just log them out
                return const LoginScreen();
              }

              // We have the user data, let's get the role
              var userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
              String role = userData['role'];

              // Route user based on their role
              if (role == 'requester') {
                return const RequesterHomeScreen();
              } else if (role == 'sender') {
                return const SenderDashboardScreen();
              } else {
                // Fallback in case role is missing (like for your old 'User A')
                return const LoginScreen();
              }
            },
          );
        }

        // User is not logged in, show LoginScreen
        return const LoginScreen();
      },
    );
  }
}
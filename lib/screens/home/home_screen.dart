// lib/screens/home/home_screen.dart

import 'package:dhatnoon_app/services/auth_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dhatnoon Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authService.signOut();
            },
          )
        ],
      ),
      body: const Center(
        child: Text(
          'Welcome! You are logged in.',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

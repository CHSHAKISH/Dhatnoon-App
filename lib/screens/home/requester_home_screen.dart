import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/screens/requester/request_user_screen.dart';
import 'package:dhatnoon_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:dhatnoon_app/screens/requester/my_tickets_screen.dart'; // <-- IMPORT THIS

class RequesterHomeScreen extends StatelessWidget {
  const RequesterHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a Ping'),
        actions: [
          // --- NEW BUTTON ---
          // This button takes the user to the list of tickets they've created
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View My Pings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyTicketsScreen()),
              );
            },
          ),
          // --- END NEW BUTTON ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              authService.signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: authService.getSendersStream(), // This is our list of Senders
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No senders are available.'));
          }

          var senders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: senders.length,
            itemBuilder: (context, index) {
              var sender = senders[index].data() as Map<String, dynamic>;
              String senderEmail = sender['email'];
              String senderId = sender['uid'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.person, size: 40),
                  title: Text(senderEmail),
                  subtitle: const Text('Available to ping'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Open the new request screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RequestUserScreen(
                          senderId: senderId,
                          senderEmail: senderEmail,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
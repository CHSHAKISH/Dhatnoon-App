import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/auth_service.dart';
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- IMPORT THIS
import 'package:flutter/material.dart';
import 'package:dhatnoon_app/screens/sender/active_ticket_screen.dart';

class SenderDashboardScreen extends StatelessWidget {
  const SenderDashboardScreen({super.key});

  // Helper to get a nice icon
  IconData _getIconForType(String type) {
    switch (type) {
      case 'image_sample':
        return Icons.camera_alt;
      case 'location':
        return Icons.location_on;
      case 'video_stream':
        return Icons.videocam;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TicketService ticketService = TicketService();
    final AuthService authService = AuthService();

    // --- THIS IS THE FIX ---
    // Get the current user ID directly.
    // We know the user is logged in because they are on this screen.
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    // --- END OF FIX ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assigned Requests'),
        actions: [
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
        // --- THIS QUERY IS NOW CORRECT ---
        // It uses the 'currentUserId' string instead of a Future.
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('senderId', isEqualTo: currentUserId) // Use the direct ID
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        // --- END OF QUERY FIX ---
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error); // For debugging
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('You have no new requests.'));
          }

          var tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              var ticket = tickets[index].data() as Map<String, dynamic>;
              String ticketId = tickets[index].id;
              String requestType = ticket['requestType'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(_getIconForType(requestType)),
                  title:
                  Text(requestType.replaceAll('_', ' ').toUpperCase()),
                  subtitle: Text('From: ${ticket['requesterEmail']}'),
                  trailing: ElevatedButton(
                    child: const Text('Accept'),
                    onPressed: () {
                      ticketService.acceptTicket(ticketId);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveTicketScreen(
                            ticketId: ticketId,
                            requestType: requestType,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
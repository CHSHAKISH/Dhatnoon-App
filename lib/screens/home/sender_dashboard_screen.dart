import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/auth_service.dart';
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

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
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('senderId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error);
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

              // --- NEW ---
              // Read duration in seconds, default to 300 (5 min)
              int durationInSeconds = ticket['durationInSeconds'] ?? 300;

              // Format for display
              String durationText =
                  "${(durationInSeconds / 60).floor()} min ${durationInSeconds % 60} sec";
              // --- END NEW ---

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(_getIconForType(requestType)),
                  title:
                  Text(requestType.replaceAll('_', ' ').toUpperCase()),
                  subtitle: Text('From: ${ticket['requesterEmail']} (For $durationText)'), // Show new text
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
                            durationInSeconds: durationInSeconds, // <-- Pass seconds
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
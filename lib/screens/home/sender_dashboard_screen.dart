import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/auth_service.dart'; // Import AuthService
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:flutter/material.dart';

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
    // --- NEW ---
    final AuthService authService = AuthService();

    return Scaffold(
      // --- NEW APPBAR ---
      appBar: AppBar(
        title: const Text('Sender Dashboard'),
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
      // --- END OF NEW APPBAR ---
      body: StreamBuilder<QuerySnapshot>(
        stream: ticketService.getOpenTickets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No open tickets available.'));
          }

          var tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              var ticket = tickets[index].data() as Map<String, dynamic>;
              String ticketId = tickets[index].id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(_getIconForType(ticket['requestType'])),
                  title: Text(ticket['requestType'].replaceAll('_', ' ').toUpperCase()),
                  subtitle: Text('From: ${ticket['requesterEmail']}'),
                  trailing: ElevatedButton(
                    child: const Text('Accept'),
                    onPressed: () {
                      ticketService.acceptTicket(ticketId);
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
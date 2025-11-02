import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:flutter/material.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TicketService ticketService = TicketService();

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ticketService.getMyTickets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('You have not created any tickets.'));
          }

          var tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              var ticket = tickets[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(_getIconForType(ticket['requestType'])),
                  title: Text(ticket['requestType'].replaceAll('_', ' ').toUpperCase()),
                  subtitle: Text('Status: ${ticket['status']}'),
                  trailing: Text(
                    ticket['status'] == 'accepted'
                        ? 'Accepted by:\n${ticket['senderEmail']}'
                        : 'Pending',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: ticket['status'] == 'accepted' ? Colors.green : Colors.orange,
                    ),
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
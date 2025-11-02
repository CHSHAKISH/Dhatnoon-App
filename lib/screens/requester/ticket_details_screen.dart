import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TicketDetailsScreen extends StatelessWidget {
  final String ticketId;
  const TicketDetailsScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Listen to this *specific* ticket
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .doc(ticketId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.hasError) {
            return const Center(child: Text('Error loading ticket.'));
          }

          var ticket = snapshot.data!.data() as Map<String, dynamic>;
          String status = ticket['status'];
          String? mediaUrl = ticket['mediaUrl'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket['requestType'].replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Status: $status', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  'Sender: ${ticket['senderEmail'] ?? 'Not accepted yet'}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const Divider(height: 32),

                // --- Here is the logic to show the image ---
                if (status == 'completed' && mediaUrl != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Result:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          mediaUrl,
                          // Show a loading spinner while the image downloads
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          // Show an error icon if the image fails to load
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.error, size: 50);
                          },
                        ),
                      ),
                    ],
                  )
                else if (status == 'accepted')
                  const Center(
                    child: Text('Sender is working on your request...'),
                  )
                else
                  const Center(
                    child: Text('Waiting for a sender to accept...'),
                  )
              ],
            ),
          );
        },
      ),
    );
  }
}
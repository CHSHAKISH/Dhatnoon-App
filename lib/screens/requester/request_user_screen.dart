import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:flutter/material.dart';

class RequestUserScreen extends StatefulWidget {
  final String senderId;
  final String senderEmail;

  const RequestUserScreen({
    super.key,
    required this.senderId,
    required this.senderEmail,
  });

  @override
  State<RequestUserScreen> createState() => _RequestUserScreenState();
}

class _RequestUserScreenState extends State<RequestUserScreen> {
  final TicketService _ticketService = TicketService();
  bool _isLoading = false;

  /// Helper function to create the ticket and show feedback
  Future<void> _handleRequest(String requestType) async {
    setState(() { _isLoading = true; });

    await _ticketService.createTicket(
      requestType,
      widget.senderId,
      widget.senderEmail,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request for $requestType sent!')),
      );
      Navigator.pop(context); // Go back to the user list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Request from ${widget.senderEmail}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What do you want to request?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Request Location Button
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text('Request Live Location'),
              onPressed: () => _handleRequest('location'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 20),

            // Request Video Button
            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('Request Live Video'),
              onPressed: () => _handleRequest('video_stream'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            // --- NEW BUTTON ---
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Request Image Sample'),
              onPressed: () => _handleRequest('image_sample'), // <-- ADDED
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            // --- END OF NEW BUTTON ---
          ],
        ),
      ),
    );
  }
}
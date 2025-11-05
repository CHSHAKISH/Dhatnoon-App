import 'dart:async'; // Import this
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:flutter/cupertino.dart'; // Import Cupertino
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

  // --- NEW ---
  // Store the duration in a Duration object
  Duration _selectedDuration = const Duration(minutes: 5);
  // --- END NEW ---

  /// Helper function to create the ticket and show feedback
  Future<void> _handleRequest(String requestType) async {
    setState(() { _isLoading = true; });

    await _ticketService.createTicket(
      requestType,
      widget.senderId,
      widget.senderEmail,
      _selectedDuration.inSeconds, // <-- Pass total seconds
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request for $requestType sent!')),
      );
      Navigator.pop(context); // Go back to the user list
    }
  }

  // --- NEW FUNCTION to format the duration ---
  String _formatDuration(Duration d) {
    return "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  // --- NEW FUNCTION to show the timer picker ---
  void _showTimerPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              // OK button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hms, // Hour, Minute, Second
                  initialTimerDuration: _selectedDuration,
                  onTimerDurationChanged: (Duration newDuration) {
                    setState(() {
                      _selectedDuration = newDuration;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // --- END NEW FUNCTIONS ---

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

            // --- NEW CUSTOM DURATION PICKER ---
            const Text('Select Duration (H:M:S):', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _showTimerPicker,
              child: Text(
                _formatDuration(_selectedDuration),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            // --- END NEW PICKER ---

            const SizedBox(height: 32),

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

            ElevatedButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('Request Live Video'),
              onPressed: () => _handleRequest('video_stream'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Request Image Sample'),
              onPressed: () => _handleRequest('image_sample'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class ActiveTicketScreen extends StatefulWidget {
  final String ticketId;
  final String requestType;

  const ActiveTicketScreen({
    super.key,
    required this.ticketId,
    required this.requestType,
  });

  @override
  State<ActiveTicketScreen> createState() => _ActiveTicketScreenState();
}

class _ActiveTicketScreenState extends State<ActiveTicketScreen> {

  // This is our new placeholder function
  Future<void> _handleImageSample() async {
    // Show a snackbar message instead of opening the camera
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Storage not configured. Feature unavailable.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildTaskWidget() {
    switch (widget.requestType) {
      case 'image_sample':
      // This button will now call our placeholder function
        return ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('Open Camera'),
          onPressed: _handleImageSample,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
          ),
        );
      case 'location':
      // We'll build this in Step 4
        return const Text('Location request (coming soon)');
      case 'video_stream':
      // We'll build this in Step 5
        return const Text('Video stream request (coming soon)');
      default:
        return const Text('Unknown request type');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Active Ticket: ${widget.requestType}'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          // We don't need the uploader logic, just the button
          child: _buildTaskWidget(),
        ),
      ),
    );
  }
}
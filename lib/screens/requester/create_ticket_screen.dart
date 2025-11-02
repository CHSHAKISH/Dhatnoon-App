import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:flutter/material.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final TicketService _ticketService = TicketService();
  String? _selectedType = 'image_sample'; // Default value

  final List<String> _ticketTypes = [
    'image_sample',
    'location',
    'video_stream'
  ];

  void _submitTicket() async {
    if (_selectedType != null) {
      await _ticketService.createTicket(_selectedType!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket created successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Ticket'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Service Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Dropdown for selecting ticket type
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: _ticketTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type.replaceAll('_', ' ').toUpperCase()),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedType = newValue;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitTicket,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Submit Request', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
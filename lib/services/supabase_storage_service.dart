import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  final _supabase = Supabase.instance.client;

  Future<String?> uploadTicketMedia(String ticketId, File file) async {
    try {
      // 1. Create a unique file path
      // We'll store it in a folder named after the ticket ID
      final filePath =
          'public/$ticketId/sample_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. Upload the file to the 'ticket_media' bucket
      await _supabase.storage.from('ticket_media').upload(
        filePath,
        file,
      );

      // 3. Get the public URL for the file we just uploaded
      // This is the URL we will save in Firestore
      final publicUrl = _supabase.storage.from('ticket_media').getPublicUrl(filePath);

      return publicUrl;

    } catch (e) {
      print('Error uploading to Supabase: $e');
      return null;
    }
  }
}
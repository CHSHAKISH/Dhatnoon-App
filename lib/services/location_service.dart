import 'package:location/location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  final _supabase = Supabase.instance.client;

  /// Sends the sender's location to the 'live_sessions' table.
  /// We use upsert to create or update the record in one command.
  Future<void> updateSenderLocation(String ticketId, LocationData location) async {
    try {
      await _supabase.from('live_sessions').upsert({
        'ticket_id': ticketId, // This is our primary key
        'lat': location.latitude,
        'lng': location.longitude,
      }, onConflict: 'ticket_id'); // If ticket_id exists, update it
    } catch (e) {
      print('Error updating Supabase location: $e');
    }
  }

  /// Gets a REALTIME stream of location data for a specific ticket.
  Stream<Map<String, dynamic>> getSessionStream(String ticketId) {
    // Use the .stream() method to listen to changes on the table
    return _supabase
        .from('live_sessions')
        .stream(primaryKey: ['ticket_id']) // Tell Supabase what the primary key is
        .eq('ticket_id', ticketId) // Filter for *only* our ticket
        .map((listOfMaps) {
      // The stream returns a List, but we only ever want the first item.
      if (listOfMaps.isEmpty) {
        return <String, dynamic>{}; // Return an empty map if no data
      }
      return listOfMaps.first; // Return the first (and only) map
    });
  }

  /// --- NEW FUNCTION ---
  /// Deletes the sender's location row from the 'live_sessions' table.
  /// This makes the session "ephemeral".
  Future<void> deleteSenderLocation(String ticketId) async {
    try {
      await _supabase
          .from('live_sessions')
          .delete()
          .eq('ticket_id', ticketId); // Delete the row where ticket_id matches
    } catch (e) {
      print('Error deleting Supabase location: $e');
    }
  }
}
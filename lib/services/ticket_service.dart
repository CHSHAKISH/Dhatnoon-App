import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart'; // Import the location package

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final CollectionReference _ticketsCollection =
  FirebaseFirestore.instance.collection('tickets');

  // --- NEW ---
  // Create a new collection for live session data
  final CollectionReference _sessionsCollection =
  FirebaseFirestore.instance.collection('sessions');

  // CREATE: Create a new ticket
  Future<void> createTicket(String requestType) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _ticketsCollection.add({
      'requesterId': currentUser.uid,
      'requesterEmail': currentUser.email,
      'requestType': requestType,
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'senderId': null,
      'senderEmail': null,
    });
  }

  // READ: Get a stream of tickets for the current requester
  Stream<QuerySnapshot> getMyTickets() {
    final User? currentUser = _auth.currentUser;
    return _ticketsCollection
        .where('requesterId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // READ: Get a stream of all open tickets for any sender
  Stream<QuerySnapshot> getOpenTickets() {
    return _ticketsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // UPDATE: Allow a sender to accept a ticket
  Future<void> acceptTicket(String ticketId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _ticketsCollection.doc(ticketId).update({
      'senderId': currentUser.uid,
      'senderEmail': currentUser.email,
      'status': 'accepted',
    });
  }

  // UPDATE: Mark ticket as complete with the media URL (from skipped Step 3)
  Future<void> completeTicketWithMedia(String ticketId, String mediaUrl) async {
    await _ticketsCollection.doc(ticketId).update({
      'status': 'completed',
      'mediaUrl': mediaUrl, // Add the new media URL field
    });
  }

  // --- NEW FUNCTION (for Location, from skipped Step 4) ---
  // Update the sender's live location in the 'sessions' collection
  Future<void> updateSenderLocation(String ticketId, LocationData location) async {
    await _sessionsCollection.doc(ticketId).set({
      'lat': location.latitude,
      'lng': location.longitude,
      'timestamp': FieldValue.serverTimestamp(), // So the requester knows it's live
    }, SetOptions(merge: true)); // Creates the doc if it doesn't exist
  }

  // --- NEW FUNCTION (for Location, from skipped Step 4) ---
  // Get a stream of the live session data for the requester

  // --- NEW FUNCTION (for Location/Video, from skipped Step 4) ---
  Future<void> completeTicket(String ticketId) async {
    await _ticketsCollection.doc(ticketId).update({
      'status': 'completed',
    });
  }
}
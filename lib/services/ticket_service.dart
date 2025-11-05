import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';

/// Service class to manage all Firestore operations related to tickets and sessions.
class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final CollectionReference _ticketsCollection =
  FirebaseFirestore.instance.collection('tickets');
  final CollectionReference _sessionsCollection =
  FirebaseFirestore.instance.collection('sessions');

  /// --- UPDATED ---
  /// Creates a new ticket document with a specific Sender and duration.
  Future<void> createTicket(
      String requestType,
      String senderId,
      String senderEmail,
      int durationInSeconds, // <-- NEW
      ) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return; // Not logged in

    await _ticketsCollection.add({
      'requesterId': currentUser.uid,
      'requesterEmail': currentUser.email,
      'requestType': requestType,
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'senderId': senderId,
      'senderEmail': senderEmail,
      'durationInSeconds': durationInSeconds, // <-- NEW
    });
  }

  /// Gets a real-time stream of tickets created by the current user (Requester).
  Stream<QuerySnapshot> getMyTickets() {
    final User? currentUser = _auth.currentUser;
    return _ticketsCollection
        .where('requesterId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Gets a real-time stream of all tickets assigned to the current user (Sender).
  Stream<QuerySnapshot> getAssignedTickets() {
    final User? currentUser = _auth.currentUser;
    return _ticketsCollection
        .where('senderId', isEqualTo: currentUser!.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Updates a ticket's status to 'accepted' and assigns it to the current user (Sender).
  Future<void> acceptTicket(String ticketId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _ticketsCollection.doc(ticketId).update({
      'status': 'accepted',
    });
  }

  /// Updates a ticket's status to 'completed' and saves the media URL.
  Future<void> completeTicketWithMedia(String ticketId, String mediaUrl) async {
    await _ticketsCollection.doc(ticketId).update({
      'status': 'completed',
      'mediaUrl': mediaUrl,
    });
  }

  /// Updates a ticket's status to 'completed'.
  Future<void> completeTicket(String ticketId) async {
    await _ticketsCollection.doc(ticketId).update({
      'status': 'completed',
    });
  }

  /// (Skipped Feature) Updates the sender's live location in the 'sessions' collection.
  Future<void> updateSenderLocation(String ticketId, LocationData location) async {
    await _sessionsCollection.doc(ticketId).set({
      'lat': location.latitude,
      'lng': location.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Gets a real-time stream of a specific session document.
  Stream<DocumentSnapshot> getSessionStream(String ticketId) {
    // This is for WebRTC, pointing to Firestore
    return _firestore.collection('sessions').doc(ticketId).snapshots();
  }
}
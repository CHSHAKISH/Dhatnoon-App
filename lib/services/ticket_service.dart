import 'package:cloud_firestore/cloud_firestore.dart'; // <-- CORRECTED
import 'package:firebase_auth/firebase_auth.dart';

class TicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the collection reference for 'tickets'
  late final CollectionReference _ticketsCollection =
  _firestore.collection('tickets');

  // CREATE: Create a new ticket
  Future<void> createTicket(String requestType) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return; // Not logged in

    await _ticketsCollection.add({
      'requesterId': currentUser.uid,
      'requesterEmail': currentUser.email,
      'requestType': requestType, // e.g., 'image_sample', 'location'
      'status': 'pending', // pending -> accepted -> completed
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

  // UPDATE: Mark ticket as complete with the media URL
  Future<void> completeTicketWithMedia(String ticketId, String mediaUrl) async {
    await _ticketsCollection.doc(ticketId).update({
      'status': 'completed',
      'mediaUrl': mediaUrl, // Add the new media URL field
    });
  }
}
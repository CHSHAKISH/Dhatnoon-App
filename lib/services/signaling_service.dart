import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get a reference to the 'sessions' collection for WebRTC signaling
  CollectionReference get _sessionsCollection =>
      _firestore.collection('sessions');

  /// Creates an offer for a WebRTC call and saves it to Firestore.
  /// This is called by the **Requester**.
  Future<void> createOffer(String ticketId, RTCSessionDescription offer) async {
    // We use the ticketId as the document ID in the 'sessions' collection
    final sessionDoc = _sessionsCollection.doc(ticketId);

    // Save the offer
    await sessionDoc.set({
      'offer': offer.toMap(), // 'offer' field
    });
  }

  /// Creates an answer to an offer and saves it to Firestore.
  /// This is called by the **Sender**.
  Future<void> createAnswer(String ticketId, RTCSessionDescription answer) async {
    final sessionDoc = _sessionsCollection.doc(ticketId);

    // Save the answer
    await sessionDoc.update({
      'answer': answer.toMap(), // 'answer' field
    });
  }

  /// Listens to the session document for an answer (for the Requester)
  /// or an offer (for the Sender).
  Stream<DocumentSnapshot> getSessionStream(String ticketId) {
    return _sessionsCollection.doc(ticketId).snapshots();
  }

  /// Adds an ICE candidate to the appropriate subcollection in Firestore.
  Future<void> addCandidate(String ticketId, RTCIceCandidate candidate, bool isRequester) async {
    // Determine which subcollection to write to
    final collectionName = isRequester ? 'requesterCandidates' : 'senderCandidates';
    await _sessionsCollection.doc(ticketId)
        .collection(collectionName)
        .add(candidate.toMap());
  }

  /// Listens for new ICE candidates from the other peer.
  Stream<QuerySnapshot> getCandidateStream(String ticketId, bool isRequester) {
    // Listen to the *other* person's candidate collection
    final collectionName = isRequester ? 'senderCandidates' : 'requesterCandidates';
    return _sessionsCollection.doc(ticketId)
        .collection(collectionName)
        .snapshots();
  }
}
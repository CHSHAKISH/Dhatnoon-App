import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/signaling_service.dart';
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TicketDetailsScreen extends StatelessWidget {
  final String ticketId;
  const TicketDetailsScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .doc(ticketId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.hasError) {
            return const Center(child: Text('Error loading ticket.'));
          }

          var ticket = snapshot.data!.data() as Map<String, dynamic>;
          String status = ticket['status'];
          String requestType = ticket['requestType'];
          String? mediaUrl = ticket['mediaUrl'];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requestType.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Status: $status', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  'Sender: ${ticket['senderEmail'] ?? 'Not accepted yet'}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const Divider(height: 32),
                Expanded(
                  child: _buildTicketContent(
                    context,
                    status,
                    requestType,
                    mediaUrl,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketContent(BuildContext context, String status,
      String requestType, String? mediaUrl) {

    // 1. Logic for Image Sample (Placeholder)
    if (requestType == 'image_sample') {
      return const Center(
        child: Text('Image upload feature not configured.'),
      );
    }

    // 2. Logic for Location (Placeholder)
    if (requestType == 'location') {
      if (status == 'accepted') {
        return const Center(child: Text('Maps API not configured.'));
      }
      if (status == 'completed') {
        return const Center(child: Text('Location sharing has ended.'));
      }
    }

    // 3. --- NEW --- Logic for Video Stream
    if (requestType == 'video_stream') {
      if (status == 'accepted') {
        // Show the video player
        return _VideoStreamViewer(ticketId: ticketId);
      }
      if (status == 'completed') {
        return const Center(child: Text('Video stream has ended.'));
      }
    }

    // 4. Fallback text
    if (status == 'accepted') {
      return const Center(
        child: Text('Sender is working on your request...'),
      );
    }

    return const Center(
      child: Text('Waiting for a sender to accept...'),
    );
  }
}

// --- NEW WIDGET for Video Streaming ---
class _VideoStreamViewer extends StatefulWidget {
  final String ticketId;
  const _VideoStreamViewer({required this.ticketId});

  @override
  State<_VideoStreamViewer> createState() => _VideoStreamViewerState();
}

class _VideoStreamViewerState extends State<_VideoStreamViewer> {
  final SignalingService _signalingService = SignalingService();
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  StreamSubscription? _sessionSub;
  StreamSubscription? _candidateSub;

  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}
    ]
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. Initialize the renderer
    await _remoteRenderer.initialize();

    // 2. Create the peer connection
    _peerConnection = await createPeerConnection(_iceConfig);

    // 3. Listen for tracks (the remote video stream)
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        // Set the remote video feed
        _remoteRenderer.srcObject = event.streams[0];
        setState(() {});
      }
    };

    // 4. Listen for ICE candidates from the Sender
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _signalingService.addCandidate(widget.ticketId, candidate, true); // true = isRequester
    };

    // 5. Listen to the session doc for the "offer"
    _sessionSub = _signalingService.getSessionStream(widget.ticketId).listen((doc) async {
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;

        // If the offer exists and we don't have a remote description yet
        if (data['offer'] != null && _peerConnection?.getRemoteDescription() == null) {
          var offer = RTCSessionDescription(
            data['offer']['sdp'],
            data['offer']['type'],
          );

          // Set the offer as our remote description
          await _peerConnection?.setRemoteDescription(offer);

          // Create an answer
          RTCSessionDescription answer = await _peerConnection!.createAnswer();
          await _peerConnection!.setLocalDescription(answer);

          // Send the answer back to Firestore
          await _signalingService.createAnswer(widget.ticketId, answer);
        }
      }
    });

    // 6. Listen for ICE candidates from the Sender
    _candidateSub = _signalingService.getCandidateStream(widget.ticketId, true).listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          _peerConnection?.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _candidateSub?.cancel();
    _peerConnection?.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey),
      ),
      // RTCVideoView displays the live stream
      child: RTCVideoView(_remoteRenderer),
    );
  }
}
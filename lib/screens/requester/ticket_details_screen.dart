import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/signaling_service.dart';
import 'package:dhatnoon_app/services/ticket_service.dart';
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
          // This mediaUrl will now come from Supabase
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
                    mediaUrl, // Pass the URL to the builder
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Dynamically builds the content widget based on the ticket type and status.
  Widget _buildTicketContent(BuildContext context, String status,
      String requestType, String? mediaUrl) {
    // --- (IMPLEMENTED) Image Sample ---
    if (requestType == 'image_sample') {
      if (status == 'completed' && mediaUrl != null) {
        // If we have a URL, display it
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            mediaUrl,
            // Show a loading spinner while the image downloads
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            // Show an error icon if the image fails to load
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, size: 50);
            },
          ),
        );
      }
    }

    // --- (Skipped Feature) Location ---
    if (requestType == 'location') {
      if (status == 'accepted') {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Live location feature was not configured (requires Google Maps SDK billing setup).',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      if (status == 'completed') {
        return const Center(child: Text('Location sharing has ended.'));
      }
    }

    // --- (Buggy Feature) Video Stream ---
    if (requestType == 'video_stream') {
      if (status == 'accepted') {
        // Show the video player widget
        return _VideoStreamViewer(ticketId: ticketId);
      }
      if (status == 'completed') {
        return const Center(child: Text('Video stream has ended.'));
      }
    }

    // --- Fallback Text ---
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

// --- (Buggy Feature) Video Stream Viewer ---
// This stateful widget manages the WebRTC connection for the Requester.
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
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun.stunprotocol.org:3478'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _remoteRenderer.initialize();

    _peerConnection = await createPeerConnection({
      ..._iceConfig,
      'sdpSemantics': 'unified-plan',
    });

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('REQUESTER: ICE Connection State: $state');
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        print("--- REQUESTER: GOT REMOTE STREAM ---");
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('REQUESTER: Got ICE candidate: ${candidate.candidate}');
      _signalingService.addCandidate(widget.ticketId, candidate, true); // true = isRequester
    };

    _sessionSub =
        _signalingService.getSessionStream(widget.ticketId).listen((doc) async {
          if (doc.exists) {
            var data = doc.data() as Map<String, dynamic>;

            if (data['offer'] != null &&
                _peerConnection?.getRemoteDescription() == null) {
              var offer = RTCSessionDescription(
                data['offer']['sdp'],
                data['offer']['type'],
              );

              print('REQUESTER: Got offer, setting remote description...');
              await _peerConnection?.setRemoteDescription(offer);

              RTCSessionDescription answer = await _peerConnection!.createAnswer();
              await _peerConnection!.setLocalDescription(answer);
              await _signalingService.createAnswer(widget.ticketId, answer);
            }
          }
        });

    _candidateSub = _signalingService
        .getCandidateStream(widget.ticketId, true)
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // This is the typo I fixed (was DocumentChange_Type)
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
      child: RTCVideoView(_remoteRenderer),
    );
  }
}
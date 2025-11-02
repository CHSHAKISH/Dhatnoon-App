import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/location_service.dart'; // <-- NEW
import 'package:dhatnoon_app/services/signaling_service.dart';
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_map/flutter_map.dart'; // <-- NEW
import 'package:latlong2/latlong.dart'; // <-- NEW (part of flutter_map)

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
                    ticketId, // <-- Pass ticketId
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
      String requestType, String? mediaUrl, String ticketId) { // <-- Added ticketId
    // --- (IMPLEMENTED) Image Sample ---
    if (requestType == 'image_sample') {
      if (status == 'completed' && mediaUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            mediaUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, size: 50);
            },
          ),
        );
      }
    }

    // --- (IMPLEMENTED) Location ---
    if (requestType == 'location') {
      if (status == 'accepted') {
        // Show the live map viewer
        return _LocationViewer(ticketId: ticketId);
      }
      if (status == 'completed') {
        return const Center(child: Text('Location sharing has ended.'));
      }
    }

    // --- (Buggy Feature) Video Stream ---
    if (requestType == 'video_stream') {
      if (status == 'accepted') {
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

// --- NEW WIDGET FOR LIVE LOCATION ---
class _LocationViewer extends StatefulWidget {
  final String ticketId;
  const _LocationViewer({required this.ticketId});

  @override
  State<_LocationViewer> createState() => _LocationViewerState();
}

class _LocationViewerState extends State<_LocationViewer> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController(); // Controller for flutter_map
  LatLng? _senderPosition;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _locationService.getSessionStream(widget.ticketId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // We have new location data from Supabase!
          var data = snapshot.data!;
          _senderPosition = LatLng(data['lat'], data['lng']);

          // Animate the map to the new position
          _mapController.move(_senderPosition!, 16.0);
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _senderPosition ?? const LatLng(20.5937, 78.9629), // Default to India
            initialZoom: _senderPosition == null ? 4.0 : 16.0,
          ),
          children: [
            // 1. The map background
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.dhatnoon_app',
            ),
            // 2. The marker for the sender
            if (_senderPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _senderPosition!,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
// --- END OF NEW WIDGET ---

// --- (Buggy Feature) Video Stream Viewer ---
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
      _signalingService.addCandidate(widget.ticketId, candidate, true);
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
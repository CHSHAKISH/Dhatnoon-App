import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/signaling_service.dart';
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';

class ActiveTicketScreen extends StatefulWidget {
  final String ticketId;
  final String requestType;

  const ActiveTicketScreen({
    super.key,
    required this.ticketId,
    required this.requestType,
  });

  @override
  State<ActiveTicketScreen> createState() => _ActiveTicketScreenState();
}

class _ActiveTicketScreenState extends State<ActiveTicketScreen> {
  final TicketService _ticketService = TicketService();
  final SignalingService _signalingService = SignalingService();

  // --- Location variables ---
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isLocationSharing = false;

  // --- WebRTC variables ---
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isStreaming = false;
  StreamSubscription? _sessionSub;
  StreamSubscription? _candidateSub;
  // ---

  // Standard STUN server configuration
  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}
    ]
  };

  @override
  void initState() {
    super.initState();
    if (widget.requestType == 'video_stream') {
      // Initialize the video renderer
      _localRenderer.initialize();
    }
  }

  @override
  void dispose() {
    // Clean up all resources
    _locationSubscription?.cancel();
    _sessionSub?.cancel();
    _candidateSub?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  // --- Image Sample (Placeholder) ---
  Future<void> _handleImageSample() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Storage not configured. Feature unavailable.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- Location Sharing (from Step 4) ---
  Future<void> _startLocationSharing() async {
    var status = await Permission.location.request();
    if (status.isDenied) return;

    await _location.changeSettings(accuracy: LocationAccuracy.high);
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData newLocation) {
          _ticketService.updateSenderLocation(widget.ticketId, newLocation);
        });
    setState(() { _isLocationSharing = true; });
  }

  Future<void> _stopLocationSharing() async {
    _locationSubscription?.cancel();
    await _ticketService.completeTicket(widget.ticketId);
    setState(() { _isLocationSharing = false; });
    if (mounted) Navigator.pop(context);
  }

  // --- NEW: Video Streaming Functions ---
  Future<void> _startVideoStream() async {
    // 1. Request permissions
    await [Permission.camera, Permission.microphone].request();

    // 2. Initialize WebRTC
    _peerConnection = await createPeerConnection(_iceConfig);

    // 3. Get camera/mic stream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'} // 'user' for front, 'environment' for back
    });

    // 4. Show local video
    _localRenderer.srcObject = _localStream;

    // 5. Add local stream to the peer connection
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // 6. Listen for ICE candidates
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _signalingService.addCandidate(widget.ticketId, candidate, false); // false = isNotRequester
    };

    // 7. Create an offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // 8. Save offer to Firestore
    await _signalingService.createOffer(widget.ticketId, offer);

    // 9. Listen for the answer from the Requester
    _sessionSub = _signalingService.getSessionStream(widget.ticketId).listen((doc) async {
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['answer'] != null) {
          var answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          await _peerConnection?.setRemoteDescription(answer);
        }
      }
    });

    // 10. Listen for ICE candidates from the Requester
    _candidateSub = _signalingService.getCandidateStream(widget.ticketId, false).listen((snapshot) {
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

    setState(() { _isStreaming = true; });
  }

  Future<void> _stopVideoStream() async {
    // 1. Clean up all streams and connections
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _sessionSub?.cancel();
    _candidateSub?.cancel();

    // 2. Mark ticket as complete
    await _ticketService.completeTicket(widget.ticketId);
    setState(() { _isStreaming = false; });
    if (mounted) Navigator.pop(context);
  }
  // --- End of new functions ---

  // --- Main Build Function ---
  Widget _buildTaskWidget() {
    switch (widget.requestType) {
      case 'image_sample':
        return ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('Open Camera'),
          onPressed: _handleImageSample,
        );

      case 'location':
      // This is our placeholder from Step 4
        return Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(_isLocationSharing ? Icons.stop : Icons.play_arrow),
              label: Text(_isLocationSharing ? 'Stop Sharing' : 'Start Sharing Location (Not Configured)'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Maps API not configured. Feature unavailable.'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
            if (_isLocationSharing)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  'Now sharing your location live...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.green),
                ),
              ),
          ],
        );

    // --- UPDATED CASE for Video ---
      case 'video_stream':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // This view shows the Sender their own camera
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.grey),
                ),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(_isStreaming ? Icons.stop_circle : Icons.play_circle),
              label: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
              onPressed: _isStreaming ? _stopVideoStream : _startVideoStream,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isStreaming ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ],
        );
    // --- End of update ---

      default:
        return const Text('Unknown request type');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Active Ticket: ${widget.requestType}'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildTaskWidget(),
        ),
      ),
    );
  }
}
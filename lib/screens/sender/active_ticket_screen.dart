import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/location_service.dart'; // <-- NEW
import 'package:dhatnoon_app/services/supabase_storage_service.dart';
import 'package:dhatnoon_app/services/ticket_service.dart';
import 'package:dhatnoon_app/services/signaling_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_picker/image_picker.dart';
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
  final SupabaseStorageService _supabaseStorage = SupabaseStorageService();
  final LocationService _locationService = LocationService(); // <-- NEW

  // --- State Variables ---
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isLocationSharing = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isStreaming = false;
  StreamSubscription? _sessionSub;
  StreamSubscription? _candidateSub;
  bool _isUploading = false;

  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  @override
  void initState() {
    super.initState();
    if (widget.requestType == 'video_stream') {
      _localRenderer.initialize();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _sessionSub?.cancel();
    _candidateSub?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  // --- (Implemented) Image Sample ---
  Future<void> _handleImageSample() async {
    var status = await Permission.camera.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required.')),
      );
      return;
    }
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() { _isUploading = true; });
      File imageFile = File(image.path);
      String? downloadUrl = await _supabaseStorage.uploadTicketMedia(
        widget.ticketId,
        imageFile,
      );
      if (downloadUrl != null) {
        await _ticketService.completeTicketWithMedia(
          widget.ticketId,
          downloadUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error uploading image.')),
        );
      }
      if (mounted) setState(() { _isUploading = false; });
    }
  }

  // --- (IMPLEMENTED) Location Sharing ---
  Future<void> _startLocationSharing() async {
    var status = await Permission.location.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required.')),
      );
      return;
    }

    await _location.changeSettings(accuracy: LocationAccuracy.high);
    // Start listening for location changes
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData newLocation) {
          // Send each new location to Supabase
          _locationService.updateSenderLocation(widget.ticketId, newLocation);
        });
    setState(() { _isLocationSharing = true; });
  }

  Future<void> _stopLocationSharing() async {
    // Stop listening
    _locationSubscription?.cancel();
    // Mark the ticket as 'completed' in Firestore
    await _ticketService.completeTicket(widget.ticketId);
    setState(() { _isLocationSharing = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location sharing stopped.')),
      );
      Navigator.pop(context);
    }
  }

  // --- (Buggy Feature) Video Streaming ---
  Future<void> _startVideoStream() async {
    await [Permission.camera, Permission.microphone].request();
    _peerConnection = await createPeerConnection({
      ..._iceConfig,
      'sdpSemantics': 'unified-plan',
    });

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('SENDER: ICE Connection State: $state');
    };
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _signalingService.addCandidate(widget.ticketId, candidate, false);
    };

    _localStream = await navigator.mediaDevices.getUserMedia(
        {'audio': true, 'video': {'facingMode': 'environment'}});
    _localRenderer.srcObject = _localStream;
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _signalingService.createOffer(widget.ticketId, offer);

    _sessionSub =
        _signalingService.getSessionStream(widget.ticketId).listen((doc) async {
          if (doc.exists) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['answer'] != null &&
                _peerConnection?.getRemoteDescription() == null) {
              var answer = RTCSessionDescription(
                data['answer']['sdp'],
                data['answer']['type'],
              );
              await _peerConnection?.setRemoteDescription(answer);
            }
          }
        });

    _candidateSub = _signalingService
        .getCandidateStream(widget.ticketId, false)
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

    setState(() {
      _isStreaming = true;
    });
  }

  Future<void> _stopVideoStream() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _sessionSub?.cancel();
    _candidateSub?.cancel();
    await _ticketService.completeTicket(widget.ticketId);
    setState(() {
      _isStreaming = false;
    });
    if (mounted) Navigator.pop(context);
  }

  // --- Main Build Function ---
  Widget _buildTaskWidget() {
    switch (widget.requestType) {
      case 'image_sample':
        return _isUploading
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Uploading image...'),
          ],
        )
            : ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('Open Camera'),
          onPressed: _handleImageSample,
        );

      case 'location':
      // This is now fully functional
        return Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(_isLocationSharing ? Icons.stop : Icons.play_arrow),
              label: Text(_isLocationSharing
                  ? 'Stop Sharing'
                  : 'Start Sharing Location'),
              onPressed: _isLocationSharing
                  ? _stopLocationSharing
                  : _startLocationSharing,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLocationSharing ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
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

      case 'video_stream':
      // ... (Video stream code remains the same)
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
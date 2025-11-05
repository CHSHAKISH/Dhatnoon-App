import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhatnoon_app/services/location_service.dart';
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
  final int durationInSeconds; // <-- UPDATED

  const ActiveTicketScreen({
    super.key,
    required this.ticketId,
    required this.requestType,
    required this.durationInSeconds, // <-- UPDATED
  });

  @override
  State<ActiveTicketScreen> createState() => _ActiveTicketScreenState();
}

class _ActiveTicketScreenState extends State<ActiveTicketScreen> {
  final TicketService _ticketService = TicketService();
  final SignalingService _signalingService = SignalingService();
  final SupabaseStorageService _supabaseStorage = SupabaseStorageService();
  final LocationService _locationService = LocationService();

  // ... (State variables are the same)
  Timer? _sessionTimer;
  bool _isMuted = false;
  // ... (rest are the same)
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
    // ... (dispose code is the same)
    _locationSubscription?.cancel();
    _sessionSub?.cancel();
    _candidateSub?.cancel();
    _sessionTimer?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  // --- UPDATED TIMER FUNCTIONS ---
  void _startSessionTimer() {
    _sessionTimer?.cancel();

    // Use seconds now
    _sessionTimer = Timer(Duration(seconds: widget.durationInSeconds), () {
      _autoStopSession();
    });
  }

  void _autoStopSession() {
    if (widget.requestType == 'location' && _isLocationSharing) {
      _stopLocationSharing();
    } else if (widget.requestType == 'video_stream' && _isStreaming) {
      _stopVideoStream();
    }
  }

  String _formatDurationForDisplay() {
    final int minutes = (widget.durationInSeconds / 60).floor();
    final int seconds = widget.durationInSeconds % 60;
    return "$minutes min ${seconds} sec";
  }
  // --- END UPDATED FUNCTIONS ---

  void _toggleMute() {
    if (_localStream == null) return;
    final audioTrack = _localStream!.getAudioTracks().first;
    setState(() {
      _isMuted = !_isMuted;
      audioTrack.enabled = !_isMuted;
    });
  }

  // ... (handleImageSample, start/stop Location, start/stop Video are the same)
  // They already call the correct timer functions.
  Future<void> _handleImageSample() async {
    // ... (code is the same)
    var status = await Permission.camera.request();
    if (status.isDenied) { /*... snackbar ...*/ return; }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() { _isUploading = true; });
      File imageFile = File(image.path);
      String? downloadUrl = await _supabaseStorage.uploadTicketMedia(widget.ticketId, imageFile);

      if (downloadUrl != null) {
        await _ticketService.completeTicketWithMedia(widget.ticketId, downloadUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded!')));
          Navigator.pop(context);
        }
      } else { /*... error snackbar ...*/ }
      if (mounted) setState(() { _isUploading = false; });
    }
  }

  // --- (Implemented) Location Sharing ---
  Future<void> _startLocationSharing() async {
    // ... (code is the same, starts timer)
    var status = await Permission.location.request();
    if (status.isDenied) { /*... snackbar ...*/ return; }

    await _location.changeSettings(accuracy: LocationAccuracy.high);
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData newLocation) {
          _locationService.updateSenderLocation(widget.ticketId, newLocation);
        });
    setState(() { _isLocationSharing = true; });
    _startSessionTimer();
  }

  Future<void> _stopLocationSharing() async {
    // ... (code is the same, stops timer)
    _sessionTimer?.cancel();
    _locationSubscription?.cancel();
    await _ticketService.completeTicket(widget.ticketId);
    await _locationService.deleteSenderLocation(widget.ticketId);

    setState(() { _isLocationSharing = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location sharing stopped.')));
      Navigator.pop(context);
    }
  }

  // --- (Buggy Feature) Video Streaming ---
  Future<void> _startVideoStream() async {
    // ... (code is the same, starts timer)
    await [Permission.camera, Permission.microphone].request();
    _peerConnection = await createPeerConnection({ /*...*/ });

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) { /*...*/ };
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) { /*...*/ };

    _localStream = await navigator.mediaDevices.getUserMedia(
        {'audio': true, 'video': {'facingMode': 'environment'}});
    _localRenderer.srcObject = _localStream;
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _signalingService.createOffer(widget.ticketId, offer);

    _sessionSub = _signalingService.getSessionStream(widget.ticketId).listen((doc) async { /*...*/ });
    _candidateSub = _signalingService.getCandidateStream(widget.ticketId, false).listen((snapshot) { /*...*/ });

    setState(() { _isStreaming = true; });
    _startSessionTimer();
  }

  Future<void> _stopVideoStream() async {
    // ... (code is the same, stops timer)
    _sessionTimer?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _sessionSub?.cancel();
    _candidateSub?.cancel();
    await _ticketService.completeTicket(widget.ticketId);

    setState(() { _isStreaming = false; });
    if (mounted) Navigator.pop(context);
  }

  // --- Main Build Function ---
  Widget _buildTaskWidget() {
    switch (widget.requestType) {
      case 'image_sample':
      // ... (Image sample UI is the same)
        return _isUploading
            ? const Column( /*... Loading UI ...*/ )
            : ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt),
          label: const Text('Open Camera'),
          onPressed: _handleImageSample,
        );

      case 'location':
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
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  'Sharing live for ${_formatDurationForDisplay()}', // <-- UPDATED
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
          ],
        );

      case 'video_stream':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isStreaming)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Streaming live for ${_formatDurationForDisplay()}', // <-- UPDATED
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(_isStreaming ? Icons.stop_circle : Icons.play_circle),
                  label: Text(_isStreaming ? 'Stop Stream' : 'Start Stream'),
                  onPressed: _isStreaming ? _stopVideoStream : _startVideoStream,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStreaming ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  ),
                ),
                IconButton.filled(
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                  iconSize: 30,
                  padding: const EdgeInsets.all(16),
                  onPressed: _isStreaming ? _toggleMute : null,
                  style: IconButton.styleFrom(
                    backgroundColor: _isMuted ? Colors.red : Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
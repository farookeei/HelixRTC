import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/repositories/signaling_repository_impl.dart';
import '../../data/repositories/webrtc_repository_impl.dart';
import '../../domain/models/signaling_message.dart';

import 'call_state.dart';

final callProvider = NotifierProvider<CallNotifier, CallState>(() {
  return CallNotifier();
});

class CallNotifier extends Notifier<CallState> {
  StreamSubscription<SignalingMessage>? _signalingSubscription;

  @override
  CallState build() {
    // Initial state: No camera stream yet.
    return CallState();
  }

  /// Tells the repository to turn on the camera, then saves it in the state so the UI updates
  Future<void> initializeCamera() async {
    final webrtcRepo = ref.read(webRtcRepoProvider);

    // Turn on the camera!
    final stream = await webrtcRepo.getLocalStream();

    state = state.copyWith(localStream: stream);
  }

  /// Connects to the signaling server and joins a room
  Future<void> joinRoom(String roomId, String senderName) async {
    if (state.isConnecting || state.isJoined) return;

    state = state.copyWith(isConnecting: true);

    try {
      final signalingRepo = ref.read(signalingRepoProvider);

      // Connect to the WebSocket signaling server
      // (Note: ws://10.0.2.2:8080/ws for Android emulator)
      await signalingRepo.connect('ws://172.17.11.75:8080/ws');

      // Listen for incoming messages from the server
      _signalingSubscription?.cancel();
      _signalingSubscription = signalingRepo.onMessageReceived.listen((message) {
        _handleSignalingMessage(message);
      });

      // Create the join message
      final message = SignalingMessage(
        type: 'join',
        room: roomId,
        sender: senderName,
      );

      signalingRepo.sendMessage(message);

      state = state.copyWith(
        isConnecting: false,
        isJoined: true,
        roomId: roomId,
      );
    } catch (e) {
      log('Failed to join room: $e');
      state = state.copyWith(isConnecting: false, isJoined: false);
    }
  }

  void leaveRoom() {
    final signalingRepo = ref.read(signalingRepoProvider);
    signalingRepo.disconnect();
    
    // Stop listening to old messages
    _signalingSubscription?.cancel();
    _signalingSubscription = null;
    
    // Close and dispose of the WebRTC peer connection
    state.peerConnection?.close();
    state.peerConnection?.dispose();
    
    // Reset state, but keep the local camera stream active
    state = CallState(
      localStream: state.localStream,
      remoteStream: null,
      peerConnection: null,
      isConnecting: false,
      isJoined: false,
      roomId: null,
      isAudioMuted: state.isAudioMuted,
      isVideoMuted: state.isVideoMuted,
    );
  }

  void _handleSignalingMessage(SignalingMessage message) {
    log('Received message: ${message.type} from ${message.sender}');
    
    switch (message.type) {
      case 'peer_joined':
        _handlePeerJoined();
        break;
      case 'offer':
        _handleOffer(message);
        break;
      case 'answer':
        _handleAnswer(message);
        break;
      case 'candidate':
        _handleIceCandidate(message);
        break;
    }
  }

  Future<void> _handlePeerJoined() async {
    await _initializePeerConnection();
    
    if (state.peerConnection == null) return;
    
    // 1. Create the SDP Offer
    final webrtcRepo = ref.read(webRtcRepoProvider);
    final offer = await webrtcRepo.createOffer(state.peerConnection!);
    
    // 2. Send it to the other person via the signaling server
    final signalingRepo = ref.read(signalingRepoProvider);
    signalingRepo.sendMessage(SignalingMessage(
      type: 'offer',
      room: state.roomId,
      data: jsonEncode(offer.toMap()),
    ));
  }

  Future<void> _handleOffer(SignalingMessage message) async {
    if (message.data == null) return;
    
    // If we just joined the room, we might not have initialized the connection yet
    if (state.peerConnection == null) {
      await _initializePeerConnection();
    }
    
    if (state.peerConnection == null) return;

    // 1. Parse the incoming Offer SDP
    final data = jsonDecode(message.data!);
    final description = RTCSessionDescription(data['sdp'], data['type']);
    
    // 2. Set it as the Remote Description
    final webrtcRepo = ref.read(webRtcRepoProvider);
    await webrtcRepo.setRemoteDescription(state.peerConnection!, description);
    
    // 3. Create our Answer
    final answer = await webrtcRepo.createAnswer(state.peerConnection!);
    
    // 4. Send the Answer back via signaling
    final signalingRepo = ref.read(signalingRepoProvider);
    signalingRepo.sendMessage(SignalingMessage(
      type: 'answer',
      room: state.roomId,
      data: jsonEncode(answer.toMap()),
    ));
  }

  Future<void> _handleAnswer(SignalingMessage message) async {
    if (message.data == null || state.peerConnection == null) return;
    
    // 1. Parse the incoming Answer SDP
    final data = jsonDecode(message.data!);
    final description = RTCSessionDescription(data['sdp'], data['type']);
    
    // 2. Set it as the Remote Description
    final webrtcRepo = ref.read(webRtcRepoProvider);
    await webrtcRepo.setRemoteDescription(state.peerConnection!, description);
  }

  Future<void> _handleIceCandidate(SignalingMessage message) async {
    if (message.data == null || state.peerConnection == null) return;
    
    // 1. Parse the incoming ICE Candidate
    final data = jsonDecode(message.data!);
    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
    
    // 2. Add it to our WebRTC engine so it can find the other peer
    final webrtcRepo = ref.read(webRtcRepoProvider);
    await webrtcRepo.addIceCandidate(state.peerConnection!, candidate);
  }

  Future<void> _initializePeerConnection() async {
    final webrtcRepo = ref.read(webRtcRepoProvider);
    
    // 1. Create the Peer Connection
    final pc = await webrtcRepo.createConnection();
    
    // 2. Add our local camera/mic tracks so the other person can see/hear us
    if (state.localStream != null) {
      for (final track in state.localStream!.getTracks()) {
        await pc.addTrack(track, state.localStream!);
      }
    }
    
    // 3. Save it to state
    state = state.copyWith(peerConnection: pc);
    
    // 4. Setup listeners (We will fill these in during later steps)
    pc.onIceCandidate = (candidate) {
      if (state.roomId == null) return;
      
      // When our phone finds a new public IP (ICE Candidate), send it to the other person
      final signalingRepo = ref.read(signalingRepoProvider);
      signalingRepo.sendMessage(SignalingMessage(
        type: 'candidate',
        room: state.roomId!,
        data: jsonEncode(candidate.toMap()),
      ));
    };
    
    pc.onTrack = (event) {
      log('Received remote track');
      if (event.streams.isNotEmpty) {
        state = state.copyWith(remoteStream: event.streams[0]);
      }
    };
  }

  void toggleAudio() {
    if (state.localStream == null) return;
    
    final audioTracks = state.localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      final isMuted = !state.isAudioMuted;
      audioTracks[0].enabled = !isMuted;
      state = state.copyWith(isAudioMuted: isMuted);
    }
  }

  void toggleVideo() {
    if (state.localStream == null) return;
    
    final videoTracks = state.localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      final isMuted = !state.isVideoMuted;
      videoTracks[0].enabled = !isMuted;
      state = state.copyWith(isVideoMuted: isMuted);
    }
  }

  Future<void> switchCamera() async {
    if (state.localStream == null) return;
    
    final videoTracks = state.localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks[0]);
    }
  }
}

import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/repositories/signaling_repository_impl.dart';
import '../../data/repositories/webrtc_repository_impl.dart';
import '../../domain/repositories/signaling_repository.dart';
import '../../domain/repositories/webrtc_repository.dart';
import '../../domain/models/signaling_message.dart';

import 'call_state.dart';

final callProvider = NotifierProvider<CallNotifier, CallState>(() {
  return CallNotifier();
});

class CallNotifier extends Notifier<CallState> {
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
      signalingRepo.onMessageReceived.listen((message) {
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

  /// Disconnects from the signaling server and resets state
  void leaveRoom() {
    final signalingRepo = ref.read(signalingRepoProvider);
    signalingRepo.disconnect();
    state = state.copyWith(isJoined: false, roomId: null);
  }

  void _handleSignalingMessage(SignalingMessage message) {
    log('Received message: ${message.type} from ${message.sender}');
    
    switch (message.type) {
      case 'peer_joined':
        _handlePeerJoined();
        break;
      // TODO: handle offer, answer, ice_candidate
    }
  }

  Future<void> _handlePeerJoined() async {
    await _initializePeerConnection();
    // TODO: Create and send SDP Offer
  }

  Future<void> _initializePeerConnection() async {
    final webrtcRepo = ref.read(webRtcRepoProvider);
    
    // 1. Create the Peer Connection
    final pc = await webrtcRepo.createConnection();
    
    // 2. Add our local camera/mic stream so the other person can see/hear us
    if (state.localStream != null) {
      await pc.addStream(state.localStream!);
    }
    
    // 3. Save it to state
    state = state.copyWith(peerConnection: pc);
    
    // 4. Setup listeners (We will fill these in during later steps)
    pc.onIceCandidate = (candidate) {
      // TODO: send ICE candidate to signaling server
    };
    
    pc.onAddStream = (stream) {
      // TODO: save remote stream to state to render on UI
    };
  }
}

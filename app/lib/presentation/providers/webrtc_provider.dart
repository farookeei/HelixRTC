import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/repositories/signaling_repository_impl.dart';
import '../../data/repositories/webrtc_repository_impl.dart';
import '../../domain/repositories/signaling_repository.dart';
import '../../domain/repositories/webrtc_repository.dart';
import '../../domain/models/signaling_message.dart';

import 'call_state.dart';

// The provider that the UI will actually watch
final callProvider = NotifierProvider<CallNotifier, CallState>(() {
  return CallNotifier();
});

// ==========================================
// 3. The State Notifier (The Brains)
// ==========================================
class CallNotifier extends Notifier<CallState> {
  @override
  CallState build() {
    // Initial state: No camera stream yet.
    return CallState();
  }

  /// Tells the repository to turn on the camera, then saves it in the state so the UI updates
  Future<void> initializeCamera() async {
    // Read the WebRTC repository from our provider above
    final webrtcRepo = ref.read(webRtcRepoProvider);

    // Turn on the camera!
    final stream = await webrtcRepo.getLocalStream();

    // Update the state. This automatically forces the Flutter UI to redraw with the new video!
    state = state.copyWith(localStream: stream);
  }

  /// Connects to the signaling server and joins a room
  Future<void> joinRoom(String roomId, String senderName) async {
    // Prevent joining if already connected or in the process of connecting
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

      // Send it!
      signalingRepo.sendMessage(message);

      // Successfully joined!
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
    // TODO: - handle peer_joined, offer, answer, ice_candidate
  }
}

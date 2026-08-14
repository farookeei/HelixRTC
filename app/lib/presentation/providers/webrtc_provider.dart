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
      const serverUrl = String.fromEnvironment(
        'SIGNALING_URL',
        defaultValue: 'ws://localhost:8080/ws',
      );
      await signalingRepo.connect(serverUrl);

      // Listen for incoming messages from the server
      _signalingSubscription?.cancel();
      _signalingSubscription = signalingRepo.onMessageReceived.listen((
        message,
      ) {
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

    // Close and dispose of all WebRTC peer connections
    for (final pc in state.peerConnections.values) {
      pc.close();
      pc.dispose();
    }

    // Close all data channels
    for (final dc in state.dataChannels.values) {
      dc.close();
    }

    // Reset state, but keep the local camera stream active
    state = CallState(
      localStream: state.localStream,
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
      case 'room_full':
        state = state.copyWith(
          isRoomFull: true,
          isConnecting: false,
          isJoined: false,
        );
        break;
      case 'peer_list':
        _handlePeerList(message);
        break;
      case 'peer_joined':
        _handlePeerJoined(message);
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

  Future<void> _handlePeerList(SignalingMessage message) async {
    final peers = message.peers ?? [];

    // For every peer already in the room, we (the new joiner) create a connection and send an offer
    for (final peerId in peers) {
      await _initializePeerConnection(peerId);
      await _setupDataChannel(peerId);

      final pc = state.peerConnections[peerId];
      if (pc == null) continue;

      // 1. Create the SDP Offer
      final webrtcRepo = ref.read(webRtcRepoProvider);
      final offer = await webrtcRepo.createOffer(pc);

      // 2. Send it ONLY to this specific peer via targeted routing
      final signalingRepo = ref.read(signalingRepoProvider);
      signalingRepo.sendMessage(
        SignalingMessage(
          type: 'offer',
          room: state.roomId,
          to: peerId,
          data: jsonEncode(offer.toMap()),
        ),
      );
    }
  }

  Future<void> _handlePeerJoined(SignalingMessage message) async {
    final peerId = message.sender;
    if (peerId == null) return;

    // We are an existing peer. A new person joined!
    // We create a connection for them, but WE DO NOT send an offer. We wait for theirs.
    await _initializePeerConnection(peerId);
  }

  Future<void> _handleOffer(SignalingMessage message) async {
    final peerId = message.sender;
    if (message.data == null || peerId == null) return;

    // Ensure connection exists
    if (!state.peerConnections.containsKey(peerId)) {
      await _initializePeerConnection(peerId);
    }

    final pc = state.peerConnections[peerId];
    if (pc == null) return;

    // 1. Parse the incoming Offer SDP
    final data = jsonDecode(message.data!);
    final description = RTCSessionDescription(data['sdp'], data['type']);

    // 2. Set it as the Remote Description
    final webrtcRepo = ref.read(webRtcRepoProvider);
    await webrtcRepo.setRemoteDescription(pc, description);

    // 3. Create our Answer
    final answer = await webrtcRepo.createAnswer(pc);

    // 4. Send the Answer back via targeted signaling
    final signalingRepo = ref.read(signalingRepoProvider);
    signalingRepo.sendMessage(
      SignalingMessage(
        type: 'answer',
        room: state.roomId,
        to: peerId,
        data: jsonEncode(answer.toMap()),
      ),
    );
  }

  Future<void> _handleAnswer(SignalingMessage message) async {
    final peerId = message.sender;
    if (message.data == null || peerId == null) return;

    final pc = state.peerConnections[peerId];
    if (pc == null) return;

    // 1. Parse the incoming Answer SDP
    final data = jsonDecode(message.data!);
    final description = RTCSessionDescription(data['sdp'], data['type']);

    // 2. Set it as the Remote Description
    final webrtcRepo = ref.read(webRtcRepoProvider);
    await webrtcRepo.setRemoteDescription(pc, description);
  }

  Future<void> _handleIceCandidate(SignalingMessage message) async {
    final peerId = message.sender;
    if (message.data == null || peerId == null) return;

    final pc = state.peerConnections[peerId];
    if (pc == null) return;

    // 1. Parse the incoming ICE Candidate
    final data = jsonDecode(message.data!);
    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );

    // 2. Add it to our WebRTC engine
    final webrtcRepo = ref.read(webRtcRepoProvider);
    await webrtcRepo.addIceCandidate(pc, candidate);
  }

  Future<void> _initializePeerConnection(String peerId) async {
    // 1. Guard against duplicates
    if (state.peerConnections.containsKey(peerId)) return;
    final webrtcRepo = ref.read(webRtcRepoProvider);
    final pc = await webrtcRepo.createConnection();

    // 2. SAVE TO STATE IMMEDIATELY (before addTrack)!
    final newConns = Map<String, RTCPeerConnection>.from(state.peerConnections);
    newConns[peerId] = pc;
    state = state.copyWith(peerConnections: newConns);

    // 3. Add tracks in background
    if (state.localStream != null) {
      for (final track in state.localStream!.getTracks()) {
        await pc.addTrack(track, state.localStream!);
      }
    }

    // 4. Setup listeners
    pc.onIceCandidate = (candidate) {
      if (state.roomId == null) return;

      final signalingRepo = ref.read(signalingRepoProvider);
      signalingRepo.sendMessage(
        SignalingMessage(
          type: 'candidate',
          room: state.roomId!,
          to: peerId, // Targeted ICE routing
          data: jsonEncode(candidate.toMap()),
        ),
      );
    };

    pc.onTrack = (event) {
      log('Received remote track from $peerId');
      if (event.streams.isNotEmpty) {
        final newStreams = Map<String, MediaStream>.from(state.remoteStreams);
        newStreams[peerId] = event.streams[0];
        state = state.copyWith(remoteStreams: newStreams);
      }
    };

    pc.onDataChannel = (channel) {
      log('Received remote data channel from $peerId');
      _bindDataChannelListeners(channel, peerId);
      final newChannels = Map<String, RTCDataChannel>.from(state.dataChannels);
      newChannels[peerId] = channel;
      state = state.copyWith(dataChannels: newChannels);
    };

    pc.onConnectionState = (connectionState) {
      log('WebRTC Connection State for $peerId: $connectionState');
      if (connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _handlePeerDisconnected(peerId);
      }
    };
  }

  void _handlePeerDisconnected(String peerId) {
    log('Peer $peerId disconnected. Cleaning up their state...');

    // Close data channel and peer connection
    state.dataChannels[peerId]?.close();
    state.peerConnections[peerId]?.close();
    state.peerConnections[peerId]?.dispose();

    // Remove them from maps
    final newConns = Map<String, RTCPeerConnection>.from(state.peerConnections)
      ..remove(peerId);
    final newStreams = Map<String, MediaStream>.from(state.remoteStreams)
      ..remove(peerId);
    final newChannels = Map<String, RTCDataChannel>.from(state.dataChannels)
      ..remove(peerId);

    state = state.copyWith(
      peerConnections: newConns,
      remoteStreams: newStreams,
      dataChannels: newChannels,
    );
  }

  Future<void> _setupDataChannel(String peerId) async {
    final pc = state.peerConnections[peerId];
    if (pc == null) return;

    final init = RTCDataChannelInit();
    final channel = await pc.createDataChannel('chat', init);

    _bindDataChannelListeners(channel, peerId);

    final newChannels = Map<String, RTCDataChannel>.from(state.dataChannels);
    newChannels[peerId] = channel;
    state = state.copyWith(dataChannels: newChannels);
  }

  void _bindDataChannelListeners(RTCDataChannel channel, String peerId) {
    channel.onMessage = (RTCDataChannelMessage data) {
      if (data.isBinary) return; // We only handle text chat

      final message = ChatMessage(
        sender: peerId, // Display their ID in the chat UI
        text: data.text,
        isLocal: false,
      );

      state = state.copyWith(
        messages: [...state.messages, message],
        unreadMessageCount: state.isChatOpen ? 0 : state.unreadMessageCount + 1,
      );
    };

    channel.onDataChannelState = (RTCDataChannelState channelState) {
      log('Data Channel State with $peerId: $channelState');
    };
  }

  void sendChatMessage(String text) {
    if (text.trim().isEmpty) return;

    bool messageSent = false;

    // Broadcast the text message to EVERY peer in the room
    for (final channel in state.dataChannels.values) {
      if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
        channel.send(RTCDataChannelMessage(text));
        messageSent = true;
      }
    }

    if (messageSent) {
      final message = ChatMessage(sender: 'Me', text: text, isLocal: true);
      state = state.copyWith(messages: [...state.messages, message]);
    }
  }

  void setChatOpen(bool isOpen) {
    state = state.copyWith(isChatOpen: isOpen, unreadMessageCount: 0);
  }

  void clearUnreadMessages() {
    state = state.copyWith(unreadMessageCount: 0);
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

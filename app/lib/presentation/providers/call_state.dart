import 'package:flutter_webrtc/flutter_webrtc.dart';

// ==========================================
// 2. The State Object
// ==========================================
class ChatMessage {
  final String sender;
  final String text;
  final bool isLocal;
  
  ChatMessage({
    required this.sender,
    required this.text,
    required this.isLocal,
  });
}

class CallState {
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final RTCPeerConnection? peerConnection;
  final RTCDataChannel? dataChannel;
  final bool isConnecting;
  final bool isJoined;
  final String? roomId;
  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isRoomFull;
  final List<ChatMessage> messages;

  CallState({
    this.localStream,
    this.remoteStream,
    this.peerConnection,
    this.dataChannel,
    this.isConnecting = false,
    this.isJoined = false,
    this.roomId,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.isRoomFull = false,
    this.messages = const [],
  });

  CallState copyWith({
    MediaStream? localStream,
    MediaStream? remoteStream,
    RTCPeerConnection? peerConnection,
    RTCDataChannel? dataChannel,
    bool? isConnecting,
    bool? isJoined,
    String? roomId,
    bool? isAudioMuted,
    bool? isVideoMuted,
    bool? isRoomFull,
    List<ChatMessage>? messages,
  }) {
    return CallState(
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      peerConnection: peerConnection ?? this.peerConnection,
      dataChannel: dataChannel ?? this.dataChannel,
      isConnecting: isConnecting ?? this.isConnecting,
      isJoined: isJoined ?? this.isJoined,
      roomId: roomId ?? this.roomId,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      isRoomFull: isRoomFull ?? this.isRoomFull,
      messages: messages ?? this.messages,
    );
  }

  // Helper method to clear only remote-specific state (since copyWith cannot set values to null)
  CallState clearRemoteSession() {
    return CallState(
      localStream: localStream,
      isConnecting: isConnecting,
      isJoined: isJoined,
      roomId: roomId,
      isAudioMuted: isAudioMuted,
      isVideoMuted: isVideoMuted,
      isRoomFull: isRoomFull,
      // Force these back to null/empty
      remoteStream: null,
      peerConnection: null,
      dataChannel: null,
      messages: const [],
    );
  }
}

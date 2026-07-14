import 'package:flutter_webrtc/flutter_webrtc.dart';

// ==========================================
// 2. The State Object
// ==========================================
class CallState {
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final RTCPeerConnection? peerConnection;
  final bool isConnecting;
  final bool isJoined;
  final String? roomId;
  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isRoomFull;

  CallState({
    this.localStream,
    this.remoteStream,
    this.peerConnection,
    this.isConnecting = false,
    this.isJoined = false,
    this.roomId,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.isRoomFull = false,
  });

  CallState copyWith({
    MediaStream? localStream,
    MediaStream? remoteStream,
    RTCPeerConnection? peerConnection,
    bool? isConnecting,
    bool? isJoined,
    String? roomId,
    bool? isAudioMuted,
    bool? isVideoMuted,
    bool? isRoomFull,
  }) {
    return CallState(
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      peerConnection: peerConnection ?? this.peerConnection,
      isConnecting: isConnecting ?? this.isConnecting,
      isJoined: isJoined ?? this.isJoined,
      roomId: roomId ?? this.roomId,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      isRoomFull: isRoomFull ?? this.isRoomFull,
    );
  }
}

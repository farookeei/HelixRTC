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

  CallState({
    this.localStream,
    this.remoteStream,
    this.peerConnection,
    this.isConnecting = false,
    this.isJoined = false,
    this.roomId,
  });

  CallState copyWith({
    MediaStream? localStream,
    MediaStream? remoteStream,
    RTCPeerConnection? peerConnection,
    bool? isConnecting,
    bool? isJoined,
    String? roomId,
  }) {
    return CallState(
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      peerConnection: peerConnection ?? this.peerConnection,
      isConnecting: isConnecting ?? this.isConnecting,
      isJoined: isJoined ?? this.isJoined,
      roomId: roomId ?? this.roomId,
    );
  }
}

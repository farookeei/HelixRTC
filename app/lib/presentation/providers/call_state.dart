import 'package:flutter_webrtc/flutter_webrtc.dart';

// ==========================================
// 2. The State Object
// ==========================================
class CallState {
  final MediaStream? localStream;
  final bool isConnecting;
  final bool isJoined;
  final String? roomId;

  CallState({
    this.localStream,
    this.isConnecting = false,
    this.isJoined = false,
    this.roomId,
  });

  CallState copyWith({
    MediaStream? localStream,
    bool? isConnecting,
    bool? isJoined,
    String? roomId,
  }) {
    return CallState(
      localStream: localStream ?? this.localStream,
      isConnecting: isConnecting ?? this.isConnecting,
      isJoined: isJoined ?? this.isJoined,
      roomId: roomId ?? this.roomId,
    );
  }
}

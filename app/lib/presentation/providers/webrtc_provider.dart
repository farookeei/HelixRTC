import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/repositories/signaling_repository_impl.dart';
import '../../data/repositories/webrtc_repository_impl.dart';
import '../../domain/repositories/signaling_repository.dart';
import '../../domain/repositories/webrtc_repository.dart';

// ==========================================
// 1. Dependency Injection (The interfaces)
// ==========================================
final signalingRepoProvider = Provider<SignalingRepository>((ref) {
  return SignalingRepositoryImpl();
});

final webRtcRepoProvider = Provider<WebRTCRepository>((ref) {
  return WebRTCRepositoryImpl();
});

// ==========================================
// 2. The State Object
// ==========================================
class CallState {
  final MediaStream? localStream;
  // Later we will add remoteStream and connection status here!

  CallState({this.localStream});

  CallState copyWith({MediaStream? localStream}) {
    return CallState(
      localStream: localStream ?? this.localStream,
    );
  }
}

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
}

// The provider that the UI will actually watch
final callProvider = NotifierProvider<CallNotifier, CallState>(() {
  return CallNotifier();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../domain/repositories/webrtc_repository.dart';

final webRtcRepoProvider = Provider<WebRTCRepository>((ref) {
  return WebRTCRepositoryImpl();
});

class WebRTCRepositoryImpl implements WebRTCRepository {
  @override
  Future<MediaStream> getLocalStream() async {
    // Define the quality and type of media we want
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user', // Defaults to the front-facing "selfie" camera
      },
    };

    // This single line from flutter_webrtc automatically handles asking the user
    // for Camera/Mic permissions and returning the active stream!
    MediaStream stream = await navigator.mediaDevices.getUserMedia(
      mediaConstraints,
    );
    return stream;
  }

  @override
  Future<RTCPeerConnection> createConnection() async {
    // We provide Google's public STUN server so our WebRTC engine can figure out its own Public IP
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
    };

    // Creates the core object that manages the video encoding and networking
    return await createPeerConnection(configuration);
  }

  @override
  Future<RTCSessionDescription> createOffer(
    RTCPeerConnection peerConnection,
  ) async {
    // Generate the SDP "Business Card"
    RTCSessionDescription offer = await peerConnection.createOffer();
    // We MUST save it to our own connection state before sending it to the other person
    await peerConnection.setLocalDescription(offer);
    return offer;
  }

  @override
  Future<RTCSessionDescription> createAnswer(
    RTCPeerConnection peerConnection,
  ) async {
    // Generate an Answer SDP
    RTCSessionDescription answer = await peerConnection.createAnswer();
    // Save it to our own connection
    await peerConnection.setLocalDescription(answer);
    return answer;
  }

  @override
  Future<void> setRemoteDescription(
    RTCPeerConnection peerConnection,
    RTCSessionDescription description,
  ) async {
    // Feed the other person's SDP "Business Card" into our WebRTC engine
    await peerConnection.setRemoteDescription(description);
  }

  @override
  Future<void> addIceCandidate(
    RTCPeerConnection peerConnection,
    RTCIceCandidate candidate,
  ) async {
    // Feed a newly discovered network route into our WebRTC engine to test
    await peerConnection.addCandidate(candidate);
  }
}

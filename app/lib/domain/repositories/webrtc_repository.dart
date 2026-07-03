import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class WebRTCRepository {
  /// Requests Camera and Microphone permissions and returns the local video/audio stream.
  Future<MediaStream> getLocalStream();

  /// Creates a new RTCPeerConnection object to manage the WebRTC link.
  Future<RTCPeerConnection> createConnection();

  /// Creates an SDP Offer to invite another peer.
  Future<RTCSessionDescription> createOffer(RTCPeerConnection peerConnection);

  /// Creates an SDP Answer in response to an offer.
  Future<RTCSessionDescription> createAnswer(RTCPeerConnection peerConnection);

  /// Applies the Remote Description (the SDP from the other peer) to the connection.
  Future<void> setRemoteDescription(RTCPeerConnection peerConnection, RTCSessionDescription description);

  /// Adds a Network Candidate (ICE Candidate) from the other peer to the connection.
  Future<void> addIceCandidate(RTCPeerConnection peerConnection, RTCIceCandidate candidate);
}

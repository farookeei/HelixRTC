import 'dart:async';
import 'package:app/data/repositories/webrtc_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:app/domain/repositories/webrtc_repository.dart';
import 'package:app/presentation/providers/webrtc_provider.dart';
import 'package:app/domain/repositories/signaling_repository.dart';
import 'package:app/domain/models/signaling_message.dart';
import 'package:app/data/repositories/signaling_repository_impl.dart';

// ========================================================
// 1. Manual Mocks using Dart's built-in Fake class
// ========================================================
class MockMediaStreamTrack extends Fake implements MediaStreamTrack {}

class MockMediaStream extends Fake implements MediaStream {
  @override
  String get id => 'mock_stream_id';

  @override
  List<MediaStreamTrack> getTracks() => [MockMediaStreamTrack()];
}

class MockRTCRtpSender extends Fake implements RTCRtpSender {}

class MockRTCTrackEvent extends Fake implements RTCTrackEvent {
  @override
  final List<MediaStream> streams;

  MockRTCTrackEvent(this.streams);
}

class MockRTCPeerConnection extends Fake implements RTCPeerConnection {
  List<MediaStreamTrack> localTracks = [];

  @override
  void Function(RTCIceCandidate candidate)? onIceCandidate;

  @override
  void Function(RTCTrackEvent event)? onTrack;

  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async {
    localTracks.add(track);
    return MockRTCRtpSender();
  }
}

class MockRTCSessionDescription extends Fake implements RTCSessionDescription {
  @override
  final String? sdp;
  @override
  final String? type;

  MockRTCSessionDescription(this.sdp, this.type);

  @override
  Map<String, dynamic> toMap() => {'sdp': sdp, 'type': type};
}

class MockRTCIceCandidate extends Fake implements RTCIceCandidate {
  @override
  final String? candidate;
  @override
  final String? sdpMid;
  @override
  final int? sdpMLineIndex;

  MockRTCIceCandidate(this.candidate, this.sdpMid, this.sdpMLineIndex);

  @override
  Map<String, dynamic> toMap() => {
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };
}

class MockWebRTCRepository extends Fake implements WebRTCRepository {
  final MediaStream mockStream;
  MockRTCPeerConnection? createdConnection;
  RTCSessionDescription? lastRemoteDescription;
  List<RTCIceCandidate> addedCandidates = [];

  MockWebRTCRepository(this.mockStream);

  @override
  Future<MediaStream> getLocalStream() async {
    return mockStream;
  }

  @override
  Future<RTCPeerConnection> createConnection() async {
    createdConnection = MockRTCPeerConnection();
    return createdConnection!;
  }

  @override
  Future<RTCSessionDescription> createOffer(
    RTCPeerConnection peerConnection,
  ) async {
    return MockRTCSessionDescription('mock_offer_sdp', 'offer');
  }

  @override
  Future<RTCSessionDescription> createAnswer(
    RTCPeerConnection peerConnection,
  ) async {
    return MockRTCSessionDescription('mock_answer_sdp', 'answer');
  }

  @override
  Future<void> setRemoteDescription(
    RTCPeerConnection peerConnection,
    RTCSessionDescription description,
  ) async {
    lastRemoteDescription = description;
  }

  @override
  Future<void> addIceCandidate(
    RTCPeerConnection peerConnection,
    RTCIceCandidate candidate,
  ) async {
    addedCandidates.add(candidate);
  }
}

class MockSignalingRepository extends Fake implements SignalingRepository {
  bool isConnected = false;
  SignalingMessage? lastMessageSent;
  final _messageController = StreamController<SignalingMessage>.broadcast();

  @override
  Future<void> connect(String url) async {
    isConnected = true;
  }

  @override
  void sendMessage(SignalingMessage message) {
    lastMessageSent = message;
  }

  @override
  Stream<SignalingMessage> get onMessageReceived => _messageController.stream;

  void simulateIncomingMessage(SignalingMessage message) {
    _messageController.add(message);
  }
}

void main() {
  test('CallNotifier initial state has no localStream', () {
    // Create a ProviderContainer (the test version of ProviderScope)
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Read the current state of our provider
    final callState = container.read(callProvider);

    // Verify it starts as null
    expect(callState.localStream, isNull);
  });

  test('CallNotifier initializeCamera updates state with localStream', () async {
    final mockStream = MockMediaStream();
    final mockRepo = MockWebRTCRepository(mockStream);

    // Create a ProviderContainer, overriding the real repository with our Mock!
    final container = ProviderContainer(
      overrides: [webRtcRepoProvider.overrideWithValue(mockRepo)],
    );
    addTearDown(container.dispose);

    // Call initializeCamera
    await container.read(callProvider.notifier).initializeCamera();

    // Verify that the callState has been successfully updated with our mock stream
    final callState = container.read(callProvider);
    expect(callState.localStream, equals(mockStream));
    expect(callState.localStream?.id, 'mock_stream_id');
  });

  test(
    'CallNotifier joinRoom connects to signaling server and sends join message',
    () async {
      final mockSigRepo = MockSignalingRepository();

      final container = ProviderContainer(
        overrides: [signalingRepoProvider.overrideWithValue(mockSigRepo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(callProvider.notifier);

      // Call joinRoom which doesn't exist yet! (Red Phase)
      await notifier.joinRoom('1234', 'Alice');

      expect(mockSigRepo.isConnected, isTrue);
      expect(mockSigRepo.lastMessageSent, isNotNull);
      expect(mockSigRepo.lastMessageSent?.type, equals('join'));
      expect(mockSigRepo.lastMessageSent?.room, equals('1234'));
      expect(mockSigRepo.lastMessageSent?.sender, equals('Alice'));
    },
  );

  test(
    'CallNotifier creates peer connection and adds stream on peer_joined message',
    () async {
      final mockStream = MockMediaStream();
      final mockWebRtcRepo = MockWebRTCRepository(mockStream);
      final mockSigRepo = MockSignalingRepository();

      final container = ProviderContainer(
        overrides: [
          webRtcRepoProvider.overrideWithValue(mockWebRtcRepo),
          signalingRepoProvider.overrideWithValue(mockSigRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(callProvider.notifier);

      // Setup state
      await notifier.initializeCamera();
      await notifier.joinRoom('101', 'Alice');

      // Simulate incoming 'peer_joined' message
      mockSigRepo.simulateIncomingMessage(
        SignalingMessage(type: 'peer_joined', sender: 'Bob', room: '101'),
      );

      // Wait a tick for the stream to process
      await Future.delayed(const Duration(milliseconds: 10));

      final callState = container.read(callProvider);

      // VERIFY: Peer connection was created and stored in state for Bob
      expect(callState.peerConnections['Bob'], isNotNull);

      // VERIFY: local stream was added to the peer connection
      expect(mockWebRtcRepo.createdConnection, isNotNull);
      expect(mockWebRtcRepo.createdConnection!.localTracks, isNotEmpty);
    },
  );

  test(
    'CallNotifier creates and sends offer to all peers when peer_list is received',
    () async {
      final mockStream = MockMediaStream();
      final mockWebRtcRepo = MockWebRTCRepository(mockStream);
      final mockSigRepo = MockSignalingRepository();

      final container = ProviderContainer(
        overrides: [
          webRtcRepoProvider.overrideWithValue(mockWebRtcRepo),
          signalingRepoProvider.overrideWithValue(mockSigRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(callProvider.notifier);
      await notifier.initializeCamera();
      await notifier.joinRoom('101', 'Charlie');

      // Simulate incoming 'peer_list' message containing Alice and Bob
      mockSigRepo.simulateIncomingMessage(
        SignalingMessage(
          type: 'peer_list',
          peers: ['Alice', 'Bob'],
          room: '101',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // VERIFY: Offers were sent via targeted signaling
      expect(mockSigRepo.lastMessageSent?.type, equals('offer'));
      expect(mockSigRepo.lastMessageSent?.data, contains('mock_offer_sdp'));
    },
  );

  test('CallNotifier handles incoming offer and sends answer', () async {
    final mockStream = MockMediaStream();
    final mockWebRtcRepo = MockWebRTCRepository(mockStream);
    final mockSigRepo = MockSignalingRepository();

    final container = ProviderContainer(
      overrides: [
        webRtcRepoProvider.overrideWithValue(mockWebRtcRepo),
        signalingRepoProvider.overrideWithValue(mockSigRepo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(callProvider.notifier);
    await notifier.initializeCamera();
    await notifier.joinRoom('101', 'Alice');

    // Simulate incoming 'offer' message from Bob
    mockSigRepo.simulateIncomingMessage(
      SignalingMessage(
        type: 'offer',
        sender: 'Bob',
        room: '101',
        data: '{"sdp":"remote_offer_sdp","type":"offer"}',
      ),
    );

    await Future.delayed(const Duration(milliseconds: 10));

    // VERIFY: Remote description was set
    expect(
      mockWebRtcRepo.lastRemoteDescription?.sdp,
      equals('remote_offer_sdp'),
    );

    // VERIFY: An answer was sent back via targeted signaling
    expect(mockSigRepo.lastMessageSent?.type, equals('answer'));
    expect(mockSigRepo.lastMessageSent?.to, equals('Bob'));
    expect(mockSigRepo.lastMessageSent?.data, contains('mock_answer_sdp'));
  });

  test(
    'CallNotifier sends ICE candidate when local connection generates one',
    () async {
      final mockStream = MockMediaStream();
      final mockWebRtcRepo = MockWebRTCRepository(mockStream);
      final mockSigRepo = MockSignalingRepository();

      final container = ProviderContainer(
        overrides: [
          webRtcRepoProvider.overrideWithValue(mockWebRtcRepo),
          signalingRepoProvider.overrideWithValue(mockSigRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(callProvider.notifier);
      await notifier.initializeCamera();
      await notifier.joinRoom('101', 'Alice');

      // Simulate joining to initialize peer connection
      mockSigRepo.simulateIncomingMessage(
        SignalingMessage(type: 'peer_joined', sender: 'Bob', room: '101'),
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Force the mock connection to trigger its ICE candidate callback
      final mockCandidate = MockRTCIceCandidate('mock_ip_123', 'video', 0);
      mockWebRtcRepo.createdConnection!.onIceCandidate?.call(mockCandidate);

      await Future.delayed(const Duration(milliseconds: 10));

      // VERIFY: The candidate was sent via targeted signaling server
      expect(mockSigRepo.lastMessageSent?.type, equals('candidate'));
      expect(mockSigRepo.lastMessageSent?.to, equals('Bob'));
      expect(mockSigRepo.lastMessageSent?.data, contains('mock_ip_123'));
    },
  );

  test(
    'CallNotifier handles incoming ICE candidate and adds it to WebRTC',
    () async {
      final mockStream = MockMediaStream();
      final mockWebRtcRepo = MockWebRTCRepository(mockStream);
      final mockSigRepo = MockSignalingRepository();

      final container = ProviderContainer(
        overrides: [
          webRtcRepoProvider.overrideWithValue(mockWebRtcRepo),
          signalingRepoProvider.overrideWithValue(mockSigRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(callProvider.notifier);
      await notifier.initializeCamera();
      await notifier.joinRoom('101', 'Alice');

      // Simulate joining so connection exists
      mockSigRepo.simulateIncomingMessage(
        SignalingMessage(type: 'peer_joined', sender: 'Bob', room: '101'),
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Simulate incoming 'candidate' message from Bob
      mockSigRepo.simulateIncomingMessage(
        SignalingMessage(
          type: 'candidate',
          sender: 'Bob',
          room: '101',
          data:
              '{"candidate":"remote_ip_999","sdpMid":"audio","sdpMLineIndex":1}',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // VERIFY: The candidate was extracted and added to WebRTC repository
      expect(mockWebRtcRepo.addedCandidates, isNotEmpty);
      expect(
        mockWebRtcRepo.addedCandidates.first.candidate,
        equals('remote_ip_999'),
      );
    },
  );

  test(
    'CallNotifier updates state with remote stream when peerConnection fires onTrack',
    () async {
      final mockStream = MockMediaStream();
      final mockWebRtcRepo = MockWebRTCRepository(mockStream);
      final mockSigRepo = MockSignalingRepository();

      final container = ProviderContainer(
        overrides: [
          webRtcRepoProvider.overrideWithValue(mockWebRtcRepo),
          signalingRepoProvider.overrideWithValue(mockSigRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(callProvider.notifier);
      await notifier.initializeCamera();
      await notifier.joinRoom('101', 'Alice');

      // Simulate joining so connection exists
      mockSigRepo.simulateIncomingMessage(
        SignalingMessage(type: 'peer_joined', sender: 'Bob', room: '101'),
      );
      await Future.delayed(const Duration(milliseconds: 10));

      final mockRemoteStream = MockMediaStream();
      // Simulate remote peer connection adding a stream
      final mockTrackEvent = MockRTCTrackEvent([mockRemoteStream]);
      mockWebRtcRepo.createdConnection!.onTrack?.call(mockTrackEvent);

      await Future.delayed(const Duration(milliseconds: 10));

      // VERIFY: remote stream is saved to state map under 'Bob'
      final callState = container.read(callProvider);
      expect(callState.remoteStreams['Bob'], equals(mockRemoteStream));
    },
  );
}

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
class MockMediaStream extends Fake implements MediaStream {
  @override
  String get id => 'mock_stream_id';
}

class MockRTCPeerConnection extends Fake implements RTCPeerConnection {
  List<MediaStream> localStreams = [];

  @override
  void Function(RTCIceCandidate candidate)? onIceCandidate;

  @override
  void Function(MediaStream stream)? onAddStream;

  @override
  Future<void> addStream(MediaStream stream) async {
    localStreams.add(stream);
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

class MockWebRTCRepository extends Fake implements WebRTCRepository {
  final MediaStream mockStream;
  MockRTCPeerConnection? createdConnection;
  RTCSessionDescription? lastRemoteDescription;

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

      // VERIFY: Peer connection was created and stored in state
      expect(callState.peerConnection, isNotNull);

      // VERIFY: local stream was added to the peer connection
      expect(mockWebRtcRepo.createdConnection, isNotNull);
      expect(
        mockWebRtcRepo.createdConnection!.localStreams,
        contains(mockStream),
      );
    },
  );

  test(
    'CallNotifier creates and sends offer when peer_joined is received',
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

      // Simulate incoming 'peer_joined' message
      mockSigRepo.simulateIncomingMessage(
        SignalingMessage(type: 'peer_joined', sender: 'Bob', room: '101'),
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // VERIFY: An offer was sent via signaling
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

    // VERIFY: An answer was sent back via signaling
    expect(mockSigRepo.lastMessageSent?.type, equals('answer'));
    expect(mockSigRepo.lastMessageSent?.data, contains('mock_answer_sdp'));
  });
}

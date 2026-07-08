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

class MockWebRTCRepository extends Fake implements WebRTCRepository {
  final MediaStream mockStream;
  MockWebRTCRepository(this.mockStream);

  @override
  Future<MediaStream> getLocalStream() async {
    return mockStream;
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

  test('CallNotifier joinRoom connects to signaling server and sends join message', () async {
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
  });
}

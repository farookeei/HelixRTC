import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/data/repositories/signaling_repository_impl.dart';
import 'package:app/domain/models/signaling_message.dart';

void main() {
  HttpServer? mockServer;
  SignalingRepositoryImpl? repo;

  setUp(() async {
    // Spin up an in-memory local WebSocket server purely for this test!
    mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    mockServer!.transform(WebSocketTransformer()).listen((webSocket) {
      // Setup the server to echo back any messages it receives
      webSocket.listen((message) {
        webSocket.add(message);
      });
    });

    repo = SignalingRepositoryImpl();
  });

  tearDown(() async {
    // Clean up connections and stop the mock server
    try {
      repo?.disconnect();
    } catch (_) {}
    await mockServer?.close(force: true);
  });

  test('SignalingRepositoryImpl connects, sends, and receives messages', () async {
    final port = mockServer!.port;
    final url = 'ws://localhost:$port';

    // 1. Connect (This should fail right now!)
    await repo!.connect(url);

    // 2. Listen to incoming messages
    final received = <SignalingMessage>[];
    final subscription = repo!.onMessageReceived.listen(received.add);

    // 3. Send a test message
    final testMsg = SignalingMessage(type: 'join', room: '101', sender: 'Alice');
    repo!.sendMessage(testMsg);

    // 4. Wait briefly for the message to travel to the server and echo back
    await Future.delayed(const Duration(milliseconds: 100));

    // 5. Verify the echo worked
    expect(received, isNotEmpty);
    expect(received.first.type, equals('join'));
    expect(received.first.sender, equals('Alice'));

    await subscription.cancel();
  });
}

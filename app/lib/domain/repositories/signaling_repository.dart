import '../models/signaling_message.dart';

abstract class SignalingRepository {
  /// Connects to the Go WebSocket server.
  Future<void> connect(String url);

  /// Disconnects from the server.
  void disconnect();

  /// Sends a strictly-typed JSON message over the WebSocket.
  void sendMessage(SignalingMessage message);

  /// A stream that emits strongly-typed messages received from the server.
  Stream<SignalingMessage> get onMessageReceived;
}

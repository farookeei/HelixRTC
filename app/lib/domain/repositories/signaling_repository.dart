abstract class SignalingRepository {
  /// Connects to the Go WebSocket server.
  Future<void> connect(String url);

  /// Disconnects from the server.
  void disconnect();

  /// Sends a "join" message to the server to enter a room.
  void joinRoom(String roomId, String clientId);

  /// Sends a WebRTC signal (offer, answer, or candidate) to the server.
  void sendSignal(String type, String roomId, String senderId, String data);

  /// A stream that emits any incoming messages (JSON Maps) from the server.
  Stream<Map<String, dynamic>> get onSignalReceived;
}

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/models/signaling_message.dart';
import '../../domain/repositories/signaling_repository.dart';

class SignalingRepositoryImpl implements SignalingRepository {
  WebSocketChannel? _channel;

  @override
  Future<void> connect(String url) async {
    // Standard way to open a WebSocket in Dart
    _channel = WebSocketChannel.connect(Uri.parse(url));
    await _channel!.ready; // Wait for the handshake to finish
  }

  @override
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void sendMessage(SignalingMessage message) {
    if (_channel != null) {
      // 1. Convert Dart Object to a Map using our new toJson()
      // 2. Convert Map to JSON String using dart:convert
      final jsonString = jsonEncode(message.toJson());
      _channel!.sink.add(jsonString); // Push it down the WebSocket pipe!
    }
  }

  @override
  Stream<SignalingMessage> get onMessageReceived {
    if (_channel == null) {
      return const Stream.empty();
    }
    
    // We take the raw stream of strings from the WebSocket and "map" it
    return _channel!.stream.map((rawString) {
      // 1. Convert incoming String to a Map
      final jsonMap = jsonDecode(rawString as String) as Map<String, dynamic>;
      
      // 2. Convert the Map into our strongly-typed Dart Object
      return SignalingMessage.fromJson(jsonMap);
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/models/signaling_message.dart';
import '../../domain/repositories/signaling_repository.dart';

final signalingRepoProvider = Provider<SignalingRepository>((ref) {
  return SignalingRepositoryImpl();
});

class SignalingRepositoryImpl implements SignalingRepository {
  WebSocketChannel? _channel;
  final _messageController = StreamController<SignalingMessage>.broadcast();

  @override
  Future<void> connect(String url) async {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    await _channel!.ready; // Wait for connection to be established

    _channel!.stream.listen(
      (data) {
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(data);
          final message = SignalingMessage.fromJson(jsonMap);
          _messageController.add(message);
        } catch (e) {
          log('Error parsing incoming message: $e');
        }
      },
      onError: (error) {
        log('WebSocket error: $error');
      },
      onDone: () {
        log('WebSocket closed');
      },
    );
  }

  @override
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void sendMessage(SignalingMessage message) {
    if (_channel != null) {
      final jsonString = jsonEncode(message.toJson());
      _channel!.sink.add(jsonString);
    }
  }

  @override
  Stream<SignalingMessage> get onMessageReceived => _messageController.stream;

  void dispose() {
    _messageController.close();
    disconnect();
  }
}

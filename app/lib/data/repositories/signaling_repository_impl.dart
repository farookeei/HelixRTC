import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/models/signaling_message.dart';
import '../../domain/repositories/signaling_repository.dart';

final signalingRepoProvider = Provider<SignalingRepository>((ref) {
  return SignalingRepositoryImpl();
});

class SignalingRepositoryImpl implements SignalingRepository {
  @override
  Future<void> connect(String url) async {
    throw UnimplementedError('connect() not implemented yet');
  }

  @override
  void disconnect() {
    throw UnimplementedError('disconnect() not implemented yet');
  }

  @override
  void sendMessage(SignalingMessage message) {
    throw UnimplementedError('sendMessage() not implemented yet');
  }

  @override
  Stream<SignalingMessage> get onMessageReceived {
    throw UnimplementedError('onMessageReceived not implemented yet');
  }
}

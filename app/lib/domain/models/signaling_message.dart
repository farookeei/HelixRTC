class SignalingMessage {
  final String type;
  final String? sender;
  final String? target;
  final String? room;
  final String? data;

  SignalingMessage({
    required this.type,
    this.sender,
    this.target,
    this.room,
    this.data,
  });

  /// Automatically convert incoming JSON string maps into Dart Objects
  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      sender: json['sender'] as String?,
      target: json['target'] as String?,
      room: json['room'] as String?,
      data: json['data'] as String?,
    );
  }

  /// Automatically convert our Dart Objects back into JSON maps for sending
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (sender != null) 'sender': sender,
      if (target != null) 'target': target,
      if (room != null) 'room': room,
      if (data != null) 'data': data,
    };
  }
}

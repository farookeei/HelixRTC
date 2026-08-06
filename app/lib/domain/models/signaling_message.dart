class SignalingMessage {
  final String type;
  final String? sender;
  final String? to;
  final String? room;
  final String? data;
  final List<String>? peers;

  SignalingMessage({
    required this.type,
    this.sender,
    this.to,
    this.room,
    this.data,
    this.peers,
  });

  /// Automatically convert incoming JSON string maps into Dart Objects
  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      sender: json['sender'] as String?,
      to: json['to'] as String?,
      room: json['room'] as String?,
      data: json['data'] as String?,
      peers: (json['peers'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  /// Automatically convert our Dart Objects back into JSON maps for sending
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (sender != null) 'sender': sender,
      if (to != null) 'to': to,
      if (room != null) 'room': room,
      if (data != null) 'data': data,
      if (peers != null) 'peers': peers,
    };
  }
}

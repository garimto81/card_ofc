import 'dart:convert';

enum MessageType {
  joinRequest,
  joinAccepted,
  gameStart,
  dealCards,
  placeCard,
  discardCard,
  confirmPlacement,
  stateUpdate,
  roundResult,
  gameOver,
}

class NetworkMessage {
  final MessageType type;
  final Map<String, dynamic> payload;

  const NetworkMessage({required this.type, required this.payload});

  factory NetworkMessage.fromJson(Map<String, dynamic> json) {
    return NetworkMessage(
      type: MessageType.values.byName(json['type'] as String),
      payload: json['payload'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'payload': payload,
      };

  String encode() => jsonEncode(toJson());

  static NetworkMessage decode(String data) =>
      NetworkMessage.fromJson(jsonDecode(data) as Map<String, dynamic>);
}

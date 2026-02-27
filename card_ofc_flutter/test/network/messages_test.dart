import 'package:flutter_test/flutter_test.dart';
import 'package:card_ofc_flutter/network/messages.dart';

void main() {
  group('NetworkMessage', () {
    test('T1: encode/decode roundtrip', () {
      final msg = NetworkMessage(
        type: MessageType.joinRequest,
        payload: {'playerName': 'Alice'},
      );
      final encoded = msg.encode();
      final decoded = NetworkMessage.decode(encoded);
      expect(decoded.type, MessageType.joinRequest);
      expect(decoded.payload['playerName'], 'Alice');
    });

    test('T2: toJson/fromJson', () {
      final msg = NetworkMessage(
        type: MessageType.stateUpdate,
        payload: {'key': 'value'},
      );
      final json = msg.toJson();
      final restored = NetworkMessage.fromJson(json);
      expect(restored.type, MessageType.stateUpdate);
      expect(restored.payload['key'], 'value');
    });

    test('T3: all MessageType values serializable', () {
      for (final type in MessageType.values) {
        final msg = NetworkMessage(type: type, payload: {});
        final decoded = NetworkMessage.decode(msg.encode());
        expect(decoded.type, type);
      }
    });
  });
}

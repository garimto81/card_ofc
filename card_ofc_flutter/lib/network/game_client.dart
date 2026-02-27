import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/game_state.dart';
import '../models/card.dart';
import 'messages.dart';

class GameClient {
  WebSocketChannel? _channel;
  String? playerId;
  bool get isConnected => _channel != null;

  final _stateController = StreamController<GameState>.broadcast();
  Stream<GameState> get stateStream => _stateController.stream;

  final _messageController = StreamController<NetworkMessage>.broadcast();
  Stream<NetworkMessage> get messageStream => _messageController.stream;

  Future<void> connect(String host, int port) async {
    final uri = Uri.parse('ws://$host:$port');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (data) => _handleMessage(data as String),
      onDone: () => disconnect(),
      onError: (error) => disconnect(),
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void joinGame(String playerName) {
    _send(NetworkMessage(
      type: MessageType.joinRequest,
      payload: {'playerName': playerName},
    ));
  }

  void sendPlaceCard(Card card, String line) {
    _send(NetworkMessage(
      type: MessageType.placeCard,
      payload: {'card': card.toJson(), 'line': line},
    ));
  }

  void sendDiscardCard(Card card) {
    _send(NetworkMessage(
      type: MessageType.discardCard,
      payload: {'card': card.toJson()},
    ));
  }

  void sendConfirmPlacement() {
    _send(NetworkMessage(
      type: MessageType.confirmPlacement,
      payload: {'playerId': playerId ?? ''},
    ));
  }

  void _handleMessage(String data) {
    final msg = NetworkMessage.decode(data);
    _messageController.add(msg);

    switch (msg.type) {
      case MessageType.joinAccepted:
        playerId = msg.payload['playerId'] as String;
        break;
      case MessageType.stateUpdate:
        final stateJson = msg.payload['gameState'] as Map<String, dynamic>;
        final state = GameState.fromJson(stateJson);
        _stateController.add(state);
        break;
      default:
        break;
    }
  }

  void _send(NetworkMessage msg) {
    _channel?.sink.add(msg.encode());
  }

  Future<void> dispose() async {
    disconnect();
    await _stateController.close();
    await _messageController.close();
  }
}

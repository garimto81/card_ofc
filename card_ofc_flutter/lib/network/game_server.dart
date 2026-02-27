import 'dart:async';
import 'dart:io';
import '../logic/game_controller.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import 'messages.dart';

class GameServer {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final GameController _controller = GameController();
  final Map<WebSocket, String> _clientPlayerIds = {};
  final int maxPlayers;

  int get port => _server?.port ?? 0;
  int get playerCount => _clients.length;
  bool get isRunning => _server != null;

  final _stateController = StreamController<GameState>.broadcast();
  Stream<GameState> get stateStream => _stateController.stream;

  GameServer({this.maxPlayers = 3});

  Future<int> start({int port = 0}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.transform(WebSocketTransformer()).listen(_handleClient);
    return _server!.port;
  }

  Future<void> stop() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    _clientPlayerIds.clear();
    await _server?.close();
    _server = null;
    await _stateController.close();
  }

  void _handleClient(WebSocket socket) {
    _clients.add(socket);
    socket.listen(
      (data) => _handleMessage(socket, data as String),
      onDone: () {
        _clients.remove(socket);
        _clientPlayerIds.remove(socket);
      },
      onError: (error) {
        _clients.remove(socket);
        _clientPlayerIds.remove(socket);
      },
    );
  }

  void _handleMessage(WebSocket socket, String data) {
    final msg = NetworkMessage.decode(data);
    switch (msg.type) {
      case MessageType.joinRequest:
        _handleJoin(socket, msg.payload['playerName'] as String);
        break;
      case MessageType.placeCard:
        _handlePlaceCard(socket, msg.payload);
        break;
      case MessageType.discardCard:
        _handleDiscardCard(socket, msg.payload);
        break;
      case MessageType.confirmPlacement:
        _handleConfirmPlacement(socket);
        break;
      default:
        break;
    }
  }

  void _handleJoin(WebSocket socket, String playerName) {
    if (_clients.length > maxPlayers) {
      socket.close(4001, 'Server full');
      return;
    }

    final playerId = 'player_${_clientPlayerIds.length}';
    _clientPlayerIds[socket] = playerId;

    _sendTo(
      socket,
      NetworkMessage(
        type: MessageType.joinAccepted,
        payload: {'playerId': playerId},
      ),
    );
  }

  void startGame() {
    final names = _clientPlayerIds.values
        .map((id) => id.replaceFirst('player_', 'P'))
        .toList();
    final state = _controller.startGame(names);
    _broadcastState(state);
    _broadcast(NetworkMessage(
      type: MessageType.gameStart,
      payload: {'gameState': state.toJson()},
    ));
  }

  void _handlePlaceCard(WebSocket socket, Map<String, dynamic> payload) {
    final playerId = _clientPlayerIds[socket];
    if (playerId == null) return;

    final cardJson = payload['card'] as Map<String, dynamic>;
    final line = payload['line'] as String;
    final card = Card.fromJson(cardJson);

    final state = _controller.placeCard(playerId, card, line);
    if (state != null) {
      _broadcastState(state);
    }
  }

  void _handleDiscardCard(WebSocket socket, Map<String, dynamic> payload) {
    final playerId = _clientPlayerIds[socket];
    if (playerId == null) return;

    final cardJson = payload['card'] as Map<String, dynamic>;
    final card = Card.fromJson(cardJson);

    final state = _controller.discardCard(playerId, card);
    if (state != null) {
      _broadcastState(state);
    }
  }

  void _handleConfirmPlacement(WebSocket socket) {
    final playerId = _clientPlayerIds[socket];
    if (playerId == null) return;

    final state = _controller.confirmPlacement(playerId);
    _broadcastState(state);

    if (state.phase == GamePhase.scoring) {
      final scores = <String, int>{};
      for (final p in state.players) {
        scores[p.id] = p.score;
      }
      _broadcast(NetworkMessage(
        type: MessageType.roundResult,
        payload: {'scores': scores},
      ));
    }
  }

  void _broadcastState(GameState state) {
    _stateController.add(state);
    _broadcast(NetworkMessage(
      type: MessageType.stateUpdate,
      payload: {'gameState': state.toJson()},
    ));
  }

  void _broadcast(NetworkMessage msg) {
    final data = msg.encode();
    for (final client in _clients) {
      client.add(data);
    }
  }

  void _sendTo(WebSocket socket, NetworkMessage msg) {
    socket.add(msg.encode());
  }
}

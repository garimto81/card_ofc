import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/game_state.dart';
import '../models/card.dart';
import '../network/game_server.dart';
import '../network/game_client.dart';
import '../network/discovery.dart';
import '../network/messages.dart';

part 'network_game_provider.g.dart';

enum NetworkConnectionState { disconnected, connecting, connected, hosting, error }

class NetworkState {
  final NetworkConnectionState connectionState;
  final GameState? gameState;
  final String? playerId;
  final String? errorMessage;
  final int connectedPlayers;

  const NetworkState({
    this.connectionState = NetworkConnectionState.disconnected,
    this.gameState,
    this.playerId,
    this.errorMessage,
    this.connectedPlayers = 0,
  });

  NetworkState copyWith({
    NetworkConnectionState? connectionState,
    GameState? gameState,
    String? playerId,
    String? errorMessage,
    int? connectedPlayers,
  }) {
    return NetworkState(
      connectionState: connectionState ?? this.connectionState,
      gameState: gameState ?? this.gameState,
      playerId: playerId ?? this.playerId,
      errorMessage: errorMessage,
      connectedPlayers: connectedPlayers ?? this.connectedPlayers,
    );
  }
}

@Riverpod(keepAlive: true)
class NetworkGameNotifier extends _$NetworkGameNotifier {
  GameServer? _server;
  GameClient? _client;
  ServiceDiscovery? _discovery;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _messageSubscription;

  @override
  NetworkState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return const NetworkState();
  }

  Future<int> hostGame(String playerName) async {
    _cleanup();
    _server = GameServer();
    final port = await _server!.start();
    _discovery = ServiceDiscovery();
    await _discovery!.advertise(name: '$playerName\'s Game', port: port);

    // Host also connects as a client
    _client = GameClient();
    await _client!.connect('localhost', port);
    _client!.joinGame(playerName);

    _stateSubscription = _client!.stateStream.listen((gameState) {
      state = state.copyWith(
        gameState: gameState,
        connectionState: NetworkConnectionState.hosting,
      );
    });

    _messageSubscription = _client!.messageStream.listen((msg) {
      if (msg.type == MessageType.joinAccepted) {
        state = state.copyWith(
          playerId: msg.payload['playerId'] as String?,
        );
      }
    });

    state = state.copyWith(
      connectionState: NetworkConnectionState.hosting,
      playerId: 'player_0',
      connectedPlayers: 1,
    );

    return port;
  }

  Future<void> joinGame(String host, int port, String playerName) async {
    _cleanup();
    state = state.copyWith(connectionState: NetworkConnectionState.connecting);

    try {
      _client = GameClient();
      await _client!.connect(host, port);
      _client!.joinGame(playerName);

      _stateSubscription = _client!.stateStream.listen((gameState) {
        state = state.copyWith(
          gameState: gameState,
          connectionState: NetworkConnectionState.connected,
        );
      });

      _messageSubscription = _client!.messageStream.listen((msg) {
        if (msg.type == MessageType.joinAccepted) {
          state = state.copyWith(
            playerId: msg.payload['playerId'] as String?,
            connectionState: NetworkConnectionState.connected,
          );
        }
      });

      state = state.copyWith(connectionState: NetworkConnectionState.connected);
    } catch (e) {
      state = state.copyWith(
        connectionState: NetworkConnectionState.error,
        errorMessage: 'Connection failed: $e',
      );
    }
  }

  void startNetworkGame() {
    _server?.startGame();
  }

  void sendPlaceCard(Card card, String line) {
    _client?.sendPlaceCard(card, line);
  }

  void sendDiscardCard(Card card) {
    _client?.sendDiscardCard(card);
  }

  void sendConfirmPlacement() {
    _client?.sendConfirmPlacement();
  }

  int get serverPlayerCount => _server?.playerCount ?? 0;

  void disconnect() {
    _cleanup();
    state = const NetworkState();
  }

  void _cleanup() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _client?.dispose();
    _client = null;
    _server?.stop();
    _server = null;
    _discovery?.stop();
    _discovery = null;
  }
}

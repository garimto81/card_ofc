import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/game_state.dart';
import '../models/card.dart';
import '../logic/game_controller.dart';
import '../logic/simple_ai.dart';

part 'game_provider.g.dart';

@riverpod
class GameNotifier extends _$GameNotifier {
  late GameController _controller;
  bool _withAI = false;

  @override
  GameState build() {
    _controller = GameController();
    return const GameState(players: []);
  }

  /// 게임 시작 (AI 대전 옵션 포함)
  void startGame(List<String> playerNames, {bool withAI = false}) {
    _withAI = withAI;
    final names = withAI ? [...playerNames, 'AI'] : playerNames;
    state = _controller.startGame(names);
  }

  /// 카드 배치 (Committed Rule: 취소 불가)
  void placeCard(Card card, String line) {
    final currentPlayerId = state.players[state.currentPlayerIndex].id;
    final newState = _controller.placeCard(currentPlayerId, card, line);
    if (newState != null) state = newState;
  }

  /// 카드 버림 (Round 1~4)
  void discardCard(Card card) {
    final currentPlayerId = state.players[state.currentPlayerIndex].id;
    final newState = _controller.discardCard(currentPlayerId, card);
    if (newState != null) state = newState;
  }

  /// 배치 확정
  void confirmPlacement() {
    final currentPlayerId = state.players[state.currentPlayerIndex].id;
    state = _controller.confirmPlacement(currentPlayerId);

    if (_withAI && _isAITurn()) {
      _processAITurn();
    }
  }

  /// 카드 딜링
  void dealCards() {
    final currentPlayerId = state.players[state.currentPlayerIndex].id;
    if (state.roundPhase == RoundPhase.initial) {
      state = _controller.dealInitial(currentPlayerId);
    } else {
      state = _controller.dealPineapple(currentPlayerId);
    }
  }

  /// 점수 계산
  void scoreRound() {
    state = _controller.scoreRound();
  }

  /// Fantasyland 체크
  void checkFantasyland() {
    state = _controller.checkFantasyland();
  }

  /// 게임 종료 여부
  bool get isGameOver => state.phase == GamePhase.gameOver;

  bool _isAITurn() {
    final currentPlayer = state.players[state.currentPlayerIndex];
    return currentPlayer.name == 'AI';
  }

  void _processAITurn() {
    final ai = SimpleAI();
    dealCards();

    final currentPlayer = state.players[state.currentPlayerIndex];
    final decision = ai.decide(
      currentPlayer.hand,
      currentPlayer.board,
      state.currentRound,
    );

    for (final entry in decision.placements.entries) {
      placeCard(entry.key, entry.value);
    }
    if (decision.discard != null) {
      discardCard(decision.discard!);
    }
    confirmPlacement();
  }
}

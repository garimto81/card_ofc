import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/game_state.dart';
import '../models/card.dart';
import '../logic/game_controller.dart';
import '../logic/simple_ai.dart';

part 'game_provider.g.dart';

@Riverpod(keepAlive: true)
class GameNotifier extends _$GameNotifier {
  late GameController _controller;
  bool _withAI = false;

  @override
  GameState build() {
    _controller = GameController();
    return const GameState(players: []);
  }

  /// 게임 시작 + 즉시 첫 딜링 (AI 대전 옵션 포함)
  void startGame(List<String> playerNames, {bool withAI = false, int targetHands = 5}) {
    _withAI = withAI;
    final names = withAI ? [...playerNames, 'AI'] : playerNames;
    state = _controller.startGame(names, targetHands: targetHands);
    // 즉시 첫 딜링 수행 — GameScreen 진입 시 바로 핸드 표시
    _dealForCurrentPlayer();
  }

  /// 다음 핸드 시작 (multi-hand 지원)
  void nextHand() {
    state = _controller.startNextHand();
    _dealForCurrentPlayer();
    if (_withAI && _isAITurn()) {
      _processAITurnSync();
    }
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

  /// 배치 확정 → AI 자동 처리 → 다음 딜링까지 일괄 수행
  void confirmPlacement() {
    final currentPlayerId = state.players[state.currentPlayerIndex].id;
    state = _controller.confirmPlacement(currentPlayerId);

    // 스코어링 완료 → FL/gameOver 전환
    if (state.phase == GamePhase.scoring) {
      state = _controller.finishHand();
      return;
    }

    if (_withAI && _isAITurn()) {
      // AI 턴: 동기적으로 AI 배치 처리 후 인간에게 딜링
      _processAITurnSync();
    }

    // AI 턴 처리 후 (또는 2P 모드) 다음 인간 플레이어에게 딜링
    if (!_isAITurn() &&
        state.phase != GamePhase.scoring &&
        state.phase != GamePhase.fantasyland &&
        state.phase != GamePhase.gameOver) {
      _dealForCurrentPlayer();
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
    if (state.players.isEmpty) return false;
    final currentPlayer = state.players[state.currentPlayerIndex];
    return currentPlayer.name == 'AI';
  }

  /// 현재 플레이어에게 딜링
  void _dealForCurrentPlayer() {
    if (state.players.isEmpty) return;
    final currentPlayerId = state.players[state.currentPlayerIndex].id;
    if (state.roundPhase == RoundPhase.initial) {
      state = _controller.dealInitial(currentPlayerId);
    } else {
      state = _controller.dealPineapple(currentPlayerId);
    }
  }

  /// AI 턴 동기 처리 (microtask 대신 즉시 실행)
  void _processAITurnSync() {
    if (!_isAITurn()) return;

    final ai = SimpleAI();
    _dealForCurrentPlayer();

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

    // AI confirm → 라운드 전환
    final aiId = state.players[state.currentPlayerIndex].id;
    state = _controller.confirmPlacement(aiId);

    // AI confirm 후 스코어링 → FL/gameOver 전환
    if (state.phase == GamePhase.scoring) {
      state = _controller.finishHand();
    }
  }
}

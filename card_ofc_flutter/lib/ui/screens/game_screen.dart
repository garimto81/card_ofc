import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_state.dart';
import '../../models/card.dart' as ofc;
import '../../providers/game_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/board_widget.dart';
import '../widgets/hand_widget.dart';
import '../widgets/opponent_board_widget.dart';
import '../widgets/foul_warning_widget.dart';
import '../widgets/turn_indicator_widget.dart';
import 'game_over_screen.dart';
import 'score_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _hasPopped = false;

  void _onCardPlaced(ofc.Card card, String line) {
    ref.read(gameNotifierProvider.notifier).placeCard(card, line);
    _tryAutoConfirm();
  }

  void _onDiscard(ofc.Card card) {
    ref.read(gameNotifierProvider.notifier).discardCard(card);
    _tryAutoConfirm();
  }

  /// Pineapple 라운드: 2장 배치 + 1장 버림 완료 시 자동 Confirm
  void _tryAutoConfirm() {
    final state = ref.read(gameNotifierProvider);
    if (state.roundPhase == RoundPhase.pineapple && _canConfirm()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canConfirm()) _onConfirm();
      });
    }
  }

  void _onConfirm() {
    final notifier = ref.read(gameNotifierProvider.notifier);
    // confirmPlacement가 AI 처리 + 다음 딜링까지 일괄 수행
    notifier.confirmPlacement();

    final state = ref.read(gameNotifierProvider);
    if (state.phase == GamePhase.gameOver) {
      if (_hasPopped) return;
      _hasPopped = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameOverScreen()),
      );
      return;
    }
    if (state.phase == GamePhase.scoring ||
        state.phase == GamePhase.fantasyland) {
      if (_hasPopped) return;
      _hasPopped = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ScoreScreen()),
      );
      return;
    }
  }

  bool _canConfirm() {
    final state = ref.read(gameNotifierProvider);
    final current = ref.read(currentPlayerProvider);
    if (current == null) return false;

    // FL 플레이어: 보드 13장 배치 완료이면 confirm 가능
    if (current.isInFantasyland) {
      return current.board.isFull();
    }

    if (state.roundPhase == RoundPhase.initial) {
      return current.hand.isEmpty;
    } else {
      return current.hand.isEmpty &&
          ref.read(gameNotifierProvider.notifier).currentTurnDiscard != null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final availableLines = ref.watch(availableLinesProvider);

    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    if (currentPlayer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasPopped) {
          _hasPopped = true;
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final opponents = gameState.players
        .where((p) => p.id != currentPlayer.id)
        .toList();

    final isFL = currentPlayer.isInFantasyland;
    final isPineapple = gameState.roundPhase == RoundPhase.pineapple && !isFL;
    final notifier = ref.watch(gameNotifierProvider.notifier);
    final hasDiscard = notifier.currentTurnDiscard != null;
    final hasPlacements = notifier.currentTurnPlacements.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showLeaveConfirmation();
      },
      child: Scaffold(
        backgroundColor: Colors.teal[800],
        appBar: AppBar(
          title: Text('Hand ${gameState.handNumber} - R${gameState.currentRound}'),
          backgroundColor: Colors.teal[900],
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _showLeaveConfirmation(),
          ),
        ),
        body: SafeArea(
          child: Column(
          children: [
            // 상단 바: 턴 표시 + 점수
            Padding(
              padding: EdgeInsets.all(isCompact ? 4 : 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TurnIndicatorWidget(
                    currentRound: gameState.currentRound,
                    playerName: currentPlayer.name,
                    phase: gameState.phase,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (gameState.players.any((p) => p.isInFantasyland))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'FL',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.teal[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Score: ${currentPlayer.score}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isCompact ? 12 : 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 상대 보드
            if (opponents.isNotEmpty)
              SizedBox(
                height: isCompact ? 100 : 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: opponents.map((opp) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OpponentBoardWidget(
                        opponent: opp,
                        hideCards: opp.isInFantasyland,
                      ),
                    );
                  }).toList(),
                ),
              ),

            const Spacer(),

            // 내 보드
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
              child: FoulWarningWidget(
                isFoul: ref.watch(isFoulRiskProvider),
                child: BoardWidget(
                  board: currentPlayer.board,
                  availableLines: availableLines,
                  onCardPlaced: _onCardPlaced,
                  currentTurnPlacements: notifier.currentTurnPlacements,
                  onUndoCard: (card, line) {
                    ref.read(gameNotifierProvider.notifier).undoPlaceCard(card, line);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // FL 안내 배너
            if (isFL && currentPlayer.hand.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Fantasyland: Place 13 cards. Remaining cards will be auto-discarded.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (isFL && currentPlayer.hand.isNotEmpty)
              const SizedBox(height: 4),

            // 내 핸드
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
              child: HandWidget(
                cards: currentPlayer.hand,
                showDiscardButtons: isPineapple,
                hasDiscarded: hasDiscard,
                onDiscard: _onDiscard,
                onCardTap: null,
                onConfirm: _canConfirm() ? _onConfirm : null,
                canConfirm: _canConfirm(),
              ),
            ),

            // Undo All + Confirm 버튼
            Padding(
              padding: EdgeInsets.all(isCompact ? 8 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (hasPlacements || hasDiscard)
                    TextButton.icon(
                      onPressed: () {
                        ref.read(gameNotifierProvider.notifier).undoAllCurrentTurn();
                      },
                      icon: Icon(Icons.undo, color: Colors.amber[300], size: 18),
                      label: Text('Undo All',
                          style: TextStyle(
                              color: Colors.amber[300],
                              fontSize: isCompact ? 12 : 14)),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  if (!(isPineapple && currentPlayer.hand.isEmpty && _canConfirm()))
                    ElevatedButton(
                      onPressed: _canConfirm() ? _onConfirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 24, vertical: 12),
                      ),
                      child: Text('Confirm',
                          style: TextStyle(fontSize: isCompact ? 14 : 16)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _showLeaveConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text(
            'Are you sure you want to leave? Current progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child:
                const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

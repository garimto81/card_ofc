import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card.dart' as ofc;
import '../../models/game_state.dart';
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
  ofc.Card? _selectedDiscard;

  // startGame()에서 이미 딜링 완료 — initState에서 추가 딜링 불필요

  void _onCardPlaced(ofc.Card card, String line) {
    ref.read(gameNotifierProvider.notifier).placeCard(card, line);
  }

  void _onDiscard(ofc.Card card) {
    setState(() => _selectedDiscard = card);
    ref.read(gameNotifierProvider.notifier).discardCard(card);
  }

  void _onConfirm() {
    setState(() => _selectedDiscard = null);
    final notifier = ref.read(gameNotifierProvider.notifier);
    // confirmPlacement가 AI 처리 + 다음 딜링까지 일괄 수행
    notifier.confirmPlacement();

    final state = ref.read(gameNotifierProvider);
    if (state.phase == GamePhase.gameOver) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameOverScreen()),
      );
      return;
    }
    if (state.phase == GamePhase.scoring ||
        state.phase == GamePhase.fantasyland) {
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

    if (state.roundPhase == RoundPhase.initial) {
      // R0: 5장 모두 배치해야 확정 가능
      return current.hand.isEmpty;
    } else {
      // R1~R4 Pineapple: 3장 중 2장 배치 + 1장 버리기 완료
      return current.hand.isEmpty && _selectedDiscard != null;
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
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final opponents = gameState.players
        .where((p) => p.id != currentPlayer.id)
        .toList();

    final isPineapple = gameState.roundPhase == RoundPhase.pineapple;
    final canDiscard = isPineapple && _selectedDiscard == null;

    return Scaffold(
      backgroundColor: Colors.teal[800],
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
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 내 핸드
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16),
              child: HandWidget(
                cards: currentPlayer.hand,
                onCardTap: (card) {
                  if (gameState.roundPhase == RoundPhase.pineapple &&
                      _selectedDiscard == null) {
                    _onDiscard(card);
                  }
                },
              ),
            ),

            // 버리기 존 + 확인 버튼
            Padding(
              padding: EdgeInsets.all(isCompact ? 8 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isPineapple)
                    DragTarget<ofc.Card>(
                      onWillAcceptWithDetails: (details) =>
                          _selectedDiscard == null,
                      onAcceptWithDetails: (details) =>
                          _onDiscard(details.data),
                      builder: (context, candidateData, rejectedData) {
                        final isHovering = candidateData.isNotEmpty;
                        final hasDiscard = _selectedDiscard != null;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isCompact ? 56 : 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: hasDiscard
                                ? Colors.red[50]
                                : (isHovering
                                    ? Colors.red[100]
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasDiscard
                                  ? Colors.red
                                  : (isHovering
                                      ? Colors.red
                                      : (canDiscard
                                          ? Colors.red[300]!
                                          : Colors.red[200]!)),
                              width: isHovering || canDiscard ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: hasDiscard
                                ? const Icon(Icons.delete,
                                    color: Colors.red, size: 24)
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: canDiscard
                                              ? Colors.red[300]
                                              : Colors.red[200],
                                          size: 20),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Discard',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: canDiscard
                                              ? Colors.red[300]
                                              : Colors.red[200],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  const Spacer(),
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
    );
  }
}

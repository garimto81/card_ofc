import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/card.dart' as ofc;
import '../../models/game_state.dart';
import '../../providers/game_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/board_widget.dart';
import '../widgets/hand_widget.dart';
import '../widgets/opponent_board_widget.dart';
import '../widgets/turn_indicator_widget.dart';
import 'score_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  ofc.Card? _selectedDiscard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameNotifierProvider.notifier).dealCards();
    });
  }

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
    notifier.confirmPlacement();

    final state = ref.read(gameNotifierProvider);
    if (state.currentRound > 4 || state.phase == GamePhase.scoring) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ScoreScreen()),
      );
      return;
    }

    notifier.dealCards();
  }

  bool _canConfirm() {
    final state = ref.read(gameNotifierProvider);
    final current = ref.read(currentPlayerProvider);
    if (current == null) return false;

    if (state.roundPhase == RoundPhase.initial) {
      return current.hand.isEmpty;
    } else {
      return current.hand.isEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final availableLines = ref.watch(availableLinesProvider);

    if (currentPlayer == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final opponents = gameState.players
        .where((p) => p.id != currentPlayer.id)
        .toList();

    return Scaffold(
      backgroundColor: Colors.teal[800],
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바: 턴 표시 + 점수
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TurnIndicatorWidget(
                    currentRound: gameState.currentRound,
                    playerName: currentPlayer.name,
                    phase: gameState.phase,
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
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // 상대 보드
            if (opponents.isNotEmpty)
              SizedBox(
                height: 120,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BoardWidget(
                board: currentPlayer.board,
                availableLines: availableLines,
                onCardPlaced: _onCardPlaced,
              ),
            ),

            const SizedBox(height: 16),

            // 내 핸드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (gameState.roundPhase == RoundPhase.pineapple)
                    DragTarget<ofc.Card>(
                      onWillAcceptWithDetails: (details) =>
                          _selectedDiscard == null,
                      onAcceptWithDetails: (details) =>
                          _onDiscard(details.data),
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          width: 60,
                          height: 70,
                          decoration: BoxDecoration(
                            color: candidateData.isNotEmpty
                                ? Colors.red[100]
                                : Colors.red[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: candidateData.isNotEmpty
                                  ? Colors.red
                                  : Colors.red[200]!,
                            ),
                          ),
                          child: Center(
                            child: _selectedDiscard != null
                                ? const Icon(Icons.delete, color: Colors.red)
                                : const Text(
                                    'Discard',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.red),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Confirm', style: TextStyle(fontSize: 16)),
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

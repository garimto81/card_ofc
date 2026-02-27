import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/game_state.dart';

class TurnIndicatorWidget extends StatelessWidget {
  final int currentRound;
  final String playerName;
  final GamePhase phase;

  const TurnIndicatorWidget({
    super.key,
    required this.currentRound,
    required this.playerName,
    required this.phase,
  });

  String get _phaseLabel {
    switch (phase) {
      case GamePhase.waiting:
        return 'Waiting';
      case GamePhase.dealing:
        return 'Dealing';
      case GamePhase.placing:
        return 'Placing';
      case GamePhase.scoring:
        return 'Scoring';
      case GamePhase.fantasyland:
        return 'Fantasyland';
      case GamePhase.gameOver:
        return 'Game Over';
    }
  }

  bool get _isActive =>
      phase == GamePhase.placing || phase == GamePhase.dealing;

  @override
  Widget build(BuildContext context) {
    final indicator = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.teal[700],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'R$currentRound',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: Colors.white30,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Text(
            '$playerName \u00B7 $_phaseLabel',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );

    if (_isActive) {
      return indicator
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.04, duration: 800.ms, curve: Curves.easeInOut);
    }

    return indicator;
  }
}

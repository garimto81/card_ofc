import 'package:flutter/material.dart';
import '../../models/board.dart';
import '../../models/player.dart';
import '../../models/card.dart' as ofc;
import 'card_widget.dart';

class OpponentBoardWidget extends StatelessWidget {
  final Player opponent;
  final bool hideCards;

  const OpponentBoardWidget({
    super.key,
    required this.opponent,
    this.hideCards = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${opponent.name} (${opponent.score}pt)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _buildMiniLine(opponent.board.top, OFCBoard.topMaxCards),
            const SizedBox(height: 2),
            _buildMiniLine(opponent.board.mid, OFCBoard.midMaxCards),
            const SizedBox(height: 2),
            _buildMiniLine(opponent.board.bottom, OFCBoard.bottomMaxCards),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniLine(List<ofc.Card> cards, int maxCards) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxCards, (i) {
        if (i < cards.length) {
          return Padding(
            padding: const EdgeInsets.all(1),
            child: SizedBox(
              width: 28,
              height: 36,
              child: CardWidget(
                card: cards[i],
                faceDown: hideCards,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(1),
          child: Container(
            width: 28,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.grey[300]!),
            ),
          ),
        );
      }),
    );
  }
}

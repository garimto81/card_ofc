import 'package:flutter/material.dart';
import '../../models/board.dart';
import '../../models/card.dart' as ofc;
import 'line_slot_widget.dart';

class BoardWidget extends StatelessWidget {
  final OFCBoard board;
  final List<String> availableLines;
  final void Function(ofc.Card card, String line)? onCardPlaced;

  const BoardWidget({
    super.key,
    required this.board,
    this.availableLines = const ['top', 'mid', 'bottom'],
    this.onCardPlaced,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLine('Top', board.top, OFCBoard.topMaxCards, 'top'),
        const SizedBox(height: 8),
        _buildLine('Mid', board.mid, OFCBoard.midMaxCards, 'mid'),
        const SizedBox(height: 8),
        _buildLine('Bottom', board.bottom, OFCBoard.bottomMaxCards, 'bottom'),
      ],
    );
  }

  Widget _buildLine(
      String label, List<ofc.Card> cards, int maxCards, String lineName) {
    final canAccept = availableLines.contains(lineName);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        ...List.generate(maxCards, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: LineSlotWidget(
              card: i < cards.length ? cards[i] : null,
              lineName: lineName,
              canAccept: canAccept && i >= cards.length,
              onCardDropped: (card) => onCardPlaced?.call(card, lineName),
            ),
          );
        }),
      ],
    );
  }
}

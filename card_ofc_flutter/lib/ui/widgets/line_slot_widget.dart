import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/card.dart' as ofc;
import 'card_widget.dart';

class LineSlotWidget extends StatelessWidget {
  final ofc.Card? card;
  final String lineName;
  final bool canAccept;
  final void Function(ofc.Card card)? onCardDropped;

  const LineSlotWidget({
    super.key,
    this.card,
    required this.lineName,
    this.canAccept = true,
    this.onCardDropped,
  });

  @override
  Widget build(BuildContext context) {
    if (card != null) {
      return CardWidget(card: card!)
          .animate()
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: 300.ms,
            curve: Curves.easeOutBack,
          )
          .fadeIn(duration: 200.ms);
    }

    return DragTarget<ofc.Card>(
      onWillAcceptWithDetails: (details) => canAccept,
      onAcceptWithDetails: (details) {
        onCardDropped?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            color: isHovering
                ? Colors.green[100]
                : (canAccept ? Colors.grey[200] : Colors.grey[100]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovering
                  ? Colors.green
                  : (canAccept ? Colors.grey[400]! : Colors.grey[300]!),
              width: isHovering ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              canAccept ? '+' : '',
              style: TextStyle(
                color: canAccept ? Colors.grey[500] : Colors.grey[300],
                fontSize: 18,
              ),
            ),
          ),
        );
      },
    );
  }
}

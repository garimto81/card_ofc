import 'package:flutter/material.dart';
import '../../models/card.dart' as ofc;

class CardWidget extends StatelessWidget {
  final ofc.Card card;
  final bool faceDown;
  final bool draggable;
  final VoidCallback? onTap;

  const CardWidget({
    super.key,
    required this.card,
    this.faceDown = false,
    this.draggable = false,
    this.onTap,
  });

  Color get _suitColor {
    switch (card.suit) {
      case ofc.Suit.heart:
      case ofc.Suit.diamond:
        return Colors.red;
      case ofc.Suit.spade:
      case ofc.Suit.club:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (faceDown) {
      return Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.blue[800],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: const Center(
          child: Icon(Icons.help_outline, color: Colors.white30, size: 20),
        ),
      );
    }

    final cardContent = Container(
      width: 50,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[400]!, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.rank.rankName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _suitColor,
            ),
          ),
          Text(
            card.suit.suitSymbol,
            style: TextStyle(fontSize: 14, color: _suitColor),
          ),
        ],
      ),
    );

    if (draggable) {
      return LongPressDraggable<ofc.Card>(
        data: card,
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(6),
          child: cardContent,
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
        child: GestureDetector(onTap: onTap, child: cardContent),
      );
    }

    return GestureDetector(onTap: onTap, child: cardContent);
  }
}

import 'package:flutter/material.dart';
import '../../models/card.dart' as ofc;
import 'card_widget.dart';

class HandWidget extends StatelessWidget {
  final List<ofc.Card> cards;
  final void Function(ofc.Card card)? onCardTap;

  const HandWidget({
    super.key,
    required this.cards,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox(
        height: 70,
        child: Center(
          child: Text('No cards', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: cards.map((card) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: CardWidget(
              card: card,
              draggable: true,
              onTap: () => onCardTap?.call(card),
            ),
          );
        }).toList(),
      ),
    );
  }
}

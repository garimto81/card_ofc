import 'package:flutter/material.dart';
import '../../models/card.dart' as ofc;
import 'card_widget.dart';

class HandWidget extends StatelessWidget {
  final List<ofc.Card> cards;
  final void Function(ofc.Card card)? onCardTap;
  final bool showDiscardButtons;
  final bool hasDiscarded;
  final void Function(ofc.Card card)? onDiscard;

  const HandWidget({
    super.key,
    required this.cards,
    this.onCardTap,
    this.showDiscardButtons = false,
    this.hasDiscarded = false,
    this.onDiscard,
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
      height: showDiscardButtons ? 104 : 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: cards.map((card) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CardWidget(
                  card: card,
                  draggable: true,
                  onTap: () => onCardTap?.call(card),
                ),
                if (showDiscardButtons)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: hasDiscarded ? null : () => onDiscard?.call(card),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              hasDiscarded ? Colors.grey[300] : Colors.red[400],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Discard',
                          style: TextStyle(
                            color: hasDiscarded
                                ? Colors.grey[500]
                                : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

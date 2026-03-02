import 'package:flutter/material.dart';
import '../../models/card.dart' as ofc;
import 'card_widget.dart';

class HandWidget extends StatelessWidget {
  final List<ofc.Card> cards;
  final void Function(ofc.Card card)? onCardTap;
  final bool showDiscardButtons;
  final bool hasDiscarded;
  final void Function(ofc.Card card)? onDiscard;
  final VoidCallback? onConfirm;
  final bool canConfirm;

  const HandWidget({
    super.key,
    required this.cards,
    this.onCardTap,
    this.showDiscardButtons = false,
    this.hasDiscarded = false,
    this.onDiscard,
    this.onConfirm,
    this.canConfirm = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      if (canConfirm && onConfirm != null) {
        return SizedBox(
          height: showDiscardButtons ? 104 : 80,
          child: Center(
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Confirm', style: TextStyle(fontSize: 16)),
            ),
          ),
        );
      }
      return const SizedBox(
        height: 70,
        child: Center(
          child: Text('No cards', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // FL mode (>5 cards): use Wrap for multi-row layout
    if (cards.length > 5) {
      // 70px card height + 4px run spacing per row; 2 rows for up to 17 cards
      final rows = (cards.length / 9).ceil();
      final wrapHeight = rows * 74.0 + (rows - 1) * 4.0;
      return SizedBox(
        height: wrapHeight,
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: cards.map((card) {
              return CardWidget(
                card: card,
                draggable: true,
                onTap: () => onCardTap?.call(card),
              );
            }).toList(),
          ),
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

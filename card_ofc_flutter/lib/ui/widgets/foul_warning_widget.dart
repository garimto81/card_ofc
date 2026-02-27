import 'package:flutter/material.dart';

class FoulWarningWidget extends StatelessWidget {
  final bool isFoul;
  final Widget child;

  const FoulWarningWidget({
    super.key,
    required this.isFoul,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isFoul
          ? BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFoul)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
              child: const Text(
                'FOUL - Invalid Board!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

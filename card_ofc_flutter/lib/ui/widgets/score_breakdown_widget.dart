import 'package:flutter/material.dart';

class LineResult {
  final String lineName;
  final String player1Hand;
  final String player2Hand;
  final int player1Points;
  final int player2Points;

  const LineResult({
    required this.lineName,
    required this.player1Hand,
    required this.player2Hand,
    required this.player1Points,
    required this.player2Points,
  });
}

class ScoreBreakdownWidget extends StatelessWidget {
  final String player1Name;
  final String player2Name;
  final List<LineResult> lineResults;
  final int player1Royalty;
  final int player2Royalty;
  final bool isScoop;
  final int player1Total;
  final int player2Total;

  const ScoreBreakdownWidget({
    super.key,
    required this.player1Name,
    required this.player2Name,
    required this.lineResults,
    this.player1Royalty = 0,
    this.player2Royalty = 0,
    this.isScoop = false,
    this.player1Total = 0,
    this.player2Total = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.teal[800],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(player1Name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      textAlign: TextAlign.center),
                ),
                const Text('VS',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Expanded(
                  child: Text(player2Name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      textAlign: TextAlign.center),
                ),
              ],
            ),
            const Divider(color: Colors.teal),
            // Line results
            ...lineResults.map((lr) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${lr.player1Hand} (${_formatPoints(lr.player1Points)})',
                          style: TextStyle(
                            color: lr.player1Points > lr.player2Points
                                ? Colors.green[300]
                                : Colors.white70,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          lr.lineName,
                          style: TextStyle(
                              color: Colors.teal[300], fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${lr.player2Hand} (${_formatPoints(lr.player2Points)})',
                          style: TextStyle(
                            color: lr.player2Points > lr.player1Points
                                ? Colors.green[300]
                                : Colors.white70,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(color: Colors.teal),
            // Royalty
            if (player1Royalty != 0 || player2Royalty != 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Royalty: ${_formatPoints(player1Royalty)}',
                        style:
                            TextStyle(color: Colors.amber[300], fontSize: 12)),
                    Text('Royalty: ${_formatPoints(player2Royalty)}',
                        style:
                            TextStyle(color: Colors.amber[300], fontSize: 12)),
                  ],
                ),
              ),
            // Scoop indicator
            if (isScoop)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('SCOOP! +3 Bonus',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            const SizedBox(height: 8),
            // Totals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ${_formatPoints(player1Total)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('Total: ${_formatPoints(player2Total)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPoints(int points) {
    return points > 0 ? '+$points' : '$points';
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/card.dart';
import '../logic/foul_checker.dart';
import '../logic/hand_evaluator.dart';
import '../logic/royalty.dart';
import 'game_provider.dart';

part 'score_detail_provider.g.dart';

class MatchupDetail {
  final String player1Name;
  final String player2Name;
  final String topResult1;
  final String topResult2;
  final String midResult1;
  final String midResult2;
  final String bottomResult1;
  final String bottomResult2;
  final int topWinner; // -1 (p1 wins), 0 (tie), 1 (p2 wins)
  final int midWinner;
  final int bottomWinner;
  final int player1Royalty;
  final int player2Royalty;
  final bool isScoop;
  final int player1Total;
  final int player2Total;

  const MatchupDetail({
    required this.player1Name,
    required this.player2Name,
    required this.topResult1,
    required this.topResult2,
    required this.midResult1,
    required this.midResult2,
    required this.bottomResult1,
    required this.bottomResult2,
    required this.topWinner,
    required this.midWinner,
    required this.bottomWinner,
    this.player1Royalty = 0,
    this.player2Royalty = 0,
    this.isScoop = false,
    this.player1Total = 0,
    this.player2Total = 0,
  });
}

@riverpod
List<MatchupDetail> scoreDetails(Ref ref) {
  final gameState = ref.watch(gameNotifierProvider);
  final players = gameState.players;
  if (players.length < 2) return [];

  final details = <MatchupDetail>[];

  for (int i = 0; i < players.length; i++) {
    for (int j = i + 1; j < players.length; j++) {
      final p1 = players[i];
      final p2 = players[j];

      final p1Foul = checkFoul(p1.board);
      final p2Foul = checkFoul(p2.board);

      String handName(List<Card> cards) {
        if (cards.isEmpty) return '-';
        final result = evaluateHand(cards);
        return result.handType.name;
      }

      int lineWinner(List<Card> c1, List<Card> c2, bool f1, bool f2) {
        if (f1 && f2) return 0;
        if (f1) return 1; // p2 wins
        if (f2) return -1; // p1 wins
        if (c1.isEmpty || c2.isEmpty) return 0;
        final h1 = evaluateHand(c1);
        final h2 = evaluateHand(c2);
        return compareHands(h1, h2);
      }

      final topW =
          lineWinner(p1.board.top, p2.board.top, p1Foul, p2Foul);
      final midW =
          lineWinner(p1.board.mid, p2.board.mid, p1Foul, p2Foul);
      final botW =
          lineWinner(p1.board.bottom, p2.board.bottom, p1Foul, p2Foul);

      final p1Wins = [topW, midW, botW].where((w) => w > 0).length;
      final p2Wins = [topW, midW, botW].where((w) => w < 0).length;
      final scoop = p1Wins == 3 || p2Wins == 3;

      final r1 = p1.board.isFull()
          ? calcBoardRoyalty(p1.board)
          : const RoyaltyResult(top: 0, mid: 0, bottom: 0);
      final r2 = p2.board.isFull()
          ? calcBoardRoyalty(p2.board)
          : const RoyaltyResult(top: 0, mid: 0, bottom: 0);

      int p1Total = 0;
      int p2Total = 0;
      if (!p1Foul && !p2Foul) {
        p1Total = p1Wins.toInt() -
            p2Wins.toInt() +
            (scoop && p1Wins == 3 ? 3 : 0) +
            r1.total;
        p2Total = p2Wins.toInt() -
            p1Wins.toInt() +
            (scoop && p2Wins == 3 ? 3 : 0) +
            r2.total;
      } else if (p1Foul && !p2Foul) {
        p2Total = 6 + r2.total;
        p1Total = -6;
      } else if (!p1Foul && p2Foul) {
        p1Total = 6 + r1.total;
        p2Total = -6;
      }

      details.add(MatchupDetail(
        player1Name: p1.name,
        player2Name: p2.name,
        topResult1: handName(p1.board.top),
        topResult2: handName(p2.board.top),
        midResult1: handName(p1.board.mid),
        midResult2: handName(p2.board.mid),
        bottomResult1: handName(p1.board.bottom),
        bottomResult2: handName(p2.board.bottom),
        topWinner: topW,
        midWinner: midW,
        bottomWinner: botW,
        player1Royalty: p1Foul ? 0 : r1.total,
        player2Royalty: p2Foul ? 0 : r2.total,
        isScoop: scoop,
        player1Total: p1Total,
        player2Total: p2Total,
      ));
    }
  }

  return details;
}

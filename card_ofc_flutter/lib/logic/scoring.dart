import '../models/card.dart';
import '../models/player.dart';
import 'foul_checker.dart';
import 'hand_evaluator.dart';
import 'royalty.dart';

/// OFC Pineapple 스코어링: 1-6 Pairwise 방식
/// 반환값: { playerId: netScore }
Map<String, int> calculateScores(List<Player> players) {
  final scores = <String, int>{};
  for (final p in players) {
    scores[p.id] = 0;
  }

  // Pairwise 비교
  for (int i = 0; i < players.length; i++) {
    for (int j = i + 1; j < players.length; j++) {
      final p1 = players[i];
      final p2 = players[j];
      final result = _scoreHeadToHead(p1, p2);
      scores[p1.id] = scores[p1.id]! + result;
      scores[p2.id] = scores[p2.id]! - result;
    }
  }

  return scores;
}

/// p1 vs p2 점수를 p1 기준으로 반환 (양수=p1 승, 음수=p2 승)
int _scoreHeadToHead(Player p1, Player p2) {
  final p1Foul = checkFoul(p1.board);
  final p2Foul = checkFoul(p2.board);

  // 양쪽 모두 Foul → 상쇄
  if (p1Foul && p2Foul) return 0;

  final p1Royalty = calcBoardRoyalty(p1.board);
  final p2Royalty = calcBoardRoyalty(p2.board);

  // p1만 Foul → p1이 -6 - p2 royalty, p2가 +6 + p2 royalty
  if (p1Foul) {
    return -(6 + p2Royalty.total);
  }

  // p2만 Foul → p1이 +6 + p1 royalty, p2가 -6 - p1 royalty
  if (p2Foul) {
    return 6 + p1Royalty.total;
  }

  // 둘 다 정상: 라인 비교
  final lineScore = _compareLines(p1, p2);
  final royaltyDiff = p1Royalty.total - p2Royalty.total;

  return lineScore + royaltyDiff;
}

/// 3라인 비교 점수 (스쿱 보너스 포함)
int _compareLines(Player p1, Player p2) {
  final topCmp = _compareLine(p1.board.top, p2.board.top);
  final midCmp = _compareLine(p1.board.mid, p2.board.mid);
  final bottomCmp = _compareLine(p1.board.bottom, p2.board.bottom);

  // 각 라인: 이기면 +1, 지면 -1, 무승부 0
  int score = topCmp + midCmp + bottomCmp;

  // 스쿱: 3라인 모두 이기면 +3 추가
  final p1Wins = [topCmp, midCmp, bottomCmp].where((v) => v > 0).length;
  final p2Wins = [topCmp, midCmp, bottomCmp].where((v) => v < 0).length;

  if (p1Wins == 3) score += 3;
  if (p2Wins == 3) score -= 3;

  return score;
}

/// 단일 라인 비교: +1 (p1 승), -1 (p2 승), 0 (무승부)
int _compareLine(List<Card> cards1, List<Card> cards2) {
  if (cards1.isEmpty || cards2.isEmpty) return 0;
  final h1 = evaluateHand(List.from(cards1));
  final h2 = evaluateHand(List.from(cards2));
  return compareHands(h1, h2);
}

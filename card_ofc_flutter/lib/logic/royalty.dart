import '../models/board.dart';
import '../models/hand_result.dart';
import 'hand_evaluator.dart';

class RoyaltyResult {
  final int top;
  final int mid;
  final int bottom;
  final int total;

  const RoyaltyResult({
    required this.top,
    required this.mid,
    required this.bottom,
  }) : total = top + mid + bottom;
}

/// 라인별 로얄티 계산 (OFC Pineapple 표준)
int calcLineRoyalty(String line, HandResult hand) {
  switch (line) {
    case 'bottom':
      return _bottomRoyalty(hand);
    case 'mid':
      return _midRoyalty(hand);
    case 'top':
      return _topRoyalty(hand);
    default:
      return 0;
  }
}

/// 보드 전체 로얄티 계산
RoyaltyResult calcBoardRoyalty(OFCBoard board) {
  if (board.top.isEmpty || board.mid.isEmpty || board.bottom.isEmpty) {
    return const RoyaltyResult(top: 0, mid: 0, bottom: 0);
  }
  final topResult = evaluateHand(board.top);
  final midResult = evaluateHand(board.mid);
  final bottomResult = evaluateHand(board.bottom);

  return RoyaltyResult(
    top: calcLineRoyalty('top', topResult),
    mid: calcLineRoyalty('mid', midResult),
    bottom: calcLineRoyalty('bottom', bottomResult),
  );
}

// ─── Bottom 로얄티 ───────────────────────────────────────────────────────────

int _bottomRoyalty(HandResult hand) {
  switch (hand.handType) {
    case HandType.straight:
      return 2;
    case HandType.flush:
      return 4;
    case HandType.fullHouse:
      return 6;
    case HandType.fourOfAKind:
      return 10;
    case HandType.straightFlush:
      return 15;
    case HandType.royalFlush:
      return 25;
    default:
      return 0;
  }
}

// ─── Mid 로얄티 ─────────────────────────────────────────────────────────────

int _midRoyalty(HandResult hand) {
  switch (hand.handType) {
    case HandType.threeOfAKind:
      return 2;
    case HandType.straight:
      return 4;
    case HandType.flush:
      return 8;
    case HandType.fullHouse:
      return 12;
    case HandType.fourOfAKind:
      return 20;
    case HandType.straightFlush:
      return 30;
    case HandType.royalFlush:
      return 50;
    default:
      return 0;
  }
}

// ─── Top 로얄티 (3장) ────────────────────────────────────────────────────────

int _topRoyalty(HandResult hand) {
  if (hand.handType == HandType.threeOfAKind) {
    // 쓰리오브어카인드: 222=10 ~ AAA=22
    // kickers[0] = trips rank
    final rank = hand.kickers.isNotEmpty ? hand.kickers[0] : 0;
    // rank 2=10, 3=11, ... 14=22
    return 8 + rank;
  }

  if (hand.handType == HandType.onePair) {
    // 페어: 66=1, 77=2, ... AA=9
    // kickers[0] = pair rank
    final rank = hand.kickers.isNotEmpty ? hand.kickers[0] : 0;
    if (rank < 6) return 0;
    return rank - 5;
  }

  return 0;
}

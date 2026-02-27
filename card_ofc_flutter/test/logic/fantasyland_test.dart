import 'package:flutter_test/flutter_test.dart';
import 'package:card_ofc_flutter/models/card.dart';
import 'package:card_ofc_flutter/models/board.dart';
import 'package:card_ofc_flutter/logic/fantasyland.dart';

OFCBoard buildFullBoard({
  required List<Card> top,
  required List<Card> mid,
  required List<Card> bottom,
}) {
  return OFCBoard(top: top, mid: mid, bottom: bottom);
}

void main() {
  group('FantasylandChecker.canEnter', () {
    // T1: Top QQ, Mid 투페어(KK+99), Bottom 풀하우스(JJJ+88) — Foul 없음
    test('T1: Top QQ + no Foul + full board → canEnter=true, count=14', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.queen, suit: Suit.spade),
          Card(rank: Rank.queen, suit: Suit.heart),
          Card(rank: Rank.two, suit: Suit.club),
        ],
        mid: [
          Card(rank: Rank.king, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.nine, suit: Suit.spade),
          Card(rank: Rank.nine, suit: Suit.heart),
          Card(rank: Rank.three, suit: Suit.club),
        ],
        bottom: [
          Card(rank: Rank.jack, suit: Suit.spade),
          Card(rank: Rank.jack, suit: Suit.heart),
          Card(rank: Rank.jack, suit: Suit.diamond),
          Card(rank: Rank.eight, suit: Suit.spade),
          Card(rank: Rank.eight, suit: Suit.heart),
        ],
      );
      expect(FantasylandChecker.canEnter(board), isTrue);
      expect(FantasylandChecker.getEntryCardCount(board), 14);
    });

    // T2: Top KK, Mid 투페어(AA+99), Bottom 풀하우스(TTT+88)
    test('T2: Top KK + no Foul + full board → canEnter=true, count=15', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.king, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.two, suit: Suit.club),
        ],
        mid: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
          Card(rank: Rank.nine, suit: Suit.spade),
          Card(rank: Rank.nine, suit: Suit.heart),
          Card(rank: Rank.three, suit: Suit.club),
        ],
        bottom: [
          Card(rank: Rank.ten, suit: Suit.spade),
          Card(rank: Rank.ten, suit: Suit.heart),
          Card(rank: Rank.ten, suit: Suit.diamond),
          Card(rank: Rank.eight, suit: Suit.spade),
          Card(rank: Rank.eight, suit: Suit.heart),
        ],
      );
      expect(FantasylandChecker.canEnter(board), isTrue);
      expect(FantasylandChecker.getEntryCardCount(board), 15);
    });

    // T3: Top AA, Mid 풀하우스(KKK+QQ), Bottom 포카드(JJJ+2)
    test('T3: Top AA + no Foul + full board → canEnter=true, count=16', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
          Card(rank: Rank.two, suit: Suit.club),
        ],
        mid: [
          Card(rank: Rank.king, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.king, suit: Suit.diamond),
          Card(rank: Rank.queen, suit: Suit.spade),
          Card(rank: Rank.queen, suit: Suit.heart),
        ],
        bottom: [
          Card(rank: Rank.jack, suit: Suit.spade),
          Card(rank: Rank.jack, suit: Suit.heart),
          Card(rank: Rank.jack, suit: Suit.diamond),
          Card(rank: Rank.jack, suit: Suit.club),
          Card(rank: Rank.three, suit: Suit.spade),
        ],
      );
      expect(FantasylandChecker.canEnter(board), isTrue);
      expect(FantasylandChecker.getEntryCardCount(board), 16);
    });

    // T4: Top Trips(777), Mid 풀하우스(KKK+99), Bottom 포카드(AAAA+2)
    test('T4: Top Trips (any) + no Foul + full board → canEnter=true, count=17', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.seven, suit: Suit.spade),
          Card(rank: Rank.seven, suit: Suit.heart),
          Card(rank: Rank.seven, suit: Suit.diamond),
        ],
        mid: [
          Card(rank: Rank.king, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.king, suit: Suit.diamond),
          Card(rank: Rank.nine, suit: Suit.spade),
          Card(rank: Rank.nine, suit: Suit.heart),
        ],
        bottom: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
          Card(rank: Rank.ace, suit: Suit.diamond),
          Card(rank: Rank.ace, suit: Suit.club),
          Card(rank: Rank.two, suit: Suit.spade),
        ],
      );
      expect(FantasylandChecker.canEnter(board), isTrue);
      expect(FantasylandChecker.getEntryCardCount(board), 17);
    });

    // T5: Top JJ — JJ < QQ이므로 canEnter=false
    test('T5: Top JJ + no Foul + full board → canEnter=false', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.jack, suit: Suit.spade),
          Card(rank: Rank.jack, suit: Suit.heart),
          Card(rank: Rank.two, suit: Suit.club),
        ],
        mid: [
          Card(rank: Rank.king, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.nine, suit: Suit.spade),
          Card(rank: Rank.nine, suit: Suit.heart),
          Card(rank: Rank.three, suit: Suit.club),
        ],
        bottom: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
          Card(rank: Rank.ace, suit: Suit.diamond),
          Card(rank: Rank.eight, suit: Suit.spade),
          Card(rank: Rank.eight, suit: Suit.heart),
        ],
      );
      expect(FantasylandChecker.canEnter(board), isFalse);
    });

    // T6: Top QQ + Foul 상태 (mid 풀하우스 > bottom 하이카드)
    test('T6: Top QQ + Foul 상태 → canEnter=false', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.queen, suit: Suit.spade),
          Card(rank: Rank.queen, suit: Suit.heart),
          Card(rank: Rank.two, suit: Suit.club),
        ],
        mid: [
          Card(rank: Rank.king, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.king, suit: Suit.diamond),
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
        ],
        bottom: [
          Card(rank: Rank.two, suit: Suit.diamond),
          Card(rank: Rank.three, suit: Suit.spade),
          Card(rank: Rank.four, suit: Suit.diamond),
          Card(rank: Rank.five, suit: Suit.club),
          Card(rank: Rank.nine, suit: Suit.heart),
        ],
      );
      expect(FantasylandChecker.canEnter(board), isFalse);
    });

    // T7: 보드 미완성 (top만 있음)
    test('T7: Top QQ + 보드 미완성 → canEnter=false', () {
      final board = OFCBoard(
        top: [
          Card(rank: Rank.queen, suit: Suit.spade),
          Card(rank: Rank.queen, suit: Suit.heart),
          Card(rank: Rank.two, suit: Suit.club),
        ],
      );
      expect(FantasylandChecker.canEnter(board), isFalse);
    });

    // T12: 빈 보드
    test('T12: 빈 보드 → canEnter=false', () {
      final board = OFCBoard();
      expect(FantasylandChecker.canEnter(board), isFalse);
    });
  });

  group('FantasylandChecker.canMaintain', () {
    // T8: Top Trips — 유지 조건 충족
    test('T8: Top Trips → canMaintain=true', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.seven, suit: Suit.spade),
          Card(rank: Rank.seven, suit: Suit.heart),
          Card(rank: Rank.seven, suit: Suit.diamond),
        ],
        mid: [
          Card(rank: Rank.king, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.king, suit: Suit.diamond),
          Card(rank: Rank.nine, suit: Suit.spade),
          Card(rank: Rank.nine, suit: Suit.heart),
        ],
        bottom: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
          Card(rank: Rank.ace, suit: Suit.diamond),
          Card(rank: Rank.ace, suit: Suit.club),
          Card(rank: Rank.two, suit: Suit.spade),
        ],
      );
      expect(FantasylandChecker.canMaintain(board), isTrue);
    });

    // T9: Mid FourOfAKind
    test('T9: Mid FourOfAKind → canMaintain=true', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.two, suit: Suit.spade),
          Card(rank: Rank.three, suit: Suit.heart),
          Card(rank: Rank.four, suit: Suit.diamond),
        ],
        mid: [
          Card(rank: Rank.jack, suit: Suit.spade),
          Card(rank: Rank.jack, suit: Suit.heart),
          Card(rank: Rank.jack, suit: Suit.diamond),
          Card(rank: Rank.jack, suit: Suit.club),
          Card(rank: Rank.king, suit: Suit.spade),
        ],
        bottom: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
          Card(rank: Rank.ace, suit: Suit.diamond),
          Card(rank: Rank.ace, suit: Suit.club),
          Card(rank: Rank.nine, suit: Suit.spade),
        ],
      );
      expect(FantasylandChecker.canMaintain(board), isTrue);
    });

    // T10: Bottom FourOfAKind
    test('T10: Bottom FourOfAKind → canMaintain=true', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.two, suit: Suit.spade),
          Card(rank: Rank.three, suit: Suit.heart),
          Card(rank: Rank.four, suit: Suit.diamond),
        ],
        mid: [
          Card(rank: Rank.six, suit: Suit.spade),
          Card(rank: Rank.six, suit: Suit.heart),
          Card(rank: Rank.seven, suit: Suit.diamond),
          Card(rank: Rank.eight, suit: Suit.club),
          Card(rank: Rank.nine, suit: Suit.spade),
        ],
        bottom: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
          Card(rank: Rank.ace, suit: Suit.diamond),
          Card(rank: Rank.ace, suit: Suit.club),
          Card(rank: Rank.king, suit: Suit.spade),
        ],
      );
      expect(FantasylandChecker.canMaintain(board), isTrue);
    });

    // T11: Top AA (pair), Mid FullHouse, Bottom Straight → canMaintain=false
    // 단, 이 경우 Foul이 없어야 함: Straight < FullHouse면 Foul
    // Bottom=Flush, Mid=TwoPair, Top=AA pair로 수정
    test('T11: Top AA pair, Mid TwoPair, Bottom Flush → canMaintain=false', () {
      final board = buildFullBoard(
        top: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.ace, suit: Suit.heart),
          Card(rank: Rank.two, suit: Suit.club),
        ],
        mid: [
          Card(rank: Rank.king, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.queen, suit: Suit.spade),
          Card(rank: Rank.queen, suit: Suit.heart),
          Card(rank: Rank.three, suit: Suit.club),
        ],
        bottom: [
          Card(rank: Rank.jack, suit: Suit.club),
          Card(rank: Rank.ten, suit: Suit.club),
          Card(rank: Rank.nine, suit: Suit.club),
          Card(rank: Rank.eight, suit: Suit.club),
          Card(rank: Rank.six, suit: Suit.club),
        ],
      );
      expect(FantasylandChecker.canMaintain(board), isFalse);
    });

    test('보드 미완성 → canMaintain=false', () {
      final board = OFCBoard();
      expect(FantasylandChecker.canMaintain(board), isFalse);
    });

    test('reEntryCardCount = 14', () {
      expect(FantasylandChecker.reEntryCardCount, 14);
    });
  });
}

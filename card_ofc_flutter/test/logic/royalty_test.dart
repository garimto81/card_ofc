import 'package:flutter_test/flutter_test.dart';
import 'package:card_ofc_flutter/models/card.dart';
import 'package:card_ofc_flutter/models/hand_result.dart';
import 'package:card_ofc_flutter/models/board.dart';
import 'package:card_ofc_flutter/logic/royalty.dart';

void main() {
  group('calcLineRoyalty - Bottom', () {
    test('스트레이트: 2점', () {
      final h = HandResult(handType: HandType.straight, kickers: [9]);
      expect(calcLineRoyalty('bottom', h), 2);
    });

    test('플러시: 4점', () {
      final h = HandResult(handType: HandType.flush, kickers: [14, 10, 8, 6, 2]);
      expect(calcLineRoyalty('bottom', h), 4);
    });

    test('풀하우스: 6점', () {
      final h = HandResult(handType: HandType.fullHouse, kickers: [11, 9]);
      expect(calcLineRoyalty('bottom', h), 6);
    });

    test('포카드: 10점', () {
      final h = HandResult(handType: HandType.fourOfAKind, kickers: [13, 14]);
      expect(calcLineRoyalty('bottom', h), 10);
    });

    test('스트레이트 플러시: 15점', () {
      final h = HandResult(handType: HandType.straightFlush, kickers: [9]);
      expect(calcLineRoyalty('bottom', h), 15);
    });

    test('로얄 플러시: 25점', () {
      final h = HandResult(handType: HandType.royalFlush, kickers: []);
      expect(calcLineRoyalty('bottom', h), 25);
    });

    test('원페어: 0점', () {
      final h = HandResult(handType: HandType.onePair, kickers: [14, 13, 12, 11]);
      expect(calcLineRoyalty('bottom', h), 0);
    });
  });

  group('calcLineRoyalty - Mid', () {
    test('쓰리오브어카인드: 2점', () {
      final h = HandResult(handType: HandType.threeOfAKind, kickers: [7, 13, 2]);
      expect(calcLineRoyalty('mid', h), 2);
    });

    test('스트레이트: 4점', () {
      final h = HandResult(handType: HandType.straight, kickers: [9]);
      expect(calcLineRoyalty('mid', h), 4);
    });

    test('플러시: 8점', () {
      final h = HandResult(handType: HandType.flush, kickers: [14, 10, 8, 6, 2]);
      expect(calcLineRoyalty('mid', h), 8);
    });

    test('풀하우스: 12점', () {
      final h = HandResult(handType: HandType.fullHouse, kickers: [11, 9]);
      expect(calcLineRoyalty('mid', h), 12);
    });

    test('포카드: 20점', () {
      final h = HandResult(handType: HandType.fourOfAKind, kickers: [13, 14]);
      expect(calcLineRoyalty('mid', h), 20);
    });

    test('스트레이트 플러시: 30점', () {
      final h = HandResult(handType: HandType.straightFlush, kickers: [9]);
      expect(calcLineRoyalty('mid', h), 30);
    });

    test('로얄 플러시: 50점', () {
      final h = HandResult(handType: HandType.royalFlush, kickers: []);
      expect(calcLineRoyalty('mid', h), 50);
    });

    test('투페어: 0점', () {
      final h = HandResult(handType: HandType.twoPair, kickers: [14, 13, 12]);
      expect(calcLineRoyalty('mid', h), 0);
    });
  });

  group('calcLineRoyalty - Top (3장)', () {
    test('66 페어: 1점', () {
      final h = HandResult(handType: HandType.onePair, kickers: [6, 14]);
      expect(calcLineRoyalty('top', h), 1);
    });

    test('77 페어: 2점', () {
      final h = HandResult(handType: HandType.onePair, kickers: [7, 14]);
      expect(calcLineRoyalty('top', h), 2);
    });

    test('AA 페어: 9점', () {
      final h = HandResult(handType: HandType.onePair, kickers: [14, 13]);
      expect(calcLineRoyalty('top', h), 9);
    });

    test('55 페어: 0점 (기준 미달)', () {
      final h = HandResult(handType: HandType.onePair, kickers: [5, 14]);
      expect(calcLineRoyalty('top', h), 0);
    });

    test('222 쓰리오브어카인드: 10점', () {
      final h = HandResult(handType: HandType.threeOfAKind, kickers: [2]);
      expect(calcLineRoyalty('top', h), 10);
    });

    test('AAA 쓰리오브어카인드: 22점', () {
      final h = HandResult(handType: HandType.threeOfAKind, kickers: [14]);
      expect(calcLineRoyalty('top', h), 22);
    });

    test('333 쓰리오브어카인드: 11점', () {
      final h = HandResult(handType: HandType.threeOfAKind, kickers: [3]);
      expect(calcLineRoyalty('top', h), 11);
    });

    test('하이카드: 0점', () {
      final h = HandResult(handType: HandType.highCard, kickers: [14, 13, 12]);
      expect(calcLineRoyalty('top', h), 0);
    });
  });

  group('calcBoardRoyalty', () {
    test('로얄티 없는 보드', () {
      final board = OFCBoard(
        top: [
          Card(rank: Rank.ace, suit: Suit.spade),
          Card(rank: Rank.king, suit: Suit.heart),
          Card(rank: Rank.queen, suit: Suit.diamond),
        ],
        mid: [
          Card(rank: Rank.nine, suit: Suit.spade),
          Card(rank: Rank.eight, suit: Suit.heart),
          Card(rank: Rank.seven, suit: Suit.diamond),
          Card(rank: Rank.six, suit: Suit.club),
          Card(rank: Rank.five, suit: Suit.spade),
        ],
        bottom: [
          Card(rank: Rank.ace, suit: Suit.club),
          Card(rank: Rank.ten, suit: Suit.club),
          Card(rank: Rank.eight, suit: Suit.club),
          Card(rank: Rank.six, suit: Suit.club),
          Card(rank: Rank.two, suit: Suit.club),
        ],
      );

      final result = calcBoardRoyalty(board);
      expect(result.top, 0);
      expect(result.mid, 4);    // 스트레이트
      expect(result.bottom, 4); // 플러시
      expect(result.total, 8);
    });
  });
}

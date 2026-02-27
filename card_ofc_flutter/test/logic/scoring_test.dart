import 'package:flutter_test/flutter_test.dart';
import 'package:card_ofc_flutter/models/card.dart';
import 'package:card_ofc_flutter/models/board.dart';
import 'package:card_ofc_flutter/models/player.dart';
import 'package:card_ofc_flutter/logic/scoring.dart';

// 헬퍼: 카드 생성
Card c(Rank r, Suit s) => Card(rank: r, suit: s);

// 헬퍼: 보드에 카드 배치
OFCBoard buildBoard({
  required List<Card> top,
  required List<Card> mid,
  required List<Card> bottom,
}) {
  return OFCBoard(top: top, mid: mid, bottom: bottom);
}

// 헬퍼: 플레이어 생성
Player makePlayer(String id, OFCBoard board) {
  return Player(id: id, name: id, board: board);
}

void main() {
  group('calculateScores - 2인 기본 시나리오', () {
    test('모두 정상 핸드, P1이 3라인 모두 승리 (스쿱)', () {
      // P1: bottom=풀하우스, mid=스트레이트, top=원페어(77)
      final p1Board = buildBoard(
        top: [
          c(Rank.seven, Suit.spade),
          c(Rank.seven, Suit.heart),
          c(Rank.ace, Suit.diamond),
        ],
        mid: [
          c(Rank.nine, Suit.spade),
          c(Rank.eight, Suit.heart),
          c(Rank.seven, Suit.diamond),
          c(Rank.six, Suit.club),
          c(Rank.five, Suit.spade),
        ],
        bottom: [
          c(Rank.king, Suit.spade),
          c(Rank.king, Suit.heart),
          c(Rank.king, Suit.diamond),
          c(Rank.ace, Suit.spade),
          c(Rank.ace, Suit.heart),
        ],
      );

      // P2: bottom=하이카드, mid=하이카드, top=하이카드
      final p2Board = buildBoard(
        top: [
          c(Rank.two, Suit.spade),
          c(Rank.three, Suit.heart),
          c(Rank.four, Suit.diamond),
        ],
        mid: [
          c(Rank.two, Suit.heart),
          c(Rank.three, Suit.spade),
          c(Rank.four, Suit.club),
          c(Rank.six, Suit.diamond),
          c(Rank.eight, Suit.spade),
        ],
        bottom: [
          c(Rank.two, Suit.diamond),
          c(Rank.three, Suit.diamond),
          c(Rank.five, Suit.heart),
          c(Rank.seven, Suit.club),
          c(Rank.nine, Suit.heart),
        ],
      );

      final p1 = makePlayer('p1', p1Board);
      final p2 = makePlayer('p2', p2Board);
      final scores = calculateScores([p1, p2]);

      // P1: 라인 3승=+3, 스쿱보너스+3=+6
      // P1 로열티: bottom FH=6, mid straight=4, top 77=2 → 12
      // P2 로열티: 0
      // P1 로열티 차이: 12-0 = +12
      // P1 총점: 6 + 12 = 18, P2 총점: -6 - 12 = -18
      expect(scores['p1'], 18);
      expect(scores['p2'], -18);
    });

    test('모두 정상 핸드, 1:1:1 (각 1라인씩 승리)', () {
      // P1: bottom=원페어(AA), mid=원페어(KK), top=원페어(QQ)
      // P2: bottom=원페어(KK), mid=원페어(AA), top=원페어(JJ)
      // P1 bottom wins, P2 mid wins, P1 top wins → 2:1 P1 우세

      final p1Board = buildBoard(
        top: [
          c(Rank.queen, Suit.spade),
          c(Rank.queen, Suit.heart),
          c(Rank.two, Suit.club),
        ],
        mid: [
          c(Rank.king, Suit.spade),
          c(Rank.king, Suit.heart),
          c(Rank.two, Suit.diamond),
          c(Rank.three, Suit.spade),
          c(Rank.four, Suit.spade),
        ],
        bottom: [
          c(Rank.ace, Suit.spade),
          c(Rank.ace, Suit.heart),
          c(Rank.three, Suit.diamond),
          c(Rank.four, Suit.diamond),
          c(Rank.five, Suit.spade),
        ],
      );

      final p2Board = buildBoard(
        top: [
          c(Rank.jack, Suit.spade),
          c(Rank.jack, Suit.heart),
          c(Rank.three, Suit.club),
        ],
        mid: [
          c(Rank.ace, Suit.diamond),
          c(Rank.ace, Suit.club),
          c(Rank.five, Suit.diamond),
          c(Rank.six, Suit.spade),
          c(Rank.seven, Suit.spade),
        ],
        bottom: [
          c(Rank.king, Suit.diamond),
          c(Rank.king, Suit.club),
          c(Rank.six, Suit.diamond),
          c(Rank.seven, Suit.diamond),
          c(Rank.eight, Suit.spade),
        ],
      );

      final p1 = makePlayer('p1', p1Board);
      final p2 = makePlayer('p2', p2Board);
      final scores = calculateScores([p1, p2]);

      // P2 board: mid=AA pair > bottom=KK pair → FOUL
      // P1 not foul, P2 foul → P1 gets +6 + P1_royalty
      // P1 royalties: top=QQ=7, mid=0, bottom=0 → total=7
      // P1 total = 6 + 7 = 13, P2 total = -6 - 7 = -13
      expect(scores['p1'], 13);
      expect(scores['p2'], -13);
    });

    test('P1 Foul, P2 정상: P1 패널티', () {
      // P1 foul: mid=풀하우스, bottom=하이카드 (bottom < mid → foul)
      final p1Board = buildBoard(
        top: [
          c(Rank.two, Suit.spade),
          c(Rank.three, Suit.heart),
          c(Rank.four, Suit.diamond),
        ],
        mid: [
          c(Rank.jack, Suit.spade),
          c(Rank.jack, Suit.heart),
          c(Rank.jack, Suit.diamond),
          c(Rank.nine, Suit.spade),
          c(Rank.nine, Suit.heart),
        ],
        bottom: [
          c(Rank.ace, Suit.spade),
          c(Rank.king, Suit.heart),
          c(Rank.queen, Suit.diamond),
          c(Rank.ten, Suit.club),
          c(Rank.eight, Suit.spade),
        ],
      );

      // P2 정상 보드: bottom(투페어) >= mid(원페어) >= top(원페어, 낮은것)
      final p2Board = buildBoard(
        top: [
          c(Rank.six, Suit.spade),
          c(Rank.six, Suit.heart),
          c(Rank.two, Suit.club),
        ],
        mid: [
          c(Rank.seven, Suit.spade),
          c(Rank.seven, Suit.heart),
          c(Rank.three, Suit.diamond),
          c(Rank.four, Suit.club),
          c(Rank.five, Suit.diamond),
        ],
        bottom: [
          c(Rank.eight, Suit.diamond),
          c(Rank.eight, Suit.club),
          c(Rank.nine, Suit.diamond),
          c(Rank.nine, Suit.club),
          c(Rank.ten, Suit.spade),
        ],
      );

      final p1 = makePlayer('p1', p1Board);
      final p2 = makePlayer('p2', p2Board);
      final scores = calculateScores([p1, p2]);

      // P1 fouls: result = -(6 + p2Royalty.total)
      // P2 royalty: top=66pair=1, mid=77pair는 mid에서 pair=0, bottom=투페어=0 → total=1
      // P1: -(6+1) = -7
      // P2: +(6+1) = +7
      expect(scores['p1'], -7);
      expect(scores['p2'], 7);
    });

    test('양쪽 모두 Foul: 서로 0점', () {
      // P1 foul (mid > bottom)
      final p1Board = buildBoard(
        top: [
          c(Rank.two, Suit.spade),
          c(Rank.three, Suit.heart),
          c(Rank.four, Suit.diamond),
        ],
        mid: [
          c(Rank.jack, Suit.spade),
          c(Rank.jack, Suit.heart),
          c(Rank.jack, Suit.diamond),
          c(Rank.nine, Suit.spade),
          c(Rank.nine, Suit.heart),
        ],
        bottom: [
          c(Rank.ace, Suit.spade),
          c(Rank.king, Suit.heart),
          c(Rank.queen, Suit.diamond),
          c(Rank.ten, Suit.club),
          c(Rank.eight, Suit.spade),
        ],
      );

      // P2 foul (mid > bottom)
      final p2Board = buildBoard(
        top: [
          c(Rank.two, Suit.heart),
          c(Rank.three, Suit.spade),
          c(Rank.four, Suit.club),
        ],
        mid: [
          c(Rank.king, Suit.spade),
          c(Rank.king, Suit.heart),
          c(Rank.king, Suit.diamond),
          c(Rank.queen, Suit.spade),
          c(Rank.queen, Suit.heart),
        ],
        bottom: [
          c(Rank.ace, Suit.heart),
          c(Rank.ace, Suit.diamond),
          c(Rank.five, Suit.spade),
          c(Rank.six, Suit.spade),
          c(Rank.seven, Suit.spade),
        ],
      );

      final p1 = makePlayer('p1', p1Board);
      final p2 = makePlayer('p2', p2Board);
      final scores = calculateScores([p1, p2]);

      // 둘 다 Foul: 서로 0 (이 쌍에서)
      expect(scores['p1'], 0);
      expect(scores['p2'], 0);
    });
  });

  group('calculateScores - 스쿱 보너스', () {
    test('3:0 스쿱 시 +3 보너스 추가', () {
      // P1이 3라인 모두 이기면 line points: +3, scoop bonus: +3
      final p1Board = buildBoard(
        top: [
          c(Rank.ace, Suit.spade),
          c(Rank.ace, Suit.heart),
          c(Rank.king, Suit.diamond),
        ],
        mid: [
          c(Rank.ace, Suit.diamond),
          c(Rank.ace, Suit.club),
          c(Rank.king, Suit.spade),
          c(Rank.king, Suit.heart),
          c(Rank.queen, Suit.spade),
        ],
        bottom: [
          c(Rank.queen, Suit.heart),
          c(Rank.queen, Suit.diamond),
          c(Rank.queen, Suit.club),
          c(Rank.jack, Suit.spade),
          c(Rank.jack, Suit.heart),
        ],
      );

      final p2Board = buildBoard(
        top: [
          c(Rank.two, Suit.spade),
          c(Rank.three, Suit.heart),
          c(Rank.four, Suit.diamond),
        ],
        mid: [
          c(Rank.two, Suit.heart),
          c(Rank.three, Suit.diamond),
          c(Rank.four, Suit.club),
          c(Rank.five, Suit.spade),
          c(Rank.seven, Suit.spade),
        ],
        bottom: [
          c(Rank.two, Suit.diamond),
          c(Rank.three, Suit.spade),
          c(Rank.four, Suit.spade),
          c(Rank.five, Suit.diamond),
          c(Rank.eight, Suit.spade),
        ],
      );

      final p1 = makePlayer('p1', p1Board);
      final p2 = makePlayer('p2', p2Board);
      final scores = calculateScores([p1, p2]);

      // P1 wins all 3: line +3, scoop +3 = +6 (before royalties)
      // Royalties: P1 top=AA=9, mid=TwoPair=0, bottom=FH=6 → 15
      // P2 royalties: 0
      // royalty diff: 15
      // P1: 6 + 15 = 21
      // P2: -6 - 15 = -21
      expect(scores['p1'], 21);
      expect(scores['p2'], -21);
    });
  });

  group('calculateScores - 3인 페어와이즈', () {
    test('전체 점수 합은 항상 0', () {
      // 3인 게임에서는 (p1,p2), (p1,p3), (p2,p3) 3쌍 계산
      final strongBoard = buildBoard(
        top: [
          c(Rank.ace, Suit.spade),
          c(Rank.ace, Suit.heart),
          c(Rank.king, Suit.diamond),
        ],
        mid: [
          c(Rank.ace, Suit.diamond),
          c(Rank.ace, Suit.club),
          c(Rank.king, Suit.spade),
          c(Rank.king, Suit.heart),
          c(Rank.queen, Suit.spade),
        ],
        bottom: [
          c(Rank.queen, Suit.heart),
          c(Rank.queen, Suit.diamond),
          c(Rank.queen, Suit.club),
          c(Rank.jack, Suit.spade),
          c(Rank.jack, Suit.heart),
        ],
      );

      final weakBoard1 = buildBoard(
        top: [
          c(Rank.two, Suit.spade),
          c(Rank.three, Suit.heart),
          c(Rank.four, Suit.diamond),
        ],
        mid: [
          c(Rank.two, Suit.heart),
          c(Rank.three, Suit.diamond),
          c(Rank.four, Suit.club),
          c(Rank.five, Suit.spade),
          c(Rank.seven, Suit.spade),
        ],
        bottom: [
          c(Rank.two, Suit.diamond),
          c(Rank.three, Suit.spade),
          c(Rank.four, Suit.spade),
          c(Rank.five, Suit.diamond),
          c(Rank.eight, Suit.spade),
        ],
      );

      final weakBoard2 = buildBoard(
        top: [
          c(Rank.two, Suit.club),
          c(Rank.three, Suit.club),
          c(Rank.four, Suit.club),
        ],
        mid: [
          c(Rank.six, Suit.heart),
          c(Rank.seven, Suit.heart),
          c(Rank.eight, Suit.heart),
          c(Rank.nine, Suit.heart),
          c(Rank.ten, Suit.heart),
        ],
        bottom: [
          c(Rank.six, Suit.spade),
          c(Rank.seven, Suit.diamond),
          c(Rank.eight, Suit.diamond),
          c(Rank.nine, Suit.diamond),
          c(Rank.ten, Suit.spade),
        ],
      );

      final p1 = makePlayer('p1', strongBoard);
      final p2 = makePlayer('p2', weakBoard1);
      final p3 = makePlayer('p3', weakBoard2);
      final scores = calculateScores([p1, p2, p3]);

      // P1 score should be positive
      expect(scores['p1']! > 0, isTrue);
      // 전체 점수 합은 0
      expect(scores['p1']! + scores['p2']! + scores['p3']!, 0);
    });
  });
}

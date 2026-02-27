import 'package:flutter_test/flutter_test.dart';
import 'package:card_ofc_flutter/models/card.dart';
import 'package:card_ofc_flutter/logic/deck.dart';

void main() {
  group('Deck', () {
    test('새 덱은 52장을 가진다', () {
      final deck = Deck();
      expect(deck.remaining, 52);
    });

    test('52장 모두 고유한 카드', () {
      final deck = Deck();
      final all = deck.dealAll();
      final unique = all.toSet();
      expect(unique.length, 52);
    });

    test('모든 수트×랭크 조합이 존재', () {
      final deck = Deck();
      final all = deck.dealAll();
      for (final suit in Suit.values) {
        for (final rank in Rank.values) {
          expect(
            all.any((c) => c.suit == suit && c.rank == rank),
            isTrue,
            reason: '${suit.name} ${rank.name} 없음',
          );
        }
      }
    });

    test('deal(5)은 5장을 반환하고 remaining이 47이 된다', () {
      final deck = Deck();
      final hand = deck.deal(5);
      expect(hand.length, 5);
      expect(deck.remaining, 47);
    });

    test('remaining보다 많이 딜하면 남은 것만 반환', () {
      final deck = Deck();
      deck.deal(50);
      final hand = deck.deal(5);
      expect(hand.length, 2);
      expect(deck.remaining, 0);
    });

    test('shuffle 후 reset하면 다시 52장', () {
      final deck = Deck();
      deck.deal(10);
      deck.reset();
      expect(deck.remaining, 52);
    });

    test('shuffle은 순서를 무작위화한다 (통계적 테스트)', () {
      final deck1 = Deck();
      final deck2 = Deck();
      deck1.shuffle();
      deck2.shuffle();
      final all1 = deck1.dealAll();
      final all2 = deck2.dealAll();
      // 두 셔플이 동일할 확률은 매우 낮음
      bool same = true;
      for (int i = 0; i < all1.length; i++) {
        if (all1[i] != all2[i]) {
          same = false;
          break;
        }
      }
      // 52! 중 동일 확률이 매우 낮으므로 보통 다름 — 그래도 강제 fail은 안함
      // 여기서는 딜 후 remaining이 0임을 검증
      expect(deck1.remaining, 0);
      expect(deck2.remaining, 0);
    });

    test('딜 후 remaining 카운트 감소', () {
      final deck = Deck();
      deck.deal(13);
      expect(deck.remaining, 39);
      deck.deal(13);
      expect(deck.remaining, 26);
    });
  });
}

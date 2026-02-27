import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_ofc_flutter/models/card.dart' as ofc;
import 'package:card_ofc_flutter/ui/widgets/card_widget.dart';

void main() {
  group('CardWidget', () {
    testWidgets('T1: 앞면 카드 표시 - 랭크/수트', (tester) async {
      const card = ofc.Card(rank: ofc.Rank.ace, suit: ofc.Suit.spade);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CardWidget(card: card)),
      ));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('♠'), findsOneWidget);
    });

    testWidgets('T2: 뒷면 카드 표시 - 랭크/수트 없음', (tester) async {
      const card = ofc.Card(rank: ofc.Rank.ace, suit: ofc.Suit.spade);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CardWidget(card: card, faceDown: true)),
      ));
      expect(find.text('A'), findsNothing);
      expect(find.text('♠'), findsNothing);
    });

    testWidgets('T3: draggable=true 시 LongPressDraggable 존재', (tester) async {
      const card = ofc.Card(rank: ofc.Rank.king, suit: ofc.Suit.heart);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CardWidget(card: card, draggable: true)),
      ));
      expect(find.byType(LongPressDraggable<ofc.Card>), findsOneWidget);
    });

    testWidgets('T4: 하트/다이아몬드 카드 빨간색', (tester) async {
      const card = ofc.Card(rank: ofc.Rank.queen, suit: ofc.Suit.heart);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CardWidget(card: card)),
      ));
      expect(find.text('Q'), findsOneWidget);
      expect(find.text('♥'), findsOneWidget);
    });

    testWidgets('T5: onTap 콜백 호출', (tester) async {
      bool tapped = false;
      const card = ofc.Card(rank: ofc.Rank.ten, suit: ofc.Suit.club);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CardWidget(card: card, onTap: () => tapped = true)),
      ));
      await tester.tap(find.text('10'));
      expect(tapped, isTrue);
    });
  });
}

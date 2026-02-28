import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:card_ofc_flutter/providers/game_provider.dart';
import 'package:card_ofc_flutter/providers/player_provider.dart';
import 'package:card_ofc_flutter/providers/score_provider.dart';
import 'package:card_ofc_flutter/models/game_state.dart';
import 'package:card_ofc_flutter/models/card.dart';

void main() {
  group('GameNotifier', () {
    test('T1: build() → empty players, waiting phase', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(gameNotifierProvider);
      expect(state.players, isEmpty);
      expect(state.phase, GamePhase.waiting);
    });

    test('T2: startGame(2 players) → dealing phase', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(gameNotifierProvider.notifier).startGame(['P1', 'P2']);
      final state = container.read(gameNotifierProvider);
      expect(state.players.length, 2);
      expect(state.phase, GamePhase.dealing);
    });

    test('T3: startGame(withAI: true) → AI player added', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(gameNotifierProvider.notifier).startGame(['P1'], withAI: true);
      final state = container.read(gameNotifierProvider);
      expect(state.players.length, 2);
      expect(state.players.last.name, 'AI');
    });

    test('T4: startGame → auto deals round 0 → player hand = 5', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);
      // startGame이 자동으로 첫 딜링 수행
      final state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, 5);
    });

    test('T5: placeCard → card removed from hand, added to board', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);
      // startGame이 자동 딜링 — 추가 dealCards 불필요
      final hand = container.read(gameNotifierProvider).players[0].hand;
      final card = hand.first;
      notifier.placeCard(card, 'bottom');
      final state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, hand.length - 1);
      expect(state.players[0].hand.contains(card), isFalse);
      expect(state.players[0].board.bottom.contains(card), isTrue);
    });

    test('T6: discardCard → card removed from hand', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);
      // startGame이 자동 딜링 — 추가 dealCards 불필요
      final hand = container.read(gameNotifierProvider).players[0].hand;
      final card = hand.first;
      notifier.discardCard(card);
      final newHand = container.read(gameNotifierProvider).players[0].hand;
      expect(newHand.contains(card), isFalse);
    });

    test('T7: scoreRound → scoring phase', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);
      notifier.scoreRound();
      final state = container.read(gameNotifierProvider);
      expect(state.phase, GamePhase.scoring);
    });

    test('T8: roundScores provider → map when scoring phase', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);
      notifier.scoreRound();
      final scores = container.read(roundScoresProvider);
      expect(scores, isNotNull);
      expect(scores!.keys.length, 2);
    });
  });

  group('Derived Providers', () {
    test('currentPlayer → null when no game', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(currentPlayerProvider), isNull);
    });

    test('currentPlayer → first player after startGame', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(gameNotifierProvider.notifier).startGame(['P1', 'P2']);
      final current = container.read(currentPlayerProvider);
      expect(current, isNotNull);
      expect(current!.name, 'P1');
    });

    test('availableLines → all lines when board empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(gameNotifierProvider.notifier).startGame(['P1', 'P2']);
      final lines = container.read(availableLinesProvider);
      expect(lines, containsAll(['top', 'mid', 'bottom']));
    });

    test('isMyTurn → true when game started', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(gameNotifierProvider.notifier).startGame(['P1', 'P2']);
      expect(container.read(isMyTurnProvider), isTrue);
    });

    test('roundScores → null when not scoring', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(gameNotifierProvider.notifier).startGame(['P1', 'P2']);
      expect(container.read(roundScoresProvider), isNull);
    });
  });

  group('Undo', () {
    test('T9: undoPlaceCard → 보드에서 제거, 핸드에 복귀', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);

      final hand = container.read(gameNotifierProvider).players[0].hand;
      final card = hand.first;
      final handLenBefore = hand.length;

      notifier.placeCard(card, 'bottom');
      // 배치 후: 핸드 -1, 보드에 카드 있음
      var state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, handLenBefore - 1);
      expect(state.players[0].board.bottom.contains(card), isTrue);

      notifier.undoPlaceCard(card, 'bottom');
      // undo 후: 핸드에 복귀, 보드에서 제거
      state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, handLenBefore);
      expect(state.players[0].hand.contains(card), isTrue);
      expect(state.players[0].board.bottom.contains(card), isFalse);
    });

    test('T10: undoDiscard → 핸드에 복귀', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);

      final hand = container.read(gameNotifierProvider).players[0].hand;
      final card = hand.first;
      final handLenBefore = hand.length;

      notifier.discardCard(card);
      var state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, handLenBefore - 1);
      expect(state.discardPile.contains(card), isTrue);

      notifier.undoDiscard();
      state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, handLenBefore);
      expect(state.players[0].hand.contains(card), isTrue);
      expect(state.discardPile.contains(card), isFalse);
    });

    test('T11: undoAllCurrentTurn → 모든 배치/버림 취소', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);

      final hand = container.read(gameNotifierProvider).players[0].hand;
      final handLenBefore = hand.length;
      final card1 = hand[0];
      final card2 = hand[1];
      final card3 = hand[2];

      // 2장 배치 + 1장 버림
      notifier.placeCard(card1, 'bottom');
      notifier.placeCard(card2, 'mid');
      notifier.discardCard(card3);

      var state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, handLenBefore - 3);

      notifier.undoAllCurrentTurn();
      state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, handLenBefore);
      expect(state.players[0].board.bottom.contains(card1), isFalse);
      expect(state.players[0].board.mid.contains(card2), isFalse);
      expect(state.discardPile.contains(card3), isFalse);
    });

    test('T12: confirm 후 undo 불가 (이전 턴 카드)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);

      final hand = container.read(gameNotifierProvider).players[0].hand;
      final card = hand.first;
      notifier.placeCard(card, 'bottom');

      // confirm: 추적 초기화 → 다음 플레이어로 전환
      notifier.confirmPlacement();

      // P2 턴으로 전환됨 — P1의 카드에 대해 undo 시도
      // currentTurnPlacements가 비어있으므로 undo 불가
      expect(notifier.currentTurnPlacements, isEmpty);
      expect(notifier.currentTurnDiscard, isNull);
    });
  });
}

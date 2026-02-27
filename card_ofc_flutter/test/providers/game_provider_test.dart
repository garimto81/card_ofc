import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:card_ofc_flutter/providers/game_provider.dart';
import 'package:card_ofc_flutter/providers/player_provider.dart';
import 'package:card_ofc_flutter/providers/score_provider.dart';
import 'package:card_ofc_flutter/models/game_state.dart';

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

    test('T4: dealCards() round 0 → player hand = 5', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);
      notifier.dealCards();
      final state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.length, 5);
    });

    test('T5: placeCard → card removed from hand, added to board', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['P1', 'P2']);
      notifier.dealCards();
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
      notifier.dealCards();
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
}

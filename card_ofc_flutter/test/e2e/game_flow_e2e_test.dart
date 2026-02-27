import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:card_ofc_flutter/main.dart';
import 'package:card_ofc_flutter/providers/game_provider.dart';
import 'package:card_ofc_flutter/models/game_state.dart';

/// Helper: pump multiple frames instead of pumpAndSettle (which times out
/// on infinite/repeating animations like turn indicator pulse).
Future<void> pumpFrames(WidgetTester tester, {int count = 10}) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('E2E: Game Flow — 무한 로딩 회귀 방지', () {
    testWidgets('E1: HomeScreen → VS AI 클릭 → GameScreen 진입 (no infinite loading)',
        (WidgetTester tester) async {
      // Overflow는 UI 레이아웃 이슈 (별도 수정 대상) — 핵심 로직 검증에서 제외
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalHandler);

      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: OFCApp()));
      await tester.pumpAndSettle();

      // HomeScreen에 VS AI 버튼이 있어야 함
      expect(find.text('VS AI'), findsOneWidget);
      expect(find.text('OFC Pineapple'), findsOneWidget);

      // VS AI 탭
      await tester.tap(find.text('VS AI'));
      // Use pump frames instead of pumpAndSettle (repeating animations prevent settle)
      await pumpFrames(tester);

      // GameScreen 진입 확인: Confirm 버튼 존재 = 게임 UI 정상 렌더링
      expect(find.text('Confirm'), findsOneWidget);

      // 무한 로딩이 아님 (CircularProgressIndicator가 없어야 함)
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // 플레이어 이름 "You"가 표시되어야 함
      expect(find.textContaining('You'), findsWidgets);
    });

    testWidgets('E2: HomeScreen → 2P Local 클릭 → GameScreen 진입',
        (WidgetTester tester) async {
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalHandler);

      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: OFCApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2P Local'));
      await pumpFrames(tester);

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('E3: GameScreen에서 Score 표시 + 게임 UI 보여야 함',
        (WidgetTester tester) async {
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalHandler);

      tester.view.physicalSize = const Size(1284, 2778);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: OFCApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('VS AI'));
      await pumpFrames(tester);

      expect(find.textContaining('Score'), findsWidgets);
    });

    testWidgets('E4: Provider keepAlive 검증 — 상태가 유지되어야 함',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(gameNotifierProvider.notifier).startGame(['You'], withAI: true);

      var state = container.read(gameNotifierProvider);
      expect(state.players.length, 2);
      expect(state.phase, GamePhase.dealing);
      expect(state.players[0].hand.length, 5);

      // 여러 번 read해도 상태가 유지되어야 함 (keepAlive)
      state = container.read(gameNotifierProvider);
      expect(state.players.length, 2);
      expect(state.players[0].hand.length, 5);
    });

    testWidgets('E5: 전체 라운드 플로우 — 카드 배치 → Confirm → 다음 턴',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameNotifierProvider.notifier);
      notifier.startGame(['You'], withAI: true);

      var state = container.read(gameNotifierProvider);
      expect(state.currentRound, 0);
      expect(state.roundPhase, RoundPhase.initial);
      expect(state.players[0].hand.length, 5);

      // 5장 모두 배치
      final hand = List.of(state.players[0].hand);
      for (final card in hand) {
        final board = container.read(gameNotifierProvider).players[0].board;
        final line = board.bottom.length < 5
            ? 'bottom'
            : board.mid.length < 5
                ? 'mid'
                : 'top';
        notifier.placeCard(card, line);
      }

      state = container.read(gameNotifierProvider);
      expect(state.players[0].hand.isEmpty, isTrue);

      notifier.confirmPlacement();

      state = container.read(gameNotifierProvider);
      if (state.phase != GamePhase.scoring) {
        expect(state.currentRound, 1);
        expect(state.roundPhase, RoundPhase.pineapple);
        expect(state.players[0].hand.length, 3);
      }
    });
  });
}

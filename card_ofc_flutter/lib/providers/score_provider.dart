import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/game_state.dart';
import 'game_provider.dart';

part 'score_provider.g.dart';

/// 현재 라운드 점수 맵 (playerId → score)
@riverpod
Map<String, int>? roundScores(Ref ref) {
  final gameState = ref.watch(gameNotifierProvider);
  if (gameState.phase != GamePhase.scoring) return null;

  return {
    for (final p in gameState.players) p.id: p.score,
  };
}

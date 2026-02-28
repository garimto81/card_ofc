import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../models/board.dart';
import '../logic/foul_checker.dart';
import 'game_provider.dart';

part 'player_provider.g.dart';

/// 현재 턴 플레이어
@riverpod
Player? currentPlayer(Ref ref) {
  final gameState = ref.watch(gameNotifierProvider);
  if (gameState.players.isEmpty) return null;
  return gameState.players[gameState.currentPlayerIndex];
}

/// 내 턴 여부 (로컬 플레이어 ID 기준)
@riverpod
bool isMyTurn(Ref ref) {
  final current = ref.watch(currentPlayerProvider);
  return current != null;
}

/// 현재 플레이어 보드의 Foul 여부
@riverpod
bool isFoulRisk(Ref ref) {
  final player = ref.watch(currentPlayerProvider);
  if (player == null) return false;
  return checkFoul(player.board);
}

/// 현재 플레이어가 배치 가능한 라인 목록
@riverpod
List<String> availableLines(Ref ref) {
  final current = ref.watch(currentPlayerProvider);
  if (current == null) return [];

  final lines = <String>[];
  if (current.board.top.length < OFCBoard.topMaxCards) lines.add('top');
  if (current.board.mid.length < OFCBoard.midMaxCards) lines.add('mid');
  if (current.board.bottom.length < OFCBoard.bottomMaxCards) {
    lines.add('bottom');
  }
  return lines;
}

/// 현재 턴 배치 추적 (undo 용)
@riverpod
List<({Card card, String line})> currentTurnPlacements(Ref ref) {
  ref.watch(gameNotifierProvider); // rebuild trigger
  return ref.watch(gameNotifierProvider.notifier).currentTurnPlacements;
}

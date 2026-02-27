import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/player.dart';
import '../models/board.dart';
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

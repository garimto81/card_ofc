import 'package:freezed_annotation/freezed_annotation.dart';
import 'card.dart';
import 'player.dart';

part 'game_state.freezed.dart';
part 'game_state.g.dart';

enum GamePhase {
  waiting,
  dealing,
  placing,
  scoring,
  fantasyland,
  gameOver,
}

enum RoundPhase {
  /// R0: initial deal of 5 cards
  initial,
  /// R1-R4: pineapple deal of 3 cards (place 2, discard 1)
  pineapple,
}

@freezed
class GameState with _$GameState {
  const factory GameState({
    required List<Player> players,
    @Default(0) int currentRound,
    @Default(0) int currentPlayerIndex,
    @Default(GamePhase.waiting) GamePhase phase,
    @Default(RoundPhase.initial) RoundPhase roundPhase,
    @Default([]) List<Card> discardPile,
  }) = _GameState;

  factory GameState.fromJson(Map<String, dynamic> json) =>
      _$GameStateFromJson(json);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameStateImpl _$$GameStateImplFromJson(Map<String, dynamic> json) =>
    _$GameStateImpl(
      players: (json['players'] as List<dynamic>)
          .map((e) => Player.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentRound: (json['currentRound'] as num?)?.toInt() ?? 0,
      currentPlayerIndex: (json['currentPlayerIndex'] as num?)?.toInt() ?? 0,
      phase:
          $enumDecodeNullable(_$GamePhaseEnumMap, json['phase']) ??
          GamePhase.waiting,
      roundPhase:
          $enumDecodeNullable(_$RoundPhaseEnumMap, json['roundPhase']) ??
          RoundPhase.initial,
      discardPile:
          (json['discardPile'] as List<dynamic>?)
              ?.map((e) => Card.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$GameStateImplToJson(_$GameStateImpl instance) =>
    <String, dynamic>{
      'players': instance.players,
      'currentRound': instance.currentRound,
      'currentPlayerIndex': instance.currentPlayerIndex,
      'phase': _$GamePhaseEnumMap[instance.phase]!,
      'roundPhase': _$RoundPhaseEnumMap[instance.roundPhase]!,
      'discardPile': instance.discardPile,
    };

const _$GamePhaseEnumMap = {
  GamePhase.waiting: 'waiting',
  GamePhase.dealing: 'dealing',
  GamePhase.placing: 'placing',
  GamePhase.scoring: 'scoring',
  GamePhase.fantasyland: 'fantasyland',
  GamePhase.gameOver: 'gameOver',
};

const _$RoundPhaseEnumMap = {
  RoundPhase.initial: 'initial',
  RoundPhase.pineapple: 'pineapple',
};

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GameState _$GameStateFromJson(Map<String, dynamic> json) {
  return _GameState.fromJson(json);
}

/// @nodoc
mixin _$GameState {
  List<Player> get players => throw _privateConstructorUsedError;
  int get currentRound => throw _privateConstructorUsedError;
  int get currentPlayerIndex => throw _privateConstructorUsedError;
  GamePhase get phase => throw _privateConstructorUsedError;
  RoundPhase get roundPhase => throw _privateConstructorUsedError;
  List<Card> get discardPile => throw _privateConstructorUsedError;
  int get handNumber => throw _privateConstructorUsedError;
  int get targetHands => throw _privateConstructorUsedError;

  /// Serializes this GameState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameStateCopyWith<GameState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameStateCopyWith<$Res> {
  factory $GameStateCopyWith(GameState value, $Res Function(GameState) then) =
      _$GameStateCopyWithImpl<$Res, GameState>;
  @useResult
  $Res call({
    List<Player> players,
    int currentRound,
    int currentPlayerIndex,
    GamePhase phase,
    RoundPhase roundPhase,
    List<Card> discardPile,
    int handNumber,
    int targetHands,
  });
}

/// @nodoc
class _$GameStateCopyWithImpl<$Res, $Val extends GameState>
    implements $GameStateCopyWith<$Res> {
  _$GameStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? players = null,
    Object? currentRound = null,
    Object? currentPlayerIndex = null,
    Object? phase = null,
    Object? roundPhase = null,
    Object? discardPile = null,
    Object? handNumber = null,
    Object? targetHands = null,
  }) {
    return _then(
      _value.copyWith(
            players: null == players
                ? _value.players
                : players // ignore: cast_nullable_to_non_nullable
                      as List<Player>,
            currentRound: null == currentRound
                ? _value.currentRound
                : currentRound // ignore: cast_nullable_to_non_nullable
                      as int,
            currentPlayerIndex: null == currentPlayerIndex
                ? _value.currentPlayerIndex
                : currentPlayerIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            phase: null == phase
                ? _value.phase
                : phase // ignore: cast_nullable_to_non_nullable
                      as GamePhase,
            roundPhase: null == roundPhase
                ? _value.roundPhase
                : roundPhase // ignore: cast_nullable_to_non_nullable
                      as RoundPhase,
            discardPile: null == discardPile
                ? _value.discardPile
                : discardPile // ignore: cast_nullable_to_non_nullable
                      as List<Card>,
            handNumber: null == handNumber
                ? _value.handNumber
                : handNumber // ignore: cast_nullable_to_non_nullable
                      as int,
            targetHands: null == targetHands
                ? _value.targetHands
                : targetHands // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GameStateImplCopyWith<$Res>
    implements $GameStateCopyWith<$Res> {
  factory _$$GameStateImplCopyWith(
    _$GameStateImpl value,
    $Res Function(_$GameStateImpl) then,
  ) = __$$GameStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Player> players,
    int currentRound,
    int currentPlayerIndex,
    GamePhase phase,
    RoundPhase roundPhase,
    List<Card> discardPile,
    int handNumber,
    int targetHands,
  });
}

/// @nodoc
class __$$GameStateImplCopyWithImpl<$Res>
    extends _$GameStateCopyWithImpl<$Res, _$GameStateImpl>
    implements _$$GameStateImplCopyWith<$Res> {
  __$$GameStateImplCopyWithImpl(
    _$GameStateImpl _value,
    $Res Function(_$GameStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? players = null,
    Object? currentRound = null,
    Object? currentPlayerIndex = null,
    Object? phase = null,
    Object? roundPhase = null,
    Object? discardPile = null,
    Object? handNumber = null,
    Object? targetHands = null,
  }) {
    return _then(
      _$GameStateImpl(
        players: null == players
            ? _value._players
            : players // ignore: cast_nullable_to_non_nullable
                  as List<Player>,
        currentRound: null == currentRound
            ? _value.currentRound
            : currentRound // ignore: cast_nullable_to_non_nullable
                  as int,
        currentPlayerIndex: null == currentPlayerIndex
            ? _value.currentPlayerIndex
            : currentPlayerIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        phase: null == phase
            ? _value.phase
            : phase // ignore: cast_nullable_to_non_nullable
                  as GamePhase,
        roundPhase: null == roundPhase
            ? _value.roundPhase
            : roundPhase // ignore: cast_nullable_to_non_nullable
                  as RoundPhase,
        discardPile: null == discardPile
            ? _value._discardPile
            : discardPile // ignore: cast_nullable_to_non_nullable
                  as List<Card>,
        handNumber: null == handNumber
            ? _value.handNumber
            : handNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        targetHands: null == targetHands
            ? _value.targetHands
            : targetHands // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GameStateImpl implements _GameState {
  const _$GameStateImpl({
    required final List<Player> players,
    this.currentRound = 0,
    this.currentPlayerIndex = 0,
    this.phase = GamePhase.waiting,
    this.roundPhase = RoundPhase.initial,
    final List<Card> discardPile = const [],
    this.handNumber = 1,
    this.targetHands = 5,
  }) : _players = players,
       _discardPile = discardPile;

  factory _$GameStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameStateImplFromJson(json);

  final List<Player> _players;
  @override
  List<Player> get players {
    if (_players is EqualUnmodifiableListView) return _players;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_players);
  }

  @override
  @JsonKey()
  final int currentRound;
  @override
  @JsonKey()
  final int currentPlayerIndex;
  @override
  @JsonKey()
  final GamePhase phase;
  @override
  @JsonKey()
  final RoundPhase roundPhase;
  final List<Card> _discardPile;
  @override
  @JsonKey()
  List<Card> get discardPile {
    if (_discardPile is EqualUnmodifiableListView) return _discardPile;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_discardPile);
  }

  @override
  @JsonKey()
  final int handNumber;
  @override
  @JsonKey()
  final int targetHands;

  @override
  String toString() {
    return 'GameState(players: $players, currentRound: $currentRound, currentPlayerIndex: $currentPlayerIndex, phase: $phase, roundPhase: $roundPhase, discardPile: $discardPile, handNumber: $handNumber, targetHands: $targetHands)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameStateImpl &&
            const DeepCollectionEquality().equals(other._players, _players) &&
            (identical(other.currentRound, currentRound) ||
                other.currentRound == currentRound) &&
            (identical(other.currentPlayerIndex, currentPlayerIndex) ||
                other.currentPlayerIndex == currentPlayerIndex) &&
            (identical(other.phase, phase) || other.phase == phase) &&
            (identical(other.roundPhase, roundPhase) ||
                other.roundPhase == roundPhase) &&
            const DeepCollectionEquality().equals(
              other._discardPile,
              _discardPile,
            ) &&
            (identical(other.handNumber, handNumber) ||
                other.handNumber == handNumber) &&
            (identical(other.targetHands, targetHands) ||
                other.targetHands == targetHands));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_players),
    currentRound,
    currentPlayerIndex,
    phase,
    roundPhase,
    const DeepCollectionEquality().hash(_discardPile),
    handNumber,
    targetHands,
  );

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameStateImplCopyWith<_$GameStateImpl> get copyWith =>
      __$$GameStateImplCopyWithImpl<_$GameStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameStateImplToJson(this);
  }
}

abstract class _GameState implements GameState {
  const factory _GameState({
    required final List<Player> players,
    final int currentRound,
    final int currentPlayerIndex,
    final GamePhase phase,
    final RoundPhase roundPhase,
    final List<Card> discardPile,
    final int handNumber,
    final int targetHands,
  }) = _$GameStateImpl;

  factory _GameState.fromJson(Map<String, dynamic> json) =
      _$GameStateImpl.fromJson;

  @override
  List<Player> get players;
  @override
  int get currentRound;
  @override
  int get currentPlayerIndex;
  @override
  GamePhase get phase;
  @override
  RoundPhase get roundPhase;
  @override
  List<Card> get discardPile;
  @override
  int get handNumber;
  @override
  int get targetHands;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameStateImplCopyWith<_$GameStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

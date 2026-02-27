// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentPlayerHash() => r'83b74725c73211c5a89e19adea63745d74343d2e';

/// 현재 턴 플레이어
///
/// Copied from [currentPlayer].
@ProviderFor(currentPlayer)
final currentPlayerProvider = AutoDisposeProvider<Player?>.internal(
  currentPlayer,
  name: r'currentPlayerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentPlayerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentPlayerRef = AutoDisposeProviderRef<Player?>;
String _$isMyTurnHash() => r'7efa85f3176bb8219c61e742452f1532d82dc26b';

/// 내 턴 여부 (로컬 플레이어 ID 기준)
///
/// Copied from [isMyTurn].
@ProviderFor(isMyTurn)
final isMyTurnProvider = AutoDisposeProvider<bool>.internal(
  isMyTurn,
  name: r'isMyTurnProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isMyTurnHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsMyTurnRef = AutoDisposeProviderRef<bool>;
String _$availableLinesHash() => r'da6297c0b5c89cf4260ed7e082a03492a734455d';

/// 현재 플레이어가 배치 가능한 라인 목록
///
/// Copied from [availableLines].
@ProviderFor(availableLines)
final availableLinesProvider = AutoDisposeProvider<List<String>>.internal(
  availableLines,
  name: r'availableLinesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$availableLinesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableLinesRef = AutoDisposeProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

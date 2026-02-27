// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'score_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$roundScoresHash() => r'197c4e0f4a9c1d928dd507c3fb481f331bbb7cc9';

/// 현재 라운드 점수 맵 (playerId → score)
///
/// Copied from [roundScores].
@ProviderFor(roundScores)
final roundScoresProvider = AutoDisposeProvider<Map<String, int>?>.internal(
  roundScores,
  name: r'roundScoresProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$roundScoresHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RoundScoresRef = AutoDisposeProviderRef<Map<String, int>?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

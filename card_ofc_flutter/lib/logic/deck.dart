import 'dart:math';
import '../models/card.dart';

class Deck {
  final List<Card> _cards = [];
  late final Random _random;
  final int? seed;

  Deck({this.seed}) {
    _random = seed != null ? Random(seed) : Random();
    _init();
    shuffle();
  }

  void _init() {
    _cards.clear();
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        _cards.add(Card(rank: rank, suit: suit));
      }
    }
  }

  void shuffle() {
    _cards.shuffle(_random);
  }

  void reset() {
    _init();
    shuffle();
  }

  int get remaining => _cards.length;

  List<Card> deal(int n) {
    final count = n > _cards.length ? _cards.length : n;
    final dealt = _cards.sublist(0, count);
    _cards.removeRange(0, count);
    return dealt;
  }

  List<Card> dealAll() {
    return deal(_cards.length);
  }
}

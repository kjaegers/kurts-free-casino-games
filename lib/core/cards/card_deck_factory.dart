import 'dart:math';

import 'playing_card.dart';

class CardDeckFactory {
  const CardDeckFactory();

  /// The 52 cards in suit and rank order, face down, followed by [jokers]
  /// jokers. Only games whose rules use jokers should ask for any.
  ///
  /// Joker ids are `J01`, `J02`, …
  List<PlayingCard> createOrderedDeck({int jokers = 0}) {
    assert(jokers >= 0 && jokers <= 99);
    final cards = <PlayingCard>[];
    for (final suit in CardSuit.values) {
      for (final rank in CardRank.values) {
        cards.add(
          PlayingCard(
            id: _buildCardId(suit: suit, rank: rank),
            suit: suit,
            rank: rank,
            faceUp: false,
          ),
        );
      }
    }
    for (var i = 1; i <= jokers; i++) {
      cards.add(PlayingCard.joker(id: jokerId(i)));
    }
    return cards;
  }

  List<PlayingCard> createShuffledDeck({
    Random? random,
    int? seed,
    int jokers = 0,
  }) {
    assert(random == null || seed == null);

    final cards = createOrderedDeck(jokers: jokers);
    cards.shuffle(random ?? Random(seed));
    return cards;
  }

  /// The id of the [number]th joker (1-based) in a deck.
  static String jokerId(int number) => 'J${number.toString().padLeft(2, '0')}';

  static String _buildCardId({required CardSuit suit, required CardRank rank}) {
    return '${suit.symbol}${rank.value.toString().padLeft(2, '0')}';
  }
}

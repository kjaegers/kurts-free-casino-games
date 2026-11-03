import '../../../../core/cards/playing_card.dart';

/// A card's blackjack value with an ace counted as 1: 2–10 at face value,
/// picture cards 10.
int blackjackCardValue(PlayingCard card) =>
    card.rank.value > 10 ? 10 : card.rank.value;

/// The best total of [cards] (an ace counts 11 when that doesn't bust) and
/// whether that total is soft (an ace is counting as 11).
({int total, bool soft}) blackjackTotal(Iterable<PlayingCard> cards) {
  var total = 0;
  var hasAce = false;
  for (final card in cards) {
    total += blackjackCardValue(card);
    if (card.isAce) hasAce = true;
  }
  if (hasAce && total + 10 <= 21) return (total: total + 10, soft: true);
  return (total: total, soft: false);
}

/// How one player hand ended against the dealer.
enum BlackjackOutcome {
  /// A two-card 21 on the first deal, paid 3:2.
  blackjack('Blackjack'),
  win('Win'),
  push('Push'),
  lose('Lose'),
  bust('Bust'),
  surrender('Surrender');

  const BlackjackOutcome(this.label);

  final String label;
}

/// One player hand as an immutable value: its cards, its stake and how it
/// has been played. The game decides what is legal; this only records it.
class BlackjackHand {
  const BlackjackHand({
    required this.cards,
    required this.bet,
    this.doubled = false,
    this.fromSplit = false,
    this.splitAces = false,
    this.surrendered = false,
    this.stood = false,
  });

  final List<PlayingCard> cards;

  /// Credits riding on this hand, doubled when [doubled].
  final int bet;
  final bool doubled;

  /// Made by splitting a pair, so a two-card 21 is not a blackjack.
  final bool fromSplit;

  /// One of a pair of split aces: it gets one card and no more.
  final bool splitAces;
  final bool surrendered;
  final bool stood;

  int get total => blackjackTotal(cards).total;
  bool get isSoft => blackjackTotal(cards).soft;
  bool get isBust => total > 21;
  bool get isBlackjack => !fromSplit && cards.length == 2 && total == 21;

  /// A pair that could be split (the game also limits the number of hands).
  bool get isPair =>
      cards.length == 2 && !splitAces && cards[0].rank == cards[1].rank;

  /// No more decisions for this hand.
  bool get isDone =>
      stood ||
      surrendered ||
      isBust ||
      total == 21 ||
      (doubled && cards.length == 3) ||
      (splitAces && cards.length == 2);

  /// Still in the game when the dealer plays.
  bool get isLive => !surrendered && !isBust;

  BlackjackHand copyWith({
    List<PlayingCard>? cards,
    int? bet,
    bool? doubled,
    bool? surrendered,
    bool? stood,
  }) {
    return BlackjackHand(
      cards: cards ?? this.cards,
      bet: bet ?? this.bet,
      doubled: doubled ?? this.doubled,
      fromSplit: fromSplit,
      splitAces: splitAces,
      surrendered: surrendered ?? this.surrendered,
      stood: stood ?? this.stood,
    );
  }

  BlackjackHand withCard(PlayingCard card) => copyWith(
    cards: List.unmodifiable([...cards, card.copyWith(faceUp: true)]),
  );
}

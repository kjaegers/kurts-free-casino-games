import '../../../../core/cards/playing_card.dart';

/// Every final-hand category any variant pays for, best first.
enum VideoPokerHand {
  royalFlush('Royal Flush'),
  fourDeuces('Four Deuces'),
  wildRoyal('Wild Royal Flush'),
  fiveOfAKind('Five of a Kind'),
  straightFlush('Straight Flush'),
  fourOfAKind('Four of a Kind'),
  fullHouse('Full House'),
  flush('Flush'),
  straight('Straight'),
  threeOfAKind('Three of a Kind'),
  twoPair('Two Pair'),
  highPair('High Pair');

  const VideoPokerHand(this.label);

  /// The general name; [VideoPokerVariant.labelFor] gives the name a variant
  /// prints on its paytable (e.g. "Jacks or Better" for [highPair]).
  final String label;

  static VideoPokerHand? tryFromName(Object? name) {
    for (final hand in values) {
      if (hand.name == name) return hand;
    }
    return null;
  }
}

/// One paytable row: [pays] coins for each coin bet.
class VideoPokerPayLine {
  const VideoPokerPayLine(this.hand, this.pays, [this.label]);

  final VideoPokerHand hand;
  final int pays;

  /// Overrides [VideoPokerHand.label] on this variant's paytable.
  final String? label;
}

/// Coins a hand may bet.
const int videoPokerMinBet = 1;
const int videoPokerMaxBet = 5;

/// A Royal Flush pays this per coin at [videoPokerMaxBet] (4,000 for 5
/// coins) instead of its listed 250, as on real machines.
const int videoPokerMaxBetRoyalPays = 800;

/// The video poker games on offer. All are five-card draw against a fixed
/// paytable: one deal, one draw, paid by the final hand.
///
/// Each paytable is the classic "full pay" table for its game, listed in
/// descending order of pay. The returns are for perfect play at
/// [videoPokerMaxBet], computed by `tools/video_poker/return_check.dart`.
enum VideoPokerVariant {
  jokerPoker(
    label: 'Joker Poker',
    summary:
        '53-card deck with one wild joker. A pair of Kings or better pays.',
    jokers: 1,
    deucesAreWild: false,
    highPairMinRank: 13,
    returnPercent: '100.65',
    paytable: [
      VideoPokerPayLine(VideoPokerHand.royalFlush, 250, 'Natural Royal'),
      VideoPokerPayLine(VideoPokerHand.fiveOfAKind, 200),
      VideoPokerPayLine(VideoPokerHand.wildRoyal, 100),
      VideoPokerPayLine(VideoPokerHand.straightFlush, 50),
      VideoPokerPayLine(VideoPokerHand.fourOfAKind, 20),
      VideoPokerPayLine(VideoPokerHand.fullHouse, 7),
      VideoPokerPayLine(VideoPokerHand.flush, 5),
      VideoPokerPayLine(VideoPokerHand.straight, 3),
      VideoPokerPayLine(VideoPokerHand.threeOfAKind, 2),
      VideoPokerPayLine(VideoPokerHand.twoPair, 1),
      VideoPokerPayLine(VideoPokerHand.highPair, 1, 'Kings or Better'),
    ],
  ),
  jacksOrBetter(
    label: 'Jacks or Better',
    summary: 'The classic 52-card game. A pair of Jacks or better pays.',
    jokers: 0,
    deucesAreWild: false,
    highPairMinRank: 11,
    returnPercent: '99.54',
    paytable: [
      VideoPokerPayLine(VideoPokerHand.royalFlush, 250),
      VideoPokerPayLine(VideoPokerHand.straightFlush, 50),
      VideoPokerPayLine(VideoPokerHand.fourOfAKind, 25),
      VideoPokerPayLine(VideoPokerHand.fullHouse, 9),
      VideoPokerPayLine(VideoPokerHand.flush, 6),
      VideoPokerPayLine(VideoPokerHand.straight, 4),
      VideoPokerPayLine(VideoPokerHand.threeOfAKind, 3),
      VideoPokerPayLine(VideoPokerHand.twoPair, 2),
      VideoPokerPayLine(VideoPokerHand.highPair, 1, 'Jacks or Better'),
    ],
  ),
  deucesWild(
    label: 'Deuces Wild',
    summary: 'All four 2s are wild. Three of a Kind or better pays; no pairs.',
    jokers: 0,
    deucesAreWild: true,
    highPairMinRank: null,
    returnPercent: '100.76',
    paytable: [
      VideoPokerPayLine(VideoPokerHand.royalFlush, 250, 'Natural Royal'),
      VideoPokerPayLine(VideoPokerHand.fourDeuces, 200),
      VideoPokerPayLine(VideoPokerHand.wildRoyal, 25),
      VideoPokerPayLine(VideoPokerHand.fiveOfAKind, 15),
      VideoPokerPayLine(VideoPokerHand.straightFlush, 9),
      VideoPokerPayLine(VideoPokerHand.fourOfAKind, 5),
      VideoPokerPayLine(VideoPokerHand.fullHouse, 3),
      VideoPokerPayLine(VideoPokerHand.flush, 2),
      VideoPokerPayLine(VideoPokerHand.straight, 2),
      VideoPokerPayLine(VideoPokerHand.threeOfAKind, 1),
    ],
  );

  const VideoPokerVariant({
    required this.label,
    required this.summary,
    required this.jokers,
    required this.deucesAreWild,
    required this.highPairMinRank,
    required this.returnPercent,
    required this.paytable,
  });

  final String label;
  final String summary;

  /// Jokers shuffled into the deck (each one wild).
  final int jokers;

  /// Whether the four 2s are wild.
  final bool deucesAreWild;

  /// The lowest pair that pays (11 = Jacks, 13 = Kings, ace high = 14), or
  /// null when no pair pays.
  final int? highPairMinRank;

  /// Theoretical return with perfect play at the maximum bet, as printed in
  /// How to Play.
  final String returnPercent;

  final List<VideoPokerPayLine> paytable;

  int get deckSize => 52 + jokers;

  bool get hasWildCards => jokers > 0 || deucesAreWild;

  bool isWild(PlayingCard card) =>
      card.isJoker || (deucesAreWild && card.rank == CardRank.two);

  /// Coins per coin bet for [hand], or 0 when this variant doesn't pay it.
  int paysFor(VideoPokerHand hand) {
    for (final line in paytable) {
      if (line.hand == hand) return line.pays;
    }
    return 0;
  }

  String labelFor(VideoPokerHand hand) {
    for (final line in paytable) {
      if (line.hand == hand) return line.label ?? hand.label;
    }
    return hand.label;
  }

  /// Credits won by [hand] (null = no paying hand) on a [bet]-coin wager.
  /// The bet itself is already spent, so a 1-for-1 line returns the stake.
  int payout(VideoPokerHand? hand, int bet) {
    if (hand == null) return 0;
    if (hand == VideoPokerHand.royalFlush && bet == videoPokerMaxBet) {
      return videoPokerMaxBetRoyalPays * bet;
    }
    return paysFor(hand) * bet;
  }

  static VideoPokerVariant fromName(String? name) => values.firstWhere(
    (variant) => variant.name == name,
    orElse: () => VideoPokerVariant.jacksOrBetter,
  );

  static VideoPokerVariant? tryFromName(Object? name) {
    for (final variant in values) {
      if (variant.name == name) return variant;
    }
    return null;
  }
}

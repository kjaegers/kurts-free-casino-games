/// One completed Texas Hold'em hand, as reported to the stats.
class TexasHoldemHandRecord {
  const TexasHoldemHandRecord({
    required this.wagered,
    required this.collected,
    required this.wonPot,
    required this.folded,
    required this.showdown,
    required this.knockouts,
    this.showdownCategory,
  });

  /// Chips the player put into the pot, and chips taken back from it (pots
  /// won and unmatched bets returned).
  final int wagered;
  final int collected;

  /// The player won at least part of a pot.
  final bool wonPot;
  final bool folded;

  /// The player's cards were compared at a showdown.
  final bool showdown;

  /// Opponents the player knocked out this hand.
  final int knockouts;

  /// The player's hand category (`HoldemHandCategory.index`) at a showdown.
  final int? showdownCategory;

  int get net => collected - wagered;
}

/// Texas Hold'em statistics and preferences, kept in the shared stats blob.
class TexasHoldemStats {
  const TexasHoldemStats({
    this.hands = 0,
    this.handsWon = 0,
    this.handsFolded = 0,
    this.showdowns = 0,
    this.showdownsWon = 0,
    this.knockouts = 0,
    this.wagered = 0,
    this.collected = 0,
    this.biggestPot = 0,
    this.bestShowdownCategory = -1,
    this.preferredOpponents = 4,
    this.preferredDifficulty = 'normal',
  });

  /// Hands the player was dealt into.
  final int hands;

  /// Hands that ended with more chips than they started with.
  final int handsWon;
  final int handsFolded;
  final int showdowns;
  final int showdownsWon;
  final int knockouts;
  final int wagered;
  final int collected;

  /// The most chips collected in one hand.
  final int biggestPot;

  /// The best hand category shown down (`HoldemHandCategory.index`), -1 for
  /// none yet.
  final int bestShowdownCategory;

  /// The table last chosen, used to seat the next one.
  final int preferredOpponents;
  final String preferredDifficulty;

  int get net => collected - wagered;

  /// Hand category names, weakest first, in the order of the game's
  /// `HoldemHandCategory` (a test keeps the two in step).
  static const List<String> categoryLabels = [
    'High Card',
    'Pair',
    'Two Pair',
    'Three of a Kind',
    'Straight',
    'Flush',
    'Full House',
    'Four of a Kind',
    'Straight Flush',
  ];

  String? get bestShowdownLabel =>
      bestShowdownCategory < 0 || bestShowdownCategory >= categoryLabels.length
      ? null
      : categoryLabels[bestShowdownCategory];

  TexasHoldemStats copyWithHand(TexasHoldemHandRecord hand) {
    final category = hand.showdownCategory ?? -1;
    return TexasHoldemStats(
      hands: hands + 1,
      handsWon: handsWon + (hand.net > 0 ? 1 : 0),
      handsFolded: handsFolded + (hand.folded ? 1 : 0),
      showdowns: showdowns + (hand.showdown ? 1 : 0),
      showdownsWon: showdownsWon + (hand.showdown && hand.wonPot ? 1 : 0),
      knockouts: knockouts + hand.knockouts,
      wagered: wagered + hand.wagered,
      collected: collected + hand.collected,
      biggestPot: hand.collected > biggestPot ? hand.collected : biggestPot,
      bestShowdownCategory: category > bestShowdownCategory
          ? category
          : bestShowdownCategory,
      preferredOpponents: preferredOpponents,
      preferredDifficulty: preferredDifficulty,
    );
  }

  TexasHoldemStats copyWithPreferences({int? opponents, String? difficulty}) {
    return TexasHoldemStats(
      hands: hands,
      handsWon: handsWon,
      handsFolded: handsFolded,
      showdowns: showdowns,
      showdownsWon: showdownsWon,
      knockouts: knockouts,
      wagered: wagered,
      collected: collected,
      biggestPot: biggestPot,
      bestShowdownCategory: bestShowdownCategory,
      preferredOpponents: opponents ?? preferredOpponents,
      preferredDifficulty: difficulty ?? preferredDifficulty,
    );
  }

  /// Clears the results but keeps the preferences (used by a stats reset).
  TexasHoldemStats copyWithPreferencesOnly() => TexasHoldemStats(
    preferredOpponents: preferredOpponents,
    preferredDifficulty: preferredDifficulty,
  );
}

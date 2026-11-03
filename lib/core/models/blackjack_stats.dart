/// One completed Blackjack round, as reported to the stats.
class BlackjackRoundRecord {
  const BlackjackRoundRecord({
    required this.wagered,
    required this.payout,
    required this.hands,
    required this.handsWon,
    required this.blackjack,
    required this.doubles,
    required this.splits,
    required this.surrendered,
  });

  /// Credits staked (bet, doubles, splits and insurance) and paid back.
  final int wagered;
  final int payout;

  /// Hands played this round (more than one after a split) and how many of
  /// them beat the dealer.
  final int hands;
  final int handsWon;

  /// The opening hand was a blackjack.
  final bool blackjack;
  final int doubles;
  final int splits;
  final bool surrendered;
}

/// Blackjack statistics and preferences, kept in the shared stats blob.
class BlackjackStats {
  const BlackjackStats({
    this.rounds = 0,
    this.roundsWon = 0,
    this.roundsPushed = 0,
    this.hands = 0,
    this.handsWon = 0,
    this.blackjacks = 0,
    this.doubles = 0,
    this.splits = 0,
    this.surrenders = 0,
    this.wagered = 0,
    this.paid = 0,
    this.biggestWin = 0,
    this.preferredBet = 10,
  });

  final int rounds;

  /// Rounds that paid back more than was staked.
  final int roundsWon;

  /// Rounds that paid back exactly what was staked.
  final int roundsPushed;
  final int hands;
  final int handsWon;
  final int blackjacks;
  final int doubles;
  final int splits;
  final int surrenders;
  final int wagered;
  final int paid;

  /// The largest payout from a single round.
  final int biggestWin;

  /// The opening bet last chosen, used to start the next session.
  final int preferredBet;

  int get net => paid - wagered;

  BlackjackStats copyWithRound(BlackjackRoundRecord round) {
    return BlackjackStats(
      rounds: rounds + 1,
      roundsWon: roundsWon + (round.payout > round.wagered ? 1 : 0),
      roundsPushed: roundsPushed + (round.payout == round.wagered ? 1 : 0),
      hands: hands + round.hands,
      handsWon: handsWon + round.handsWon,
      blackjacks: blackjacks + (round.blackjack ? 1 : 0),
      doubles: doubles + round.doubles,
      splits: splits + round.splits,
      surrenders: surrenders + (round.surrendered ? 1 : 0),
      wagered: wagered + round.wagered,
      paid: paid + round.payout,
      biggestWin: round.payout > biggestWin ? round.payout : biggestWin,
      preferredBet: preferredBet,
    );
  }

  BlackjackStats copyWithPreferences({int? bet}) {
    return BlackjackStats(
      rounds: rounds,
      roundsWon: roundsWon,
      roundsPushed: roundsPushed,
      hands: hands,
      handsWon: handsWon,
      blackjacks: blackjacks,
      doubles: doubles,
      splits: splits,
      surrenders: surrenders,
      wagered: wagered,
      paid: paid,
      biggestWin: biggestWin,
      preferredBet: bet ?? preferredBet,
    );
  }

  /// Clears the results but keeps the preferences (used by a stats reset).
  BlackjackStats copyWithPreferencesOnly() =>
      BlackjackStats(preferredBet: preferredBet);
}

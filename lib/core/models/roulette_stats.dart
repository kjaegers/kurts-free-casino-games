/// One completed roulette spin, as reported to the stats.
class RouletteSpinRecord {
  const RouletteSpinRecord({
    required this.bet,
    required this.payout,
    required this.pocket,
    required this.straightWins,
  });

  /// Credits staked (every bet on the table) and credits paid back.
  final int bet;
  final int payout;

  /// Where the ball landed, 0–36.
  final int pocket;

  /// Straight-up bets that won (0 or 1: only one number comes up).
  final int straightWins;
}

/// Roulette statistics and preferences, kept in the shared stats blob.
class RouletteStats {
  const RouletteStats({
    this.spins = 0,
    this.spinsWon = 0,
    this.spinsPushed = 0,
    this.wagered = 0,
    this.paid = 0,
    this.biggestWin = 0,
    this.straightWins = 0,
    this.zeros = 0,
    this.preferredChip = 5,
  });

  final int spins;

  /// Spins that paid more than the stake.
  final int spinsWon;

  /// Spins that paid back exactly the stake.
  final int spinsPushed;
  final int wagered;
  final int paid;

  /// The largest payout from a single spin.
  final int biggestWin;

  /// Straight-up (single number) bets that won.
  final int straightWins;

  /// Spins that landed on 0.
  final int zeros;

  /// The chip value last chosen, used to start the next session.
  final int preferredChip;

  int get net => paid - wagered;

  RouletteStats copyWithSpin(RouletteSpinRecord spin) {
    return RouletteStats(
      spins: spins + 1,
      spinsWon: spinsWon + (spin.payout > spin.bet ? 1 : 0),
      spinsPushed: spinsPushed + (spin.payout == spin.bet ? 1 : 0),
      wagered: wagered + spin.bet,
      paid: paid + spin.payout,
      biggestWin: spin.payout > biggestWin ? spin.payout : biggestWin,
      straightWins: straightWins + spin.straightWins,
      zeros: zeros + (spin.pocket == 0 ? 1 : 0),
      preferredChip: preferredChip,
    );
  }

  RouletteStats copyWithPreferences({int? chip}) {
    return RouletteStats(
      spins: spins,
      spinsWon: spinsWon,
      spinsPushed: spinsPushed,
      wagered: wagered,
      paid: paid,
      biggestWin: biggestWin,
      straightWins: straightWins,
      zeros: zeros,
      preferredChip: chip ?? preferredChip,
    );
  }

  /// Clears the results but keeps the preferences (used by a stats reset).
  RouletteStats copyWithPreferencesOnly() =>
      RouletteStats(preferredChip: preferredChip);
}

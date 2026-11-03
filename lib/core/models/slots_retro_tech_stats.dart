/// One completed Retro Tech spin, as reported to the stats.
class RetroTechSpinRecord {
  const RetroTechSpinRecord({
    required this.bet,
    required this.payout,
    required this.cascades,
    required this.clusterSymbols,
  });

  /// Credits wagered and credits paid back.
  final int bet;
  final int payout;

  /// Paying cascades in the spin (0 when it paid nothing).
  final int cascades;

  /// The symbol name of each winning cluster (one entry per cluster).
  final List<String> clusterSymbols;
}

/// Retro Tech statistics and preferences, kept in the shared stats blob.
class RetroTechStats {
  const RetroTechStats({
    this.spins = 0,
    this.spinsWon = 0,
    this.spinsPushed = 0,
    this.wagered = 0,
    this.paid = 0,
    this.biggestWin = 0,
    this.longestChain = 0,
    this.clusterCounts = const {},
    this.preferredBetLevel = 1,
  });

  final int spins;

  /// Spins that paid more than the bet.
  final int spinsWon;

  /// Spins that paid back exactly the bet.
  final int spinsPushed;
  final int wagered;
  final int paid;

  /// The largest payout from a single spin.
  final int biggestWin;

  /// The most paying cascades in one spin.
  final int longestChain;

  /// Winning clusters, by symbol name.
  final Map<String, int> clusterCounts;

  /// The bet level last chosen, used to start the next session.
  final int preferredBetLevel;

  int get net => paid - wagered;

  /// Winning clusters of [symbolName].
  int countOf(String symbolName) => clusterCounts[symbolName] ?? 0;

  RetroTechStats copyWithSpin(RetroTechSpinRecord spin) {
    final counts = Map<String, int>.of(clusterCounts);
    for (final name in spin.clusterSymbols) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return RetroTechStats(
      spins: spins + 1,
      spinsWon: spinsWon + (spin.payout > spin.bet ? 1 : 0),
      spinsPushed: spinsPushed + (spin.payout == spin.bet ? 1 : 0),
      wagered: wagered + spin.bet,
      paid: paid + spin.payout,
      biggestWin: spin.payout > biggestWin ? spin.payout : biggestWin,
      longestChain: spin.cascades > longestChain ? spin.cascades : longestChain,
      clusterCounts: Map.unmodifiable(counts),
      preferredBetLevel: preferredBetLevel,
    );
  }

  RetroTechStats copyWithPreferences({int? betLevel}) {
    return RetroTechStats(
      spins: spins,
      spinsWon: spinsWon,
      spinsPushed: spinsPushed,
      wagered: wagered,
      paid: paid,
      biggestWin: biggestWin,
      longestChain: longestChain,
      clusterCounts: clusterCounts,
      preferredBetLevel: betLevel ?? preferredBetLevel,
    );
  }

  /// Clears the results but keeps the preferences (used by a stats reset).
  RetroTechStats copyWithPreferencesOnly() =>
      RetroTechStats(preferredBetLevel: preferredBetLevel);
}

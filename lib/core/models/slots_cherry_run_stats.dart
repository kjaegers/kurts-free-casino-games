/// One completed Cherry Run spin, as reported to the stats.
class CherryRunSpinRecord {
  const CherryRunSpinRecord({
    required this.bet,
    required this.payout,
    required this.winNames,
  });

  /// Credits wagered (every line played) and credits paid back.
  final int bet;
  final int payout;

  /// The name of each paying line's win (one entry per line).
  final List<String> winNames;
}

/// Cherry Run statistics and preferences, kept in the shared stats blob.
class CherryRunStats {
  const CherryRunStats({
    this.spins = 0,
    this.spinsWon = 0,
    this.spinsPushed = 0,
    this.wagered = 0,
    this.paid = 0,
    this.biggestWin = 0,
    this.winCounts = const {},
    this.preferredLines = 3,
    this.preferredBetPerLine = 1,
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

  /// Paying lines, by win name.
  final Map<String, int> winCounts;

  /// The lines and bet per line last chosen, used to start the next session.
  final int preferredLines;
  final int preferredBetPerLine;

  int get net => paid - wagered;

  /// Times [winName] was paid on a line.
  int countOf(String winName) => winCounts[winName] ?? 0;

  CherryRunStats copyWithSpin(CherryRunSpinRecord spin) {
    final counts = Map<String, int>.of(winCounts);
    for (final name in spin.winNames) {
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return CherryRunStats(
      spins: spins + 1,
      spinsWon: spinsWon + (spin.payout > spin.bet ? 1 : 0),
      spinsPushed: spinsPushed + (spin.payout == spin.bet ? 1 : 0),
      wagered: wagered + spin.bet,
      paid: paid + spin.payout,
      biggestWin: spin.payout > biggestWin ? spin.payout : biggestWin,
      winCounts: Map.unmodifiable(counts),
      preferredLines: preferredLines,
      preferredBetPerLine: preferredBetPerLine,
    );
  }

  CherryRunStats copyWithPreferences({int? lines, int? betPerLine}) {
    return CherryRunStats(
      spins: spins,
      spinsWon: spinsWon,
      spinsPushed: spinsPushed,
      wagered: wagered,
      paid: paid,
      biggestWin: biggestWin,
      winCounts: winCounts,
      preferredLines: lines ?? preferredLines,
      preferredBetPerLine: betPerLine ?? preferredBetPerLine,
    );
  }

  /// Clears the results but keeps the preferences (used by a stats reset).
  CherryRunStats copyWithPreferencesOnly() => CherryRunStats(
    preferredLines: preferredLines,
    preferredBetPerLine: preferredBetPerLine,
  );
}

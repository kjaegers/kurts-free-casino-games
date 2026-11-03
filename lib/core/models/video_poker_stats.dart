/// One completed Video Poker hand, as reported to the stats.
class VideoPokerHandRecord {
  const VideoPokerHandRecord({
    required this.variantName,
    required this.handName,
    required this.bet,
    required this.payout,
  });

  final String variantName;

  /// The paying hand's name, or null when it paid nothing.
  final String? handName;

  /// Credits wagered and credits paid back.
  final int bet;
  final int payout;
}

/// Video Poker results in one variant.
class VideoPokerVariantRecord {
  const VideoPokerVariantRecord({
    this.hands = 0,
    this.handsWon = 0,
    this.handsPushed = 0,
    this.wagered = 0,
    this.paid = 0,
    this.biggestWin = 0,
    this.handCounts = const {},
  });

  final int hands;

  /// Hands that paid more than the bet.
  final int handsWon;

  /// Hands that paid back exactly the bet.
  final int handsPushed;
  final int wagered;
  final int paid;

  /// The largest single payout.
  final int biggestWin;

  /// Paying hands made, by hand name.
  final Map<String, int> handCounts;

  int get net => paid - wagered;

  VideoPokerVariantRecord withHand(VideoPokerHandRecord hand) {
    final name = hand.handName;
    return VideoPokerVariantRecord(
      hands: hands + 1,
      handsWon: handsWon + (hand.payout > hand.bet ? 1 : 0),
      handsPushed: handsPushed + (hand.payout == hand.bet ? 1 : 0),
      wagered: wagered + hand.bet,
      paid: paid + hand.payout,
      biggestWin: hand.payout > biggestWin ? hand.payout : biggestWin,
      handCounts: name == null
          ? handCounts
          : Map.unmodifiable({
              ...handCounts,
              name: (handCounts[name] ?? 0) + 1,
            }),
    );
  }
}

/// Video Poker statistics and preferences, kept in the shared stats blob.
class VideoPokerStats {
  const VideoPokerStats({
    this.byVariant = const {},
    this.preferredVariantName,
    this.preferredBet = 5,
  });

  /// Results keyed by variant name.
  final Map<String, VideoPokerVariantRecord> byVariant;

  /// The variant and bet last chosen, used to start the next session.
  final String? preferredVariantName;
  final int preferredBet;

  VideoPokerVariantRecord recordFor(String variantName) =>
      byVariant[variantName] ?? const VideoPokerVariantRecord();

  int get hands => _sum((r) => r.hands);
  int get handsWon => _sum((r) => r.handsWon);
  int get wagered => _sum((r) => r.wagered);
  int get paid => _sum((r) => r.paid);
  int get net => paid - wagered;

  int get biggestWin => byVariant.values.fold(
    0,
    (best, r) => r.biggestWin > best ? r.biggestWin : best,
  );

  /// Times [handName] was made, across every variant.
  int countOf(String handName) => _sum((r) => r.handCounts[handName] ?? 0);

  int _sum(int Function(VideoPokerVariantRecord) pick) =>
      byVariant.values.fold(0, (total, r) => total + pick(r));

  VideoPokerStats copyWithHand(VideoPokerHandRecord hand) {
    return VideoPokerStats(
      byVariant: Map.unmodifiable({
        ...byVariant,
        hand.variantName: recordFor(hand.variantName).withHand(hand),
      }),
      preferredVariantName: preferredVariantName,
      preferredBet: preferredBet,
    );
  }

  VideoPokerStats copyWithPreferences({String? variantName, int? bet}) {
    return VideoPokerStats(
      byVariant: byVariant,
      preferredVariantName: variantName ?? preferredVariantName,
      preferredBet: bet ?? preferredBet,
    );
  }

  /// Clears the results but keeps the preferences (used by a stats reset).
  VideoPokerStats copyWithPreferencesOnly() => VideoPokerStats(
    preferredVariantName: preferredVariantName,
    preferredBet: preferredBet,
  );
}

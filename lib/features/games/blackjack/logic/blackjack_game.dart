import '../../../../core/cards/card_deck_factory.dart';
import '../../../../core/cards/playing_card.dart';
import '../../../../core/cards/playing_card_codec.dart';
import 'blackjack_hand.dart';

// ── Table rules ──────────────────────────────────────────────────────────────

const int blackjackDecks = 6;
const int blackjackShoeSize = 52 * blackjackDecks;

/// A fresh shoe is shuffled before a round once fewer cards than this are
/// left (the last quarter of the shoe is never dealt). One round can use at
/// most 74 cards: four hands busting at 31 or less and the dealer stopping
/// at 26 or less add up to at most 150 points, and the smallest 74 cards in
/// the shoe (24 aces, 24 twos, 24 threes and two fours) already make 152.
/// So the shoe never runs out mid-round.
const int blackjackCutCard = blackjackShoeSize ~/ 4;

const int blackjackMinBet = 10;
const int blackjackMaxBet = 1000;

/// Bets go up in steps of 10 so a 3:2 blackjack and a half-bet insurance or
/// surrender are always whole credits.
const int blackjackBetStep = 10;

/// The most hands a player can split into.
const int blackjackMaxHands = 4;

/// The long-run return for perfect basic strategy under these rules, as
/// published in How to Play. Checked by `tools/blackjack/return_check.dart`.
const String blackjackReturnPercent = '99.6';

bool isValidBlackjackBet(int bet) =>
    bet >= blackjackMinBet &&
    bet <= blackjackMaxBet &&
    bet % blackjackBetStep == 0;

/// Where a round is.
enum BlackjackPhase {
  /// Choosing a bet before the deal.
  betting,

  /// The dealer shows an ace: insurance is offered before the peek.
  insurance,

  /// The player is acting on [BlackjackGame.activeHand].
  playerTurn,

  /// The dealer has played and every hand is settled.
  complete,
}

/// One round of blackjack against the dealer as an immutable value.
/// Transitions return a new instance and throw [StateError] when illegal;
/// check the matching `can…` getter first.
///
/// Rules: six decks, dealer stands on all 17s and peeks for blackjack with
/// an ace or ten showing, blackjack pays 3:2, insurance pays 2:1, double on
/// any first two cards (also after a split), split pairs of equal rank up
/// to [blackjackMaxHands] hands, split aces take one card each and can't be
/// split again, and late surrender on the first two cards.
///
/// Credits live outside the game: the bet is taken at [deal], each double,
/// split or insurance costs the amount the matching `…Cost` getter gives,
/// and [payout] is paid once the round is [BlackjackPhase.complete].
///
/// Cards come off the front of [shoe] in order, so a saved round always
/// deals exactly the cards it would have dealt.
class BlackjackGame {
  const BlackjackGame._({
    required this.phase,
    required this.bet,
    required this.shoe,
    required this.dealer,
    required this.hands,
    required this.activeIndex,
    required this.insurance,
    required this.freshShoe,
  });

  /// A table waiting for the first deal. The shoe is shuffled on it.
  factory BlackjackGame.newSession({int bet = blackjackMinBet}) {
    return BlackjackGame._(
      phase: BlackjackPhase.betting,
      bet: isValidBlackjackBet(bet) ? bet : blackjackMinBet,
      shoe: const [],
      dealer: const [],
      hands: const [],
      activeIndex: 0,
      insurance: 0,
      freshShoe: false,
    );
  }

  final BlackjackPhase phase;

  /// The opening bet for each round.
  final int bet;

  /// The undealt cards, face down, in dealing order.
  final List<PlayingCard> shoe;

  /// The dealer's cards. The second (the hole card) stays face down until
  /// the dealer plays or has blackjack.
  final List<PlayingCard> dealer;

  /// The player's hands: one, or up to four after splits.
  final List<BlackjackHand> hands;

  /// The hand being played during [BlackjackPhase.playerTurn].
  final int activeIndex;

  /// Credits staked on insurance this round (0 when declined or not offered).
  final int insurance;

  /// This round was dealt from a freshly shuffled shoe.
  final bool freshShoe;

  bool get isInPlay =>
      phase == BlackjackPhase.insurance || phase == BlackjackPhase.playerTurn;
  bool get isComplete => phase == BlackjackPhase.complete;

  BlackjackHand? get activeHand =>
      phase == BlackjackPhase.playerTurn ? hands[activeIndex] : null;

  /// The dealer's face-up card, or null before the deal.
  PlayingCard? get dealerUpCard => dealer.isEmpty ? null : dealer.first;

  bool get holeCardRevealed => dealer.length >= 2 && dealer[1].faceUp;

  /// The dealer's total counting only the cards that are face up.
  int get dealerVisibleTotal =>
      blackjackTotal(dealer.where((c) => c.faceUp)).total;

  int get dealerTotal => blackjackTotal(dealer).total;
  bool get dealerHasBlackjack => dealer.length == 2 && dealerTotal == 21;
  bool get dealerBust => dealerTotal > 21;

  /// The next deal shuffles a fresh shoe first.
  bool get needsShuffle => shoe.length < blackjackCutCard;

  // ── What the player may do ─────────────────────────────────────────────────

  bool get canChangeBet => !isInPlay;
  bool get canDeal => !isInPlay;
  bool get canDecideInsurance => phase == BlackjackPhase.insurance;
  bool get canHit => activeHand != null;
  bool get canStand => activeHand != null;

  bool get canDouble => activeHand?.cards.length == 2;

  bool get canSplit =>
      (activeHand?.isPair ?? false) && hands.length < blackjackMaxHands;

  /// Late surrender: only the opening hand, before any other action.
  bool get canSurrender => hands.length == 1 && activeHand?.cards.length == 2;

  /// What insurance costs: half the bet.
  int get insuranceCost => bet ~/ 2;

  /// What doubling or splitting the active hand costs: its bet again.
  int get doubleCost => activeHand?.bet ?? 0;
  int get splitCost => activeHand?.bet ?? 0;

  // ── Money ──────────────────────────────────────────────────────────────────

  /// Everything staked this round: hand bets (with doubles and splits) and
  /// insurance.
  int get totalWagered => hands.fold(0, (sum, h) => sum + h.bet) + insurance;

  /// How [hand] did. Only meaningful once the round is complete.
  BlackjackOutcome outcomeOf(BlackjackHand hand) {
    if (hand.surrendered) return BlackjackOutcome.surrender;
    if (hand.isBust) return BlackjackOutcome.bust;
    final dealerBlackjack = dealerHasBlackjack;
    if (hand.isBlackjack) {
      return dealerBlackjack
          ? BlackjackOutcome.push
          : BlackjackOutcome.blackjack;
    }
    if (dealerBlackjack) return BlackjackOutcome.lose;
    if (dealerBust || hand.total > dealerTotal) return BlackjackOutcome.win;
    return hand.total == dealerTotal
        ? BlackjackOutcome.push
        : BlackjackOutcome.lose;
  }

  /// What [hand] pays back, stake included (0 until the round is complete).
  int payoutOf(BlackjackHand hand) {
    if (!isComplete) return 0;
    return switch (outcomeOf(hand)) {
      BlackjackOutcome.blackjack => hand.bet + hand.bet * 3 ~/ 2,
      BlackjackOutcome.win => hand.bet * 2,
      BlackjackOutcome.push => hand.bet,
      BlackjackOutcome.surrender => hand.bet ~/ 2,
      BlackjackOutcome.lose || BlackjackOutcome.bust => 0,
    };
  }

  /// What insurance pays back, stake included: 3× the stake (2:1) when the
  /// dealer has blackjack.
  int get insurancePayout =>
      isComplete && dealerHasBlackjack ? insurance * 3 : 0;

  /// Credits paid back by the whole round (0 until complete).
  int get payout =>
      hands.fold(0, (sum, h) => sum + payoutOf(h)) + insurancePayout;

  // ── Transitions ────────────────────────────────────────────────────────────

  BlackjackGame withBet(int bet) {
    if (!canChangeBet) {
      throw StateError('The bet is fixed until the round ends');
    }
    if (!isValidBlackjackBet(bet)) throw ArgumentError.value(bet, 'bet');
    return _copyWith(bet: bet);
  }

  /// Deals a new round: player, dealer, player, dealer (the hole card face
  /// down). When [needsShuffle], [shuffledShoe] must be a full shuffled
  /// six-deck shoe, which replaces the old one; otherwise it is ignored.
  BlackjackGame deal({List<PlayingCard>? shuffledShoe}) {
    if (!canDeal) throw StateError('Finish this round before dealing');
    var shoe = this.shoe;
    final fresh = needsShuffle;
    if (fresh) {
      if (shuffledShoe == null || !isFullShoe(shuffledShoe)) {
        throw ArgumentError('A full $blackjackDecks-deck shoe is needed');
      }
      shoe = [for (final c in shuffledShoe) c.copyWith(faceUp: false)];
    }
    final next = [...shoe];
    PlayingCard take({bool faceUp = true}) =>
        next.removeAt(0).copyWith(faceUp: faceUp);
    final player1 = take();
    final up = take();
    final player2 = take();
    final hole = take(faceUp: false);
    final round = BlackjackGame._(
      phase: BlackjackPhase.insurance,
      bet: bet,
      shoe: List.unmodifiable(next),
      dealer: List.unmodifiable([up, hole]),
      hands: List.unmodifiable([
        BlackjackHand(cards: List.unmodifiable([player1, player2]), bet: bet),
      ]),
      activeIndex: 0,
      insurance: 0,
      freshShoe: fresh,
    );
    // Insurance is only offered against an ace.
    return up.isAce ? round : round._peek();
  }

  /// Takes insurance (when [take]) or declines it, then the dealer peeks.
  BlackjackGame decideInsurance({required bool take}) {
    if (!canDecideInsurance) throw StateError('Insurance is not on offer');
    return _copyWith(insurance: take ? insuranceCost : 0)._peek();
  }

  BlackjackGame hit() {
    if (!canHit) throw StateError('No hand to hit');
    final (card, shoe) = _draw();
    return _replaceActive(activeHand!.withCard(card), shoe: shoe)._advance();
  }

  BlackjackGame stand() {
    if (!canStand) throw StateError('No hand to stand');
    return _replaceActive(activeHand!.copyWith(stood: true))._advance();
  }

  /// Doubles the active hand's bet for exactly one more card.
  BlackjackGame doubleDown() {
    if (!canDouble) throw StateError('Only a two-card hand can double');
    final hand = activeHand!;
    final (card, shoe) = _draw();
    return _replaceActive(
      hand.copyWith(bet: hand.bet * 2, doubled: true).withCard(card),
      shoe: shoe,
    )._advance();
  }

  /// Splits the active pair into two hands with the same bet each. The
  /// first takes its second card now, the second when its turn comes.
  BlackjackGame split() {
    if (!canSplit) throw StateError('This hand cannot be split');
    final hand = activeHand!;
    final aces = hand.cards.first.isAce;
    BlackjackHand half(PlayingCard card) => BlackjackHand(
      cards: List.unmodifiable([card]),
      bet: hand.bet,
      fromSplit: true,
      splitAces: aces,
    );
    final splitHands = [
      for (var i = 0; i < hands.length; i++)
        if (i == activeIndex) ...[
          half(hand.cards[0]),
          half(hand.cards[1]),
        ] else
          hands[i],
    ];
    return _copyWith(hands: List.unmodifiable(splitHands))._advance();
  }

  /// Gives up the opening hand for half the bet back.
  BlackjackGame surrender() {
    if (!canSurrender) throw StateError('Surrender is not allowed now');
    return _replaceActive(activeHand!.copyWith(surrendered: true))._advance();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  (PlayingCard, List<PlayingCard>) _draw() {
    if (shoe.isEmpty) throw StateError('The shoe is empty');
    return (shoe.first.copyWith(faceUp: true), List.unmodifiable(shoe.skip(1)));
  }

  BlackjackGame _replaceActive(BlackjackHand hand, {List<PlayingCard>? shoe}) {
    return _copyWith(
      shoe: shoe,
      hands: List.unmodifiable([
        for (var i = 0; i < hands.length; i++)
          i == activeIndex ? hand : hands[i],
      ]),
    );
  }

  /// The dealer checks the hole card. A dealer blackjack ends the round at
  /// once; otherwise a player blackjack is paid, or play begins.
  BlackjackGame _peek() {
    final playing = _copyWith(phase: BlackjackPhase.playerTurn);
    final upValue = blackjackCardValue(dealer.first);
    final dealerBlackjack =
        (upValue == 1 || upValue == 10) && dealerTotal == 21;
    if (dealerBlackjack || hands.first.isBlackjack) {
      return playing._settle(dealerPlays: false);
    }
    return playing._advance();
  }

  /// Moves play to the first hand still needing a decision, dealing a split
  /// hand its second card as its turn comes. When none is left, the dealer
  /// plays and the round is settled.
  BlackjackGame _advance() {
    var game = this;
    for (var i = 0; i < game.hands.length; i++) {
      var hand = game.hands[i];
      if (hand.cards.length == 1) {
        final (card, shoe) = game._draw();
        hand = hand.withCard(card);
        game = game._copyWith(activeIndex: i)._replaceActive(hand, shoe: shoe);
      }
      if (!hand.isDone) return game._copyWith(activeIndex: i);
    }
    return game._settle(dealerPlays: game.hands.any((h) => h.isLive));
  }

  /// Turns the hole card and, when [dealerPlays], draws to 17 or more,
  /// standing on soft 17.
  BlackjackGame _settle({required bool dealerPlays}) {
    final dealerCards = [for (final c in dealer) c.copyWith(faceUp: true)];
    final next = [...shoe];
    while (dealerPlays && blackjackTotal(dealerCards).total < 17) {
      if (next.isEmpty) throw StateError('The shoe is empty');
      dealerCards.add(next.removeAt(0).copyWith(faceUp: true));
    }
    return BlackjackGame._(
      phase: BlackjackPhase.complete,
      bet: bet,
      shoe: List.unmodifiable(next),
      dealer: List.unmodifiable(dealerCards),
      hands: hands,
      activeIndex: activeIndex,
      insurance: insurance,
      freshShoe: freshShoe,
    );
  }

  BlackjackGame _copyWith({
    BlackjackPhase? phase,
    int? bet,
    List<PlayingCard>? shoe,
    List<BlackjackHand>? hands,
    int? activeIndex,
    int? insurance,
  }) {
    return BlackjackGame._(
      phase: phase ?? this.phase,
      bet: bet ?? this.bet,
      shoe: shoe ?? this.shoe,
      dealer: dealer,
      hands: hands ?? this.hands,
      activeIndex: activeIndex ?? this.activeIndex,
      insurance: insurance ?? this.insurance,
      freshShoe: freshShoe,
    );
  }

  /// A full six-deck shoe: every card exactly [blackjackDecks] times.
  static bool isFullShoe(List<PlayingCard> cards) =>
      cards.length == blackjackShoeSize && _withinShoe(cards);

  /// No card appears more often than a six-deck shoe holds it.
  static bool _withinShoe(List<PlayingCard> cards) {
    final counts = <String, int>{};
    for (final card in cards) {
      if (card.isJoker) return false;
      final n = counts[card.id] = (counts[card.id] ?? 0) + 1;
      if (n > blackjackDecks) return false;
    }
    return cards.length <= blackjackShoeSize;
  }

  /// A full, shuffled six-deck shoe. Every card keeps its single-deck id
  /// (`H01`…), so ids repeat across decks: never key widgets by id alone.
  static List<PlayingCard> shuffledShoe(
    List<PlayingCard> Function(List<PlayingCard> cards) shuffle,
  ) {
    const factory = CardDeckFactory();
    return shuffle([
      for (var d = 0; d < blackjackDecks; d++) ...factory.createOrderedDeck(),
    ]);
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  static const int schemaVersion = 1;

  /// Only a round in play is worth saving: its bets have been taken and the
  /// rest of the shoe decides how it ends.
  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'phase': phase.name,
    'bet': bet,
    'shoe': encodeCardPile(shoe),
    'dealer': encodeCardPile(dealer),
    'hands': [
      for (final h in hands)
        {
          'cards': encodeCardPile(h.cards),
          'bet': h.bet,
          'doubled': h.doubled,
          'fromSplit': h.fromSplit,
          'splitAces': h.splitAces,
          'surrendered': h.surrendered,
          'stood': h.stood,
        },
    ],
    'active': activeIndex,
    'insurance': insurance,
    'freshShoe': freshShoe,
  };

  /// Restores a round saved in play. Returns null for anything malformed,
  /// inconsistent or not in play, never throwing.
  static BlackjackGame? fromJson(Map<String, dynamic> json) {
    try {
      if (json['version'] != schemaVersion) return null;
      final phase = BlackjackPhase.values
          .where((p) => p.name == json['phase'])
          .firstOrNull;
      final bet = json['bet'];
      final rawShoe = json['shoe'];
      final rawDealer = json['dealer'];
      final rawHands = json['hands'];
      final active = json['active'];
      final insurance = json['insurance'];
      final fresh = json['freshShoe'];
      if (phase == null ||
          !(phase == BlackjackPhase.insurance ||
              phase == BlackjackPhase.playerTurn) ||
          bet is! int ||
          !isValidBlackjackBet(bet) ||
          rawShoe is! String ||
          rawDealer is! String ||
          rawHands is! List ||
          rawHands.isEmpty ||
          rawHands.length > blackjackMaxHands ||
          active is! int ||
          active < 0 ||
          active >= rawHands.length ||
          insurance is! int ||
          (insurance != 0 && insurance != bet ~/ 2) ||
          fresh is! bool) {
        return null;
      }
      final hands = <BlackjackHand>[];
      for (final raw in rawHands) {
        if (raw is! Map) return null;
        final cards = raw['cards'];
        final handBet = raw['bet'];
        final flags = [
          for (final key in const [
            'doubled',
            'fromSplit',
            'splitAces',
            'surrendered',
            'stood',
          ])
            raw[key],
        ];
        if (cards is! String ||
            handBet is! int ||
            flags.any((f) => f is! bool)) {
          return null;
        }
        final hand = BlackjackHand(
          cards: List.unmodifiable([
            for (final c in decodeCardPile(cards)) c.copyWith(faceUp: true),
          ]),
          bet: handBet,
          doubled: flags[0] as bool,
          fromSplit: flags[1] as bool,
          splitAces: flags[2] as bool,
          surrendered: flags[3] as bool,
          stood: flags[4] as bool,
        );
        if (hand.bet != (hand.doubled ? bet * 2 : bet) ||
            hand.cards.isEmpty ||
            hand.fromSplit != (rawHands.length > 1)) {
          return null;
        }
        hands.add(hand);
      }
      final dealer = decodeCardPile(rawDealer);
      final shoe = [
        for (final c in decodeCardPile(rawShoe)) c.copyWith(faceUp: false),
      ];
      if (dealer.length != 2 ||
          !dealer[0].faceUp ||
          dealer[1].faceUp ||
          !_withinShoe([
            ...shoe,
            ...dealer,
            for (final h in hands) ...h.cards,
          ])) {
        return null;
      }
      // Every hand before the active one is finished, the active one needs
      // a decision, and the ones after it are waiting their turn.
      for (var i = 0; i < hands.length; i++) {
        final hand = hands[i];
        if (i < active && (!hand.isDone || hand.cards.length < 2)) return null;
        if (i == active &&
            phase == BlackjackPhase.playerTurn &&
            (hand.isDone || hand.cards.length < 2)) {
          return null;
        }
        if (i > active && hand.cards.length != 1) return null;
      }
      final dealerBlackjack = blackjackTotal(dealer).total == 21;
      if (phase == BlackjackPhase.insurance &&
          (hands.length != 1 || !dealer[0].isAce || insurance != 0)) {
        return null;
      }
      // Past the peek, a dealer blackjack would already have ended the round.
      if (phase == BlackjackPhase.playerTurn && dealerBlackjack) return null;
      return BlackjackGame._(
        phase: phase,
        bet: bet,
        shoe: List.unmodifiable(shoe),
        dealer: List.unmodifiable(dealer),
        hands: List.unmodifiable(hands),
        activeIndex: active,
        insurance: insurance,
        freshShoe: fresh,
      );
    } on FormatException {
      return null;
    } on StateError {
      return null;
    }
  }
}

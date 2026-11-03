import '../../../../core/cards/card_deck_factory.dart';
import '../../../../core/cards/playing_card.dart';
import '../../../../core/cards/playing_card_codec.dart';
import 'video_poker_evaluator.dart';
import 'video_poker_variant.dart';

/// Where a hand is.
enum VideoPokerPhase {
  /// Choosing a bet before the deal (or the first hand of a session).
  betting,

  /// Five cards dealt; choosing which to hold before the draw.
  holding,

  /// The draw is done and the hand has been paid.
  complete,
}

const int videoPokerHandSize = 5;

/// One hand of video poker as an immutable value. Transitions return a new
/// instance and throw [StateError] when illegal; check the matching `can…`
/// getter first.
///
/// Credits live outside the game: the bet is taken when [deal] is called
/// and [payout] is paid once the hand is [VideoPokerPhase.complete].
class VideoPokerGame {
  const VideoPokerGame._({
    required this.variant,
    required this.phase,
    required this.bet,
    required this.hand,
    required this.held,
    required this.stub,
    this.result,
  });

  /// A fresh session waiting for the first deal.
  factory VideoPokerGame.newSession({
    required VideoPokerVariant variant,
    int bet = videoPokerMaxBet,
  }) {
    return VideoPokerGame._(
      variant: variant,
      phase: VideoPokerPhase.betting,
      bet: bet.clamp(videoPokerMinBet, videoPokerMaxBet),
      hand: const [],
      held: const [false, false, false, false, false],
      stub: const [],
    );
  }

  final VideoPokerVariant variant;
  final VideoPokerPhase phase;

  /// Coins wagered, 1–5. Fixed from the deal until the hand is complete.
  final int bet;

  /// The five cards on the table, face up (empty before the first deal).
  /// After a hand completes it keeps showing the final hand.
  final List<PlayingCard> hand;
  final List<bool> held;

  /// The undealt cards in draw order. Replacements come from the front, so a
  /// saved hand always draws exactly the cards it would have drawn.
  final List<PlayingCard> stub;

  /// The final hand's category; null before the draw or when it pays
  /// nothing.
  final VideoPokerHand? result;

  bool get isHolding => phase == VideoPokerPhase.holding;
  bool get isComplete => phase == VideoPokerPhase.complete;

  /// Credits won by the final hand (0 until complete).
  int get payout => isComplete ? variant.payout(result, bet) : 0;

  /// What the five cards on the table make right now: the dealt hand while
  /// holding, the final hand once complete.
  VideoPokerHand? get currentHand => hand.length == videoPokerHandSize
      ? evaluateVideoPokerHand(hand, variant)
      : null;

  bool get canChangeBet => !isHolding;
  bool get canDeal => !isHolding;
  bool get canToggleHold => isHolding;
  bool get canDraw => isHolding;

  VideoPokerGame withBet(int coins) {
    if (!canChangeBet) throw StateError('The bet is fixed until the draw');
    if (coins < videoPokerMinBet || coins > videoPokerMaxBet) {
      throw RangeError.range(coins, videoPokerMinBet, videoPokerMaxBet);
    }
    return _copyWith(bet: coins);
  }

  /// Deals five cards from the top of [shuffledDeck], a full deck for this
  /// variant (with its jokers, if any) in random order.
  VideoPokerGame deal(List<PlayingCard> shuffledDeck) {
    if (!canDeal) throw StateError('Finish this hand before dealing');
    if (shuffledDeck.length != variant.deckSize ||
        shuffledDeck.where((c) => c.isJoker).length != variant.jokers ||
        shuffledDeck.map((c) => c.id).toSet().length != variant.deckSize) {
      throw ArgumentError('Not a full ${variant.label} deck');
    }
    return VideoPokerGame._(
      variant: variant,
      phase: VideoPokerPhase.holding,
      bet: bet,
      hand: List.unmodifiable([
        for (final card in shuffledDeck.take(videoPokerHandSize))
          card.copyWith(faceUp: true),
      ]),
      held: List.unmodifiable(List.filled(videoPokerHandSize, false)),
      stub: List.unmodifiable(shuffledDeck.skip(videoPokerHandSize)),
    );
  }

  VideoPokerGame toggleHold(int index) {
    if (!canToggleHold) {
      throw StateError('Cards can only be held before the draw');
    }
    RangeError.checkValidIndex(index, held, 'index');
    return _copyWith(
      held: List.unmodifiable([
        for (var i = 0; i < held.length; i++) i == index ? !held[i] : held[i],
      ]),
    );
  }

  /// Replaces every card not held, in order, and scores the final hand.
  VideoPokerGame draw() {
    if (!canDraw) throw StateError('Nothing to draw');
    var next = 0;
    final finalHand = <PlayingCard>[
      for (var i = 0; i < videoPokerHandSize; i++)
        held[i] ? hand[i] : stub[next++].copyWith(faceUp: true),
    ];
    return VideoPokerGame._(
      variant: variant,
      phase: VideoPokerPhase.complete,
      bet: bet,
      hand: List.unmodifiable(finalHand),
      held: held,
      stub: List.unmodifiable(stub.skip(next)),
      result: evaluateVideoPokerHand(finalHand, variant),
    );
  }

  /// Cards that were replaced on the draw (false while holding).
  List<bool> get drawn => [
    for (var i = 0; i < videoPokerHandSize; i++) isComplete && !held[i],
  ];

  VideoPokerGame _copyWith({int? bet, List<bool>? held}) {
    return VideoPokerGame._(
      variant: variant,
      phase: phase,
      bet: bet ?? this.bet,
      hand: hand,
      held: held ?? this.held,
      stub: stub,
      result: result,
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  static const int schemaVersion = 1;

  /// Only a hand in progress ([VideoPokerPhase.holding]) is worth saving: its
  /// bet has been taken and the draw is still to come.
  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'variant': variant.name,
    'phase': phase.name,
    'bet': bet,
    'hand': encodeCardPile(hand),
    'held': held,
    'stub': encodeCardPile(stub),
  };

  /// Restores a hand saved while holding. Returns null for anything
  /// malformed, inconsistent or not in progress, never throwing.
  static VideoPokerGame? fromJson(Map<String, dynamic> json) {
    try {
      if (json['version'] != schemaVersion) return null;
      final variant = VideoPokerVariant.tryFromName(json['variant']);
      final bet = json['bet'];
      final rawHeld = json['held'];
      final rawHand = json['hand'];
      final rawStub = json['stub'];
      if (variant == null ||
          json['phase'] != VideoPokerPhase.holding.name ||
          bet is! int ||
          bet < videoPokerMinBet ||
          bet > videoPokerMaxBet ||
          rawHeld is! List ||
          rawHeld.length != videoPokerHandSize ||
          rawHeld.any((h) => h is! bool) ||
          rawHand is! String ||
          rawStub is! String) {
        return null;
      }
      final hand = decodeCardPile(rawHand);
      final stub = decodeCardPile(rawStub);
      final all = [...hand, ...stub];
      if (hand.length != videoPokerHandSize ||
          all.length != variant.deckSize ||
          !_isFullDeck(all, variant)) {
        return null;
      }
      return VideoPokerGame._(
        variant: variant,
        phase: VideoPokerPhase.holding,
        bet: bet,
        hand: List.unmodifiable([
          for (final c in hand) c.copyWith(faceUp: true),
        ]),
        held: List.unmodifiable(rawHeld.cast<bool>()),
        stub: List.unmodifiable(stub),
      );
    } on FormatException {
      return null;
    }
  }

  /// Every card of [variant]'s deck exactly once.
  static bool _isFullDeck(List<PlayingCard> cards, VideoPokerVariant variant) {
    final expected = const CardDeckFactory()
        .createOrderedDeck(jokers: variant.jokers)
        .map((c) => c.id)
        .toSet();
    final ids = cards.map((c) => c.id).toSet();
    return ids.length == cards.length && ids.containsAll(expected);
  }
}

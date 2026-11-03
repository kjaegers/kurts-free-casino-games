import 'dart:math';

import '../../../../core/cards/playing_card.dart';
import '../../../../core/cards/playing_card_codec.dart';
import 'holdem_evaluator.dart';

/// Where a hand is. Each betting round is named after the cards out.
enum HoldemStreet { preflop, flop, turn, river, complete }

/// The last thing a seat did this betting round, shown beside it.
enum HoldemMove { smallBlind, bigBlind, fold, check, call, bet, raise, allIn }

enum HoldemDecisionKind { fold, checkOrCall, raiseTo }

/// What the seat to act chooses. [amount] is the total a raise (or opening
/// bet) brings the seat's bet this round to.
class HoldemDecision {
  const HoldemDecision.fold() : kind = HoldemDecisionKind.fold, amount = 0;
  const HoldemDecision.checkOrCall()
    : kind = HoldemDecisionKind.checkOrCall,
      amount = 0;
  const HoldemDecision.raiseTo(this.amount) : kind = HoldemDecisionKind.raiseTo;

  final HoldemDecisionKind kind;
  final int amount;

  @override
  String toString() =>
      kind == HoldemDecisionKind.raiseTo ? 'raiseTo($amount)' : kind.name;
}

/// One seat's part in a hand.
class HoldemSeat {
  const HoldemSeat({
    required this.stack,
    required this.hole,
    this.committed = 0,
    this.streetBet = 0,
    this.folded = false,
    this.acted = false,
    this.lastMove,
  });

  /// Chips still behind (not yet bet).
  final int stack;

  /// The two hole cards.
  final List<PlayingCard> hole;

  /// Everything put into the pot this hand.
  final int committed;

  /// What the seat has bet in the current betting round.
  final int streetBet;
  final bool folded;

  /// Has acted since the last full bet or raise. A seat that has acted can
  /// only call or fold when the bet goes up by a short all-in.
  final bool acted;
  final HoldemMove? lastMove;

  bool get isLive => !folded;
  bool get isAllIn => !folded && stack == 0;

  HoldemSeat copyWith({
    int? stack,
    int? committed,
    int? streetBet,
    bool? folded,
    bool? acted,
    HoldemMove? lastMove,
    bool clearMove = false,
  }) {
    return HoldemSeat(
      stack: stack ?? this.stack,
      hole: hole,
      committed: committed ?? this.committed,
      streetBet: streetBet ?? this.streetBet,
      folded: folded ?? this.folded,
      acted: acted ?? this.acted,
      lastMove: clearMove ? null : (lastMove ?? this.lastMove),
    );
  }
}

/// A main or side pot at the end of a hand.
class HoldemPot {
  const HoldemPot({
    required this.amount,
    required this.eligible,
    required this.winners,
  });

  final int amount;

  /// Seats still in the hand that put in enough to win this pot.
  final List<int> eligible;
  final List<int> winners;
}

/// One hand of no-limit Texas Hold'em as an immutable value. Transitions
/// return a new instance and throw [StateError] when illegal; check the
/// matching `can…` getters first.
///
/// Seat 0 is the human player; the others are computer opponents, who play
/// by exactly the same rules. Cards come off the front of [deck] in order
/// (it is shuffled once, before the deal), so a saved hand always deals
/// exactly the cards it would have dealt.
///
/// Rules: the seat after the button posts the small blind and the next the
/// big blind (heads-up, the button posts the small blind and acts first
/// before the flop). A bet or raise must be at least the big blind and at
/// least the previous raise, except an all-in; an all-in short of a full
/// raise doesn't reopen the betting to seats that have already acted.
/// Unmatched chips go back to their owner; side pots are formed for players
/// all-in for less, and split pots give odd chips to the first winner left
/// of the button.
class HoldemHand {
  const HoldemHand._({
    required this.seats,
    required this.deck,
    required this.board,
    required this.street,
    required this.button,
    required this.toAct,
    required this.currentBet,
    required this.minRaise,
    required this.smallBlind,
    required this.bigBlind,
    required this.lastActor,
    required this.lastAggressor,
    this.pots = const [],
    this.winnings = const [],
    this.showdown = false,
  });

  /// Deals a new hand: posts the blinds and two cards to each seat.
  /// Every seat must have chips.
  factory HoldemHand.deal({
    required List<int> stacks,
    required int button,
    required List<PlayingCard> deck,
    required int smallBlind,
    required int bigBlind,
  }) {
    final n = stacks.length;
    if (n < 2 || stacks.any((s) => s <= 0)) {
      throw ArgumentError('Needs two or more seats with chips');
    }
    if (button < 0 || button >= n) throw RangeError.index(button, stacks);
    if (deck.length < 2 * n + 5) throw ArgumentError('Deck too small');

    // Cards go round one at a time, starting left of the button.
    final cards = deck.map((c) => c.copyWith(faceUp: false)).toList();
    final holes = List.generate(n, (_) => <PlayingCard>[]);
    var next = 0;
    for (var round = 0; round < 2; round++) {
      for (var i = 1; i <= n; i++) {
        holes[(button + i) % n].add(cards[next++]);
      }
    }
    final seats = [
      for (var i = 0; i < n; i++)
        HoldemSeat(stack: stacks[i], hole: List.unmodifiable(holes[i])),
    ];
    final sb = n == 2 ? button : (button + 1) % n;
    final bb = (sb + 1) % n;
    HoldemSeat post(HoldemSeat seat, int blind, HoldemMove move) {
      final amount = min(blind, seat.stack);
      return seat.copyWith(
        stack: seat.stack - amount,
        committed: amount,
        streetBet: amount,
        lastMove: amount == seat.stack ? HoldemMove.allIn : move,
      );
    }

    seats[sb] = post(seats[sb], smallBlind, HoldemMove.smallBlind);
    seats[bb] = post(seats[bb], bigBlind, HoldemMove.bigBlind);

    final hand = HoldemHand._(
      seats: List.unmodifiable(seats),
      deck: List.unmodifiable(cards.sublist(next)),
      board: const [],
      street: HoldemStreet.preflop,
      button: button,
      toAct: -1,
      currentBet: bigBlind,
      minRaise: bigBlind,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      lastActor: bb,
      lastAggressor: -1,
    );
    final first = hand._nextToAct(bb);
    return first == null ? hand._endStreet() : hand._with(toAct: first);
  }

  final List<HoldemSeat> seats;

  /// The undealt cards, in dealing order.
  final List<PlayingCard> deck;

  /// The community cards, face up.
  final List<PlayingCard> board;
  final HoldemStreet street;

  /// The dealer button's seat.
  final int button;

  /// The seat to act, or -1 when nobody is (the hand is complete).
  final int toAct;

  /// The bet to match this round.
  final int currentBet;

  /// The smallest raise allowed: the last full raise, at least the big blind.
  final int minRaise;
  final int smallBlind;
  final int bigBlind;

  /// The seat that acted last (or posted the big blind), -1 for none.
  final int lastActor;

  /// The seat that made the last bet or raise, -1 when nobody has this hand.
  final int lastAggressor;

  /// Once complete: the pots, main pot first.
  final List<HoldemPot> pots;

  /// Once complete: what each seat collects (pots and returned chips).
  final List<int> winnings;

  /// The hand was decided by comparing cards, not by everyone else folding.
  final bool showdown;

  bool get isComplete => street == HoldemStreet.complete;
  bool get isInPlay => !isComplete;

  int get seatCount => seats.length;

  /// Every chip bet this hand.
  int get pot => seats.fold(0, (sum, s) => sum + s.committed);

  int get liveCount => seats.where((s) => s.isLive).length;

  HoldemSeat? get actingSeat => toAct < 0 ? null : seats[toAct];

  /// What [seat] must add to stay in (capped at its stack).
  int toCallFor(int seat) {
    final s = seats[seat];
    return min(max(0, currentBet - s.streetBet), s.stack);
  }

  int get toCall => toAct < 0 ? 0 : toCallFor(toAct);

  bool get canCheck => toAct >= 0 && currentBet <= seats[toAct].streetBet;
  bool get canCall => toAct >= 0 && !canCheck;

  /// Folding is only offered when there is something to call.
  bool get canFold => canCall;

  /// A bet or raise is possible: the seat hasn't acted at this level, has
  /// chips beyond the call, and someone else is left who could answer it.
  bool get canRaise {
    if (toAct < 0) return false;
    final s = seats[toAct];
    if (s.acted) return false;
    if (s.stack <= currentBet - s.streetBet) return false;
    for (var i = 0; i < seats.length; i++) {
      if (i != toAct && seats[i].isLive && seats[i].stack > 0) return true;
    }
    return false;
  }

  /// The smallest legal total for a bet or raise (an all-in may be less).
  int get minRaiseTo {
    if (toAct < 0) return 0;
    return min(currentBet + minRaise, maxRaiseTo);
  }

  /// All-in: the seat's bet this round plus everything behind.
  int get maxRaiseTo {
    if (toAct < 0) return 0;
    final s = seats[toAct];
    return s.streetBet + s.stack;
  }

  bool isLegal(HoldemDecision decision) {
    return switch (decision.kind) {
      HoldemDecisionKind.fold => canFold,
      HoldemDecisionKind.checkOrCall => toAct >= 0,
      HoldemDecisionKind.raiseTo =>
        canRaise &&
            decision.amount >= minRaiseTo &&
            decision.amount <= maxRaiseTo,
    };
  }

  // ── Transitions ────────────────────────────────────────────────────────────

  /// The seat to act makes [decision].
  HoldemHand act(HoldemDecision decision) {
    if (!isLegal(decision)) {
      throw StateError('Illegal $decision for seat $toAct');
    }
    final i = toAct;
    final s = seats[i];
    final next = List.of(seats);
    var bet = currentBet;
    var raise = minRaise;
    var aggressor = lastAggressor;
    switch (decision.kind) {
      case HoldemDecisionKind.fold:
        next[i] = s.copyWith(
          folded: true,
          acted: true,
          lastMove: HoldemMove.fold,
        );
      case HoldemDecisionKind.checkOrCall:
        final put = toCallFor(i);
        next[i] = s.copyWith(
          stack: s.stack - put,
          committed: s.committed + put,
          streetBet: s.streetBet + put,
          acted: true,
          lastMove: put == 0
              ? HoldemMove.check
              : (put == s.stack ? HoldemMove.allIn : HoldemMove.call),
        );
      case HoldemDecisionKind.raiseTo:
        final total = decision.amount;
        final put = total - s.streetBet;
        final opening = currentBet == 0;
        next[i] = s.copyWith(
          stack: s.stack - put,
          committed: s.committed + put,
          streetBet: total,
          acted: true,
          lastMove: put == s.stack
              ? HoldemMove.allIn
              : (opening ? HoldemMove.bet : HoldemMove.raise),
        );
        if (total - currentBet >= minRaise) {
          // A full raise reopens the betting to everyone.
          raise = total - currentBet;
          for (var j = 0; j < next.length; j++) {
            if (j != i && next[j].isLive && next[j].stack > 0) {
              next[j] = next[j].copyWith(acted: false);
            }
          }
        }
        bet = max(bet, total);
        aggressor = i;
    }
    final hand = _with(
      seats: next,
      currentBet: bet,
      minRaise: raise,
      lastActor: i,
      lastAggressor: aggressor,
    );
    if (hand.liveCount == 1) return hand._finish();
    final after = hand._nextToAct(i);
    return after == null ? hand._endStreet() : hand._with(toAct: after);
  }

  bool _needsToAct(int i) {
    final s = seats[i];
    if (!s.isLive || s.stack == 0) return false;
    final behind = s.streetBet < currentBet;
    if (!behind) {
      // Nobody else could answer a raise: nothing left to decide.
      var others = 0;
      for (var j = 0; j < seats.length; j++) {
        if (j != i && seats[j].isLive && seats[j].stack > 0) others++;
      }
      if (others == 0) return false;
    }
    return !s.acted || behind;
  }

  int? _nextToAct(int from) {
    for (var k = 1; k <= seats.length; k++) {
      final i = (from + k) % seats.length;
      if (_needsToAct(i)) return i;
    }
    return null;
  }

  /// Closes a betting round: deals the next street (running the board out
  /// when nobody can bet any more) or goes to the showdown.
  HoldemHand _endStreet() {
    var hand = this;
    while (true) {
      if (hand.street == HoldemStreet.river) return hand._finish();
      final count = hand.street == HoldemStreet.preflop ? 3 : 1;
      final dealt = [
        for (final c in hand.deck.take(count)) c.copyWith(faceUp: true),
      ];
      hand = hand._with(
        seats: [
          for (final s in hand.seats)
            s.copyWith(streetBet: 0, acted: false, clearMove: !s.folded),
        ],
        deck: hand.deck.sublist(count),
        board: [...hand.board, ...dealt],
        street: HoldemStreet.values[hand.street.index + 1],
        currentBet: 0,
        minRaise: bigBlind,
        toAct: -1,
      );
      final first = hand._nextToAct(hand.button);
      if (first != null) return hand._with(toAct: first);
    }
  }

  /// Settles the pots: returns unmatched chips, builds side pots and awards
  /// each to the best hand among the seats eligible for it.
  HoldemHand _finish() {
    final n = seats.length;
    final winnings = List<int>.filled(n, 0);
    final contrib = [for (final s in seats) s.committed];

    // Chips nobody matched go straight back.
    var top = 0;
    for (var i = 1; i < n; i++) {
      if (contrib[i] > contrib[top]) top = i;
    }
    var second = 0;
    for (var i = 0; i < n; i++) {
      if (i != top) second = max(second, contrib[i]);
    }
    if (contrib[top] > second) {
      winnings[top] += contrib[top] - second;
      contrib[top] = second;
    }

    final live = [
      for (var i = 0; i < n; i++)
        if (seats[i].isLive) i,
    ];
    final showdown = live.length > 1;
    final scores = <int, int>{
      if (showdown)
        for (final i in live) i: holdemScoreCards([...seats[i].hole, ...board]),
    };

    final levels = {
      for (final i in live) contrib[i],
    }.where((l) => l > 0).toList()..sort();
    final pots = <HoldemPot>[];
    var previous = 0;
    var potted = 0;
    for (final level in levels) {
      var amount = 0;
      for (final c in contrib) {
        amount += max(0, min(c, level) - previous);
      }
      previous = level;
      potted += amount;
      final eligible = [
        for (final i in live)
          if (contrib[i] >= level) i,
      ];
      pots.add(HoldemPot(amount: amount, eligible: eligible, winners: []));
    }
    final total = contrib.fold(0, (a, b) => a + b);
    if (pots.isEmpty && total > 0) {
      pots.add(HoldemPot(amount: total, eligible: live, winners: const []));
      potted = total;
    }
    if (total > potted) {
      // Chips from folded seats above every live seat's level (can't happen
      // after the return above, but never lose a chip).
      final last = pots.removeLast();
      pots.add(
        HoldemPot(
          amount: last.amount + total - potted,
          eligible: last.eligible,
          winners: last.winners,
        ),
      );
    }

    // Odd chips go to winners in order from the button's left.
    int order(int seat) => (seat - button - 1 + n) % n;
    final settled = <HoldemPot>[];
    for (final pot in pots) {
      final List<int> winners;
      if (pot.eligible.length == 1) {
        winners = pot.eligible;
      } else {
        final best = pot.eligible.map((i) => scores[i]!).reduce(max);
        winners = [
          for (final i in pot.eligible)
            if (scores[i] == best) i,
        ]..sort((a, b) => order(a).compareTo(order(b)));
      }
      final share = pot.amount ~/ winners.length;
      var odd = pot.amount - share * winners.length;
      for (final w in winners) {
        winnings[w] += share + (odd > 0 ? 1 : 0);
        if (odd > 0) odd--;
      }
      settled.add(
        HoldemPot(
          amount: pot.amount,
          eligible: List.unmodifiable(pot.eligible),
          winners: List.unmodifiable(winners),
        ),
      );
    }

    return HoldemHand._(
      seats: List.unmodifiable([
        for (var i = 0; i < n; i++)
          seats[i].copyWith(stack: seats[i].stack + winnings[i]),
      ]),
      deck: deck,
      board: board,
      street: HoldemStreet.complete,
      button: button,
      toAct: -1,
      currentBet: currentBet,
      minRaise: minRaise,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      lastActor: lastActor,
      lastAggressor: lastAggressor,
      pots: List.unmodifiable(settled),
      winnings: List.unmodifiable(winnings),
      showdown: showdown,
    );
  }

  HoldemHand _with({
    List<HoldemSeat>? seats,
    List<PlayingCard>? deck,
    List<PlayingCard>? board,
    HoldemStreet? street,
    int? toAct,
    int? currentBet,
    int? minRaise,
    int? lastActor,
    int? lastAggressor,
  }) {
    return HoldemHand._(
      seats: seats == null ? this.seats : List.unmodifiable(seats),
      deck: deck == null ? this.deck : List.unmodifiable(deck),
      board: board == null ? this.board : List.unmodifiable(board),
      street: street ?? this.street,
      button: button,
      toAct: toAct ?? this.toAct,
      currentBet: currentBet ?? this.currentBet,
      minRaise: minRaise ?? this.minRaise,
      smallBlind: smallBlind,
      bigBlind: bigBlind,
      lastActor: lastActor ?? this.lastActor,
      lastAggressor: lastAggressor ?? this.lastAggressor,
    );
  }

  // ── Results ────────────────────────────────────────────────────────────────

  /// [seat]'s best hand with the board, for a seat still in at the end.
  int scoreOf(int seat) => holdemScoreCards([...seats[seat].hole, ...board]);

  /// Seats whose hole cards are shown: everyone still in at a showdown.
  bool isRevealed(int seat) => isComplete && showdown && seats[seat].isLive;

  // ── Persistence ────────────────────────────────────────────────────────────

  static const int schemaVersion = 1;

  /// Only a hand in play is saved: its chips are already in the pot.
  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'seats': [
      for (final s in seats)
        {
          'stack': s.stack,
          'hole': encodeCardPile(s.hole),
          'committed': s.committed,
          'streetBet': s.streetBet,
          'folded': s.folded,
          'acted': s.acted,
          'move': s.lastMove?.name,
        },
    ],
    'deck': encodeCardPile(deck),
    'board': encodeCardPile(board),
    'street': street.name,
    'button': button,
    'toAct': toAct,
    'currentBet': currentBet,
    'minRaise': minRaise,
    'smallBlind': smallBlind,
    'bigBlind': bigBlind,
    'lastActor': lastActor,
    'lastAggressor': lastAggressor,
  };

  /// Restores a hand saved in play. Returns null for anything malformed,
  /// inconsistent or finished, never throwing.
  static HoldemHand? fromJson(Map<String, dynamic> json) {
    try {
      if (json['version'] != schemaVersion) return null;
      final street = HoldemStreet.values
          .where((s) => s.name == json['street'])
          .firstOrNull;
      final rawSeats = json['seats'];
      final ints = [
        for (final key in const [
          'button',
          'toAct',
          'currentBet',
          'minRaise',
          'smallBlind',
          'bigBlind',
          'lastActor',
          'lastAggressor',
        ])
          json[key],
      ];
      final rawDeck = json['deck'];
      final rawBoard = json['board'];
      if (street == null ||
          street == HoldemStreet.complete ||
          rawSeats is! List ||
          rawSeats.length < 2 ||
          rawSeats.length > 6 ||
          ints.any((v) => v is! int) ||
          rawDeck is! String ||
          rawBoard is! String) {
        return null;
      }
      final [
        button as int,
        toAct as int,
        currentBet as int,
        minRaise as int,
        smallBlind as int,
        bigBlind as int,
        lastActor as int,
        lastAggressor as int,
      ] = ints;
      final n = rawSeats.length;
      final seats = <HoldemSeat>[];
      for (final raw in rawSeats) {
        if (raw is! Map) return null;
        final stack = raw['stack'];
        final hole = raw['hole'];
        final committed = raw['committed'];
        final streetBet = raw['streetBet'];
        final folded = raw['folded'];
        final acted = raw['acted'];
        final move = raw['move'];
        if (stack is! int ||
            stack < 0 ||
            hole is! String ||
            committed is! int ||
            streetBet is! int ||
            streetBet < 0 ||
            committed < streetBet ||
            folded is! bool ||
            acted is! bool ||
            (move != null && move is! String)) {
          return null;
        }
        final cards = decodeCardPile(hole);
        if (cards.length != 2) return null;
        seats.add(
          HoldemSeat(
            stack: stack,
            hole: List.unmodifiable([
              for (final c in cards) c.copyWith(faceUp: false),
            ]),
            committed: committed,
            streetBet: streetBet,
            folded: folded,
            acted: acted,
            lastMove: move == null
                ? null
                : HoldemMove.values.firstWhere((m) => m.name == move),
          ),
        );
      }
      final deck = [
        for (final c in decodeCardPile(rawDeck)) c.copyWith(faceUp: false),
      ];
      final board = [
        for (final c in decodeCardPile(rawBoard)) c.copyWith(faceUp: true),
      ];
      const boardSizes = {
        HoldemStreet.preflop: 0,
        HoldemStreet.flop: 3,
        HoldemStreet.turn: 4,
        HoldemStreet.river: 5,
      };
      final all = [...deck, ...board, for (final s in seats) ...s.hole];
      if (board.length != boardSizes[street] ||
          all.length != 52 ||
          all.map((c) => c.id).toSet().length != 52 ||
          all.any((c) => c.isJoker) ||
          button < 0 ||
          button >= n ||
          toAct < 0 ||
          toAct >= n ||
          lastActor < -1 ||
          lastActor >= n ||
          lastAggressor < -1 ||
          lastAggressor >= n ||
          smallBlind <= 0 ||
          bigBlind < smallBlind ||
          minRaise < bigBlind ||
          currentBet < seats.map((s) => s.streetBet).reduce(max) ||
          seats.where((s) => s.isLive).length < 2) {
        return null;
      }
      final hand = HoldemHand._(
        seats: List.unmodifiable(seats),
        deck: List.unmodifiable(deck),
        board: List.unmodifiable(board),
        street: street,
        button: button,
        toAct: toAct,
        currentBet: currentBet,
        minRaise: minRaise,
        smallBlind: smallBlind,
        bigBlind: bigBlind,
        lastActor: lastActor,
        lastAggressor: lastAggressor,
      );
      return hand._needsToAct(toAct) ? hand : null;
    } on FormatException {
      return null;
    } on StateError {
      return null;
    }
  }
}

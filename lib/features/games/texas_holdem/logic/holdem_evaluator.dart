import 'dart:math';

import '../../../../core/cards/playing_card.dart';

/// Poker hand categories, weakest first, so `index` orders them.
enum HoldemHandCategory {
  highCard('High Card'),
  pair('Pair'),
  twoPair('Two Pair'),
  threeOfAKind('Three of a Kind'),
  straight('Straight'),
  flush('Flush'),
  fullHouse('Full House'),
  fourOfAKind('Four of a Kind'),
  straightFlush('Straight Flush');

  const HoldemHandCategory(this.label);

  final String label;
}

/// Compact card codes for fast evaluation (the AI scores thousands of hands
/// per decision): `rank * 4 + suit.index`, with poker ranks 2..14 (ace high).
int holdemCardCode(PlayingCard card) =>
    (card.isAce ? 14 : card.rank.value) * 4 + card.suit.index;

/// Scores the best five-card poker hand in 5 to 7 [codes]; a higher score
/// beats a lower one and equal scores tie. The category sits in bits 20+,
/// then up to five deciding ranks, four bits each, most significant first.
int holdemScore(List<int> codes) {
  final counts = List<int>.filled(15, 0);
  final suitMasks = List<int>.filled(4, 0);
  final suitCounts = List<int>.filled(4, 0);
  var rankMask = 0;
  for (final code in codes) {
    final rank = code >> 2;
    final suit = code & 3;
    counts[rank]++;
    suitMasks[suit] |= 1 << rank;
    suitCounts[suit]++;
    rankMask |= 1 << rank;
  }

  // Seven cards can't hold a flush and a full house or quads together, so a
  // flush is the answer unless it is also a straight.
  for (var suit = 0; suit < 4; suit++) {
    if (suitCounts[suit] < 5) continue;
    final straightFlush = _straightHigh(suitMasks[suit]);
    if (straightFlush > 0) {
      return _pack(HoldemHandCategory.straightFlush, [straightFlush]);
    }
    return _pack(HoldemHandCategory.flush, _topRanks(suitMasks[suit], 5));
  }

  var quad = 0;
  final trips = <int>[];
  final pairs = <int>[];
  final singles = <int>[];
  for (var rank = 14; rank >= 2; rank--) {
    switch (counts[rank]) {
      case 4:
        quad = rank;
      case 3:
        trips.add(rank);
      case 2:
        pairs.add(rank);
      case 1:
        singles.add(rank);
    }
  }

  if (quad > 0) {
    final kicker = _topRanks(rankMask & ~(1 << quad), 1);
    return _pack(HoldemHandCategory.fourOfAKind, [quad, ...kicker]);
  }
  if (trips.isNotEmpty && (trips.length > 1 || pairs.isNotEmpty)) {
    final pair = max(
      trips.length > 1 ? trips[1] : 0,
      pairs.isNotEmpty ? pairs[0] : 0,
    );
    return _pack(HoldemHandCategory.fullHouse, [trips[0], pair]);
  }
  final straight = _straightHigh(rankMask);
  if (straight > 0) return _pack(HoldemHandCategory.straight, [straight]);
  if (trips.isNotEmpty) {
    return _pack(HoldemHandCategory.threeOfAKind, [
      trips[0],
      ...singles.take(2),
    ]);
  }
  if (pairs.length >= 2) {
    // A third pair can still be the kicker.
    final kicker = max(
      pairs.length > 2 ? pairs[2] : 0,
      singles.isNotEmpty ? singles[0] : 0,
    );
    return _pack(HoldemHandCategory.twoPair, [pairs[0], pairs[1], kicker]);
  }
  if (pairs.length == 1) {
    return _pack(HoldemHandCategory.pair, [pairs[0], ...singles.take(3)]);
  }
  return _pack(HoldemHandCategory.highCard, singles.take(5).toList());
}

/// [holdemScore] for playing cards.
int holdemScoreCards(Iterable<PlayingCard> cards) =>
    holdemScore([for (final c in cards) holdemCardCode(c)]);

HoldemHandCategory holdemCategoryOf(int score) =>
    HoldemHandCategory.values[score >> 20];

/// The highest card of the best straight in [mask] (bit n = rank n), or 0.
/// The ace also plays low, in A-2-3-4-5.
int _straightHigh(int mask) {
  final m = (mask & (1 << 14)) != 0 ? mask | (1 << 1) : mask;
  for (var high = 14; high >= 5; high--) {
    final window = 0x1F << (high - 4);
    if (m & window == window) return high;
  }
  return 0;
}

List<int> _topRanks(int mask, int count) {
  final ranks = <int>[];
  for (var rank = 14; rank >= 2 && ranks.length < count; rank--) {
    if (mask & (1 << rank) != 0) ranks.add(rank);
  }
  return ranks;
}

int _pack(HoldemHandCategory category, List<int> ranks) {
  var score = category.index << 20;
  for (var i = 0; i < ranks.length && i < 5; i++) {
    score |= ranks[i] << (16 - 4 * i);
  }
  return score;
}

int _rankAt(int score, int i) => (score >> (16 - 4 * i)) & 0xF;

String _rankName(int rank, {bool plural = false}) {
  const names = {
    2: 'Two',
    3: 'Three',
    4: 'Four',
    5: 'Five',
    6: 'Six',
    7: 'Seven',
    8: 'Eight',
    9: 'Nine',
    10: 'Ten',
    11: 'Jack',
    12: 'Queen',
    13: 'King',
    14: 'Ace',
  };
  final name = names[rank]!;
  if (!plural) return name;
  return rank == 6 ? 'Sixes' : '${name}s';
}

/// A readable name for a [holdemScore], e.g. "Two Pair, Kings and Sevens".
String holdemHandName(int score) {
  final category = holdemCategoryOf(score);
  final first = _rankAt(score, 0);
  final second = _rankAt(score, 1);
  return switch (category) {
    HoldemHandCategory.highCard => '${_rankName(first)} High',
    HoldemHandCategory.pair => 'Pair of ${_rankName(first, plural: true)}',
    HoldemHandCategory.twoPair =>
      'Two Pair, ${_rankName(first, plural: true)} and '
          '${_rankName(second, plural: true)}',
    HoldemHandCategory.threeOfAKind =>
      'Three ${_rankName(first, plural: true)}',
    HoldemHandCategory.straight => 'Straight, ${_rankName(first)} High',
    HoldemHandCategory.flush => 'Flush, ${_rankName(first)} High',
    HoldemHandCategory.fullHouse =>
      'Full House, ${_rankName(first, plural: true)} over '
          '${_rankName(second, plural: true)}',
    HoldemHandCategory.fourOfAKind => 'Four ${_rankName(first, plural: true)}',
    HoldemHandCategory.straightFlush =>
      first == 14 ? 'Royal Flush' : 'Straight Flush, ${_rankName(first)} High',
  };
}

/// The five of [cards] (5 to 7) that make their best hand, for highlighting.
List<PlayingCard> holdemBestFive(List<PlayingCard> cards) {
  if (cards.length <= 5) return List.of(cards);
  final codes = [for (final c in cards) holdemCardCode(c)];
  var best = -1;
  var bestPick = const <int>[];
  void search(List<int> pick, int from) {
    if (pick.length == 5) {
      final score = holdemScore([for (final i in pick) codes[i]]);
      if (score > best) {
        best = score;
        bestPick = List.of(pick);
      }
      return;
    }
    for (var i = from; i < cards.length; i++) {
      search([...pick, i], i + 1);
    }
  }

  search(const [], 0);
  return [for (final i in bestPick) cards[i]];
}

/// Estimates how often [hole] wins (ties shared) against [opponents] random
/// hands, with the rest of the board dealt at random, over [iterations]
/// deals. Only the cards passed in are known; nothing else about the real
/// deck is used.
double holdemEquity({
  required List<PlayingCard> hole,
  required List<PlayingCard> board,
  required int opponents,
  required int iterations,
  required Random random,
}) {
  final heroCodes = [for (final c in hole) holdemCardCode(c)];
  final boardCodes = [for (final c in board) holdemCardCode(c)];
  final known = {...heroCodes, ...boardCodes};
  final deck = [
    for (var rank = 2; rank <= 14; rank++)
      for (var suit = 0; suit < 4; suit++)
        if (!known.contains(rank * 4 + suit)) rank * 4 + suit,
  ];
  final missing = 5 - boardCodes.length;
  final needed = missing + 2 * opponents;
  if (opponents < 1 || needed > deck.length) return 1;

  final hand = List<int>.filled(7, 0);
  var total = 0.0;
  for (var it = 0; it < iterations; it++) {
    // A partial Fisher-Yates shuffle draws just the cards needed.
    for (var i = 0; i < needed; i++) {
      final j = i + random.nextInt(deck.length - i);
      final t = deck[i];
      deck[i] = deck[j];
      deck[j] = t;
    }
    final fullBoard = [
      ...boardCodes,
      for (var i = 0; i < missing; i++) deck[i],
    ];
    for (var i = 0; i < 5; i++) {
      hand[i] = fullBoard[i];
    }
    hand[5] = heroCodes[0];
    hand[6] = heroCodes[1];
    final hero = holdemScore(hand);
    var bestOther = -1;
    var ties = 0;
    for (var o = 0; o < opponents; o++) {
      hand[5] = deck[missing + 2 * o];
      hand[6] = deck[missing + 2 * o + 1];
      final score = holdemScore(hand);
      if (score > bestOther) {
        bestOther = score;
        ties = score == hero ? 1 : 0;
      } else if (score == bestOther && score == hero) {
        ties++;
      }
    }
    if (hero > bestOther) {
      total += 1;
    } else if (hero == bestOther) {
      total += 1 / (ties + 1);
    }
  }
  return total / iterations;
}

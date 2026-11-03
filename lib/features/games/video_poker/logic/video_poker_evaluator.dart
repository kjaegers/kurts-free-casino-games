import '../../../../core/cards/playing_card.dart';
import 'video_poker_variant.dart';

/// Compact card codes for fast evaluation (the return checker scores
/// millions of hands): `rankIndex * 4 + suit.index`, where rankIndex 0 is a
/// Two and 12 an Ace, and [videoPokerJokerCode] for a joker.
const int videoPokerJokerCode = 52;

int videoPokerCardCode(PlayingCard card) {
  if (card.isJoker) return videoPokerJokerCode;
  final rankIndex = card.isAce ? 12 : card.rank.value - 2;
  return rankIndex * 4 + card.suit.index;
}

/// The best paying hand [cards] make under [variant]'s rules, or null when
/// it pays nothing.
VideoPokerHand? evaluateVideoPokerHand(
  List<PlayingCard> cards,
  VideoPokerVariant variant,
) {
  if (cards.length != 5) {
    throw ArgumentError.value(cards.length, 'cards', 'must be five cards');
  }
  return evaluateVideoPokerCodes([
    for (final card in cards) videoPokerCardCode(card),
  ], variant);
}

/// [evaluateVideoPokerHand] for five card codes ([videoPokerCardCode]).
///
/// Wild cards stand in for whatever card makes the best hand. The variant's
/// paytable is checked from the top, so the first category the cards can
/// form is the one that pays most.
VideoPokerHand? evaluateVideoPokerCodes(
  List<int> codes,
  VideoPokerVariant variant,
) {
  final shape = _HandShape(codes, variant.deucesAreWild);
  for (final line in variant.paytable) {
    if (shape.canMake(line.hand, variant.highPairMinRank)) return line.hand;
  }
  return null;
}

/// What the natural (non-wild) cards of a hand look like.
class _HandShape {
  _HandShape(List<int> codes, bool deucesWild) {
    for (final code in codes) {
      if (code == videoPokerJokerCode || (deucesWild && code < 4)) {
        wilds++;
        continue;
      }
      // Poker ranks run 2..14 with the ace high.
      final rank = code ~/ 4 + 2;
      counts[rank]++;
      suitMask |= 1 << (code % 4);
      rankMask |= 1 << rank;
    }
    for (var rank = 2; rank <= 14; rank++) {
      final count = counts[rank];
      if (count == 0) continue;
      distinct++;
      if (count >= 2) pairs++;
      if (count > maxCount) maxCount = count;
    }
  }

  final List<int> counts = List<int>.filled(15, 0);
  int wilds = 0;
  int suitMask = 0;
  int rankMask = 0;
  int distinct = 0;
  int pairs = 0;
  int maxCount = 0;

  int get naturals => 5 - wilds;

  bool get _flush => suitMask & (suitMask - 1) == 0;

  /// Distinct natural ranks that fit inside five consecutive ranks, the
  /// wilds filling the gaps. The ace plays high (10-A) or low (A-5).
  bool get _straight {
    if (distinct != naturals) return false;
    final aceLowMask = (rankMask & (1 << 14)) != 0
        ? (rankMask & ~(1 << 14)) | (1 << 1)
        : rankMask;
    for (var low = 1; low <= 10; low++) {
      final window = 0x1F << low;
      if (rankMask & ~window == 0 || aceLowMask & ~window == 0) return true;
    }
    return false;
  }

  /// Every natural card is a 10, J, Q, K or A of one suit, no two alike.
  bool get _royalShape =>
      _flush && distinct == naturals && rankMask & ~(0x1F << 10) == 0;

  bool canMake(VideoPokerHand hand, int? highPairMinRank) {
    return switch (hand) {
      VideoPokerHand.royalFlush => wilds == 0 && _royalShape,
      VideoPokerHand.fourDeuces => wilds == 4,
      VideoPokerHand.wildRoyal => wilds > 0 && _royalShape,
      VideoPokerHand.fiveOfAKind => maxCount + wilds >= 5,
      VideoPokerHand.straightFlush => _flush && _straight,
      VideoPokerHand.fourOfAKind => maxCount + wilds >= 4,
      // Two natural ranks at most, neither needing more than three cards.
      VideoPokerHand.fullHouse => distinct <= 2 && maxCount <= 3,
      VideoPokerHand.flush => _flush,
      VideoPokerHand.straight => _straight,
      VideoPokerHand.threeOfAKind => maxCount + wilds >= 3,
      VideoPokerHand.twoPair => pairs + wilds >= 2,
      VideoPokerHand.highPair => _hasHighPair(highPairMinRank),
    };
  }

  bool _hasHighPair(int? minRank) {
    if (minRank == null) return false;
    for (var rank = minRank; rank <= 14; rank++) {
      if (counts[rank] > 0 && counts[rank] + wilds >= 2) return true;
    }
    return wilds >= 2;
  }
}

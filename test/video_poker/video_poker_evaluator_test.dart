import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_evaluator.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_variant.dart';

import '../../tools/video_poker/return_check.dart';
import 'video_poker_test_support.dart';

typedef H = VideoPokerHand;
typedef V = VideoPokerVariant;

void main() {
  VideoPokerHand? eval(String hand, V variant) =>
      evaluateVideoPokerHand(cards(hand), variant);

  void expectAll(V variant, Map<String, VideoPokerHand?> examples) {
    for (final MapEntry(key: hand, value: expected) in examples.entries) {
      test('$hand is ${expected?.label ?? 'no win'}', () {
        expect(eval(hand, variant), expected);
      });
    }
  }

  group('Jacks or Better', () {
    expectAll(V.jacksOrBetter, {
      '10S JS QS KS AS': H.royalFlush,
      '9H 10H JH QH KH': H.straightFlush,
      'AD 2D 3D 4D 5D': H.straightFlush,
      '7C 7D 7H 7S 2C': H.fourOfAKind,
      'QC QD QH 4S 4C': H.fullHouse,
      '2H 7H 9H JH KH': H.flush,
      '5C 6D 7H 8S 9C': H.straight,
      'AC 2D 3H 4S 5C': H.straight,
      '10C JD QH KS AC': H.straight,
      '3C 3D 3H KS 9C': H.threeOfAKind,
      '3C 3D 9H 9S KC': H.twoPair,
      'JC JD 2H 5S 9C': H.highPair,
      'AC AD 2H 5S 9C': H.highPair,
      '10C 10D 2H 5S 9C': null,
      'QC KD AH 2S 3C': null,
      'JC QD KH AS 2C': null,
      '8C 8D 2H 5S KC': null,
    });
  });

  group('Joker Poker', () {
    expectAll(V.jokerPoker, {
      '10S JS QS KS AS': H.royalFlush,
      '10S JS QS KS JK': H.wildRoyal,
      '9S 9D 9H 9C JK': H.fiveOfAKind,
      '5H 6H 8H 9H JK': H.straightFlush,
      '8C 8D 8H 2S JK': H.fourOfAKind,
      '8C 8D 4H 4S JK': H.fullHouse,
      '2H 7H 9H JH JK': H.flush,
      '5C 6D 8H 9S JK': H.straight,
      'AC 2D 3H 4S JK': H.straight,
      '8C 8D 2H 5S JK': H.threeOfAKind,
      '8C 8D 2H 2S KC': H.twoPair,
      'KC KD 5H 5S 3C': H.twoPair,
      'KC 2D 5H 9S JK': H.highPair,
      'AC 2D 5H 9S JK': H.highPair,
      'KC KD 5H 9S 3C': H.highPair,
      'QC QD 5H 9S 3C': null,
      'QC 2D 5H 9S JK': null,
    });
  });

  group('Deuces Wild', () {
    expectAll(V.deucesWild, {
      '10S JS QS KS AS': H.royalFlush,
      '2C 2D 2H 2S 9C': H.fourDeuces,
      '10S JS QS KS 2D': H.wildRoyal,
      '9S 9D 9H 2C 2D': H.fiveOfAKind,
      '5H 6H 2C 8H 9H': H.straightFlush,
      '8C 8D 8H 2S KC': H.fourOfAKind,
      '8C 8D 4H 4S 2C': H.fullHouse,
      '3H 7H 9H JH KH': H.flush,
      '5C 6D 2H 8S 9C': H.straight,
      'AC 2D 3H 4S 5C': H.straight,
      '8C 8D 2H 5S KC': H.threeOfAKind,
      '8C 8D 3H 3S KC': null,
      'AC AD 5H 9S 3C': null,
    });
  });

  group('payouts', () {
    test('every paytable line pays its listed coins per coin', () {
      for (final variant in V.values) {
        for (final line in variant.paytable) {
          for (var bet = 1; bet <= 5; bet++) {
            final expected = line.hand == H.royalFlush && bet == 5
                ? 4000
                : line.pays * bet;
            expect(
              variant.payout(line.hand, bet),
              expected,
              reason: '${variant.name} ${line.hand.name} x$bet',
            );
          }
        }
        expect(variant.payout(null, 5), 0);
      }
    });

    test('paytables are listed best-paying first', () {
      for (final variant in V.values) {
        final pays = variant.paytable.map((l) => l.pays).toList();
        for (var i = 1; i < pays.length; i++) {
          expect(pays[i], lessThanOrEqualTo(pays[i - 1]), reason: variant.name);
        }
      }
    });

    test('only Joker Poker uses a joker', () {
      expect(V.jokerPoker.deckSize, 53);
      expect(V.jacksOrBetter.deckSize, 52);
      expect(V.deucesWild.deckSize, 52);
    });

    test('card codes cover the deck once, with the joker last', () {
      final codes = stackedDeck(
        V.jokerPoker,
        '',
      ).map(videoPokerCardCode).toSet();
      expect(codes, {for (var i = 0; i <= 52; i++) i});
      expect(videoPokerCardCode(card('JK')), videoPokerJokerCode);
    });
  });

  // The figures in How to Play: an exhaustive perfect-play analysis of
  // every deal (a few seconds per variant).
  test('published returns match perfect play', () {
    for (final variant in V.values) {
      expect(
        (theoreticalReturn(variant) * 100).toStringAsFixed(2),
        variant.returnPercent,
        reason: variant.name,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/models/texas_holdem_stats.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_evaluator.dart';

import 'holdem_test_support.dart';

int score(String text) => holdemScoreCards(cards(text));
HoldemHandCategory category(String text) => holdemCategoryOf(score(text));

void main() {
  group('categories', () {
    for (final (hand, expected) in const [
      ('AS KD 9H 7C 4S 3D 2H', HoldemHandCategory.highCard),
      ('AS AD 9H 7C 4S 3D 2H', HoldemHandCategory.pair),
      ('AS AD 9H 9C 4S 3D 2H', HoldemHandCategory.twoPair),
      ('AS AD AH 9C 4S 3D 2H', HoldemHandCategory.threeOfAKind),
      ('6S 5D 4H 3C 2S KD KH', HoldemHandCategory.straight),
      ('AS 2D 3H 4C 5S KD KH', HoldemHandCategory.straight),
      ('AS JS 9S 4S 2S KD KH', HoldemHandCategory.flush),
      ('AS AD AH 9C 9S 3D 2H', HoldemHandCategory.fullHouse),
      ('AS AD AH 9C 9S 9D 2H', HoldemHandCategory.fullHouse),
      ('AS AD AH AC 9S 9D 9H', HoldemHandCategory.fourOfAKind),
      ('9S 8S 7S 6S 5S AD AH', HoldemHandCategory.straightFlush),
      ('AS 2S 3S 4S 5S KD KH', HoldemHandCategory.straightFlush),
    ]) {
      test('$hand is ${expected.label}', () {
        expect(category(hand), expected);
      });
    }

    test('five-card hands score too', () {
      expect(category('KS KD 4H 4C 2S'), HoldemHandCategory.twoPair);
    });
  });

  group('ordering and kickers', () {
    test('categories beat each other in order', () {
      final hands = [
        'AS KD 9H 7C 4S',
        '2S 2D 9H 7C 4S',
        '2S 2D 3H 3C 4S',
        '2S 2D 2H 7C 4S',
        'AS 2D 3H 4C 5S',
        '2S 4S 6S 8S 10S',
        '2S 2D 2H 3C 3S',
        '2S 2D 2H 2C 3S',
        'AS 2S 3S 4S 5S',
      ];
      for (var i = 1; i < hands.length; i++) {
        expect(score(hands[i]), greaterThan(score(hands[i - 1])));
      }
    });

    test('the wheel is the lowest straight', () {
      expect(score('6S 5D 4H 3C 2S'), greaterThan(score('AS 2D 3H 4C 5S')));
      expect(score('AS KD QH JC 10S'), greaterThan(score('KS QD JH 10C 9S')));
    });

    test('kickers decide pairs, and only the best five count', () {
      expect(
        score('AS AD KH 7C 4S 3D 2H'),
        greaterThan(score('AS AD QH JC 10S 3D 2H')),
      );
      // Both play A-A-K-Q-J; the sixth and seventh cards don't matter.
      expect(score('AS AD KH QC JS 3D 2H'), score('AH AC KS QD JH 9D 8C'));
    });

    test('a third pair can be the two-pair kicker', () {
      expect(score('KS KD QH QC 9S 9D 2H'), score('KS KD QH QC 9S 3D 2H'));
      expect(
        score('KS KD QH QC 9S 9D 2H'),
        greaterThan(score('KS KD QH QC 8S 3D 2H')),
      );
    });

    test('full house picks the best pair, even from a second set', () {
      expect(score('AS AD AH KC KS KD 2H'), score('AS AD AH KC KS QD 2H'));
      expect(
        score('AS AD AH KC KS QD QH'),
        greaterThan(score('AS AD AH QC QS JD JH')),
      );
    });

    test('suits never break ties', () {
      expect(score('AS KS QH JC 9S'), score('AH KH QD JS 9D'));
    });
  });

  test('hand names', () {
    expect(holdemHandName(score('AS KD 9H 7C 4S')), 'Ace High');
    expect(holdemHandName(score('6S 6D 9H 7C 4S')), 'Pair of Sixes');
    expect(
      holdemHandName(score('KS KD 7H 7C 4S')),
      'Two Pair, Kings and Sevens',
    );
    expect(holdemHandName(score('AS 2D 3H 4C 5S')), 'Straight, Five High');
    expect(
      holdemHandName(score('QS QD QH 2C 2S')),
      'Full House, Queens over Twos',
    );
    expect(holdemHandName(score('AS KS QS JS 10S')), 'Royal Flush');
    expect(
      holdemHandName(score('9S 8S 7S 6S 5S')),
      'Straight Flush, Nine High',
    );
  });

  test('best five picks the cards that make the hand', () {
    final best = holdemBestFive(cards('AS 2D KS 9S 7H 4S 3S'));
    expect(best.map((c) => c.id).toSet(), {'S01', 'S13', 'S09', 'S04', 'S03'});
  });

  test('stats labels follow the categories', () {
    expect(TexasHoldemStats.categoryLabels, [
      for (final c in HoldemHandCategory.values) c.label,
    ]);
  });

  group('equity estimate', () {
    test('aces are about 85% heads-up before the flop', () {
      final equity = holdemEquity(
        hole: cards('AS AD'),
        board: const [],
        opponents: 1,
        iterations: 4000,
        random: Random(1),
      );
      expect(equity, closeTo(0.85, 0.03));
    });

    test('the nuts on the river always wins', () {
      final equity = holdemEquity(
        hole: cards('AS KS'),
        board: cards('QS JS 10S 2D 3C'),
        opponents: 3,
        iterations: 300,
        random: Random(2),
      );
      expect(equity, 1);
    });

    test('a board that plays for everyone is a split', () {
      final equity = holdemEquity(
        hole: cards('2C 3D'),
        board: cards('AS KS QS JS 10S'),
        opponents: 1,
        iterations: 200,
        random: Random(3),
      );
      expect(equity, 0.5);
    });
  });
}

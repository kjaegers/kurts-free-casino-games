import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_achievements.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_ai.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_hand.dart';

import 'holdem_test_support.dart';

void main() {
  group('opponents', () {
    test('never use other players\' cards or the deck', () {
      // Same seat, cards and betting; only the other hands and the deck
      // differ. With the same random numbers the decision must match.
      for (var seed = 0; seed < 40; seed++) {
        final a = dealHand(
          stacks: [1000, 1000, 1000],
          holes: ['AS 2D', 'KH QH', '7C 7D'],
          board: '9S 9D 4C 10H JH',
        );
        final b = dealHand(
          stacks: [1000, 1000, 1000],
          holes: ['AS 2D', '3C 4D', '8S 6S'],
          board: '2S 3S 5H 5D KC',
        );
        for (final difficulty in HoldemDifficulty.values) {
          HoldemDecision decide(HoldemHand h) => decideHoldemAction(
            HoldemAiView.of(h),
            style: HoldemStyle.shark,
            difficulty: difficulty,
            random: Random(seed),
          );
          expect(decide(a).toString(), decide(b).toString());
        }
      }
    });

    test('raise strong hands more often than weak ones', () {
      int raises(String hole) {
        var count = 0;
        for (var seed = 0; seed < 200; seed++) {
          final h = dealHand(
            stacks: [1000, 1000, 1000],
            holes: [hole, '2C 7D', '3C 8D'],
          );
          final d = decideHoldemAction(
            HoldemAiView.of(h),
            style: HoldemStyle.shark,
            difficulty: HoldemDifficulty.normal,
            random: Random(seed),
          );
          if (d.kind == HoldemDecisionKind.raiseTo) count++;
        }
        return count;
      }

      expect(raises('AS AD'), greaterThan(raises('7S 2H') + 50));
    });

    test('fold rubbish to a big bet', () {
      var folds = 0;
      for (var seed = 0; seed < 100; seed++) {
        var h = dealHand(
          stacks: [1000, 1000],
          holes: ['AS AD', '7S 2H'],
          board: 'KC QD 9H 4S 3C',
        );
        // The button (seat 0) shoves; seat 1 holds seven high.
        h = h.act(raiseTo(1000));
        final d = decideHoldemAction(
          HoldemAiView.of(h),
          style: HoldemStyle.shark,
          difficulty: HoldemDifficulty.hard,
          random: Random(seed),
        );
        if (d.kind == HoldemDecisionKind.fold) folds++;
      }
      expect(folds, greaterThan(80));
    });
  });

  group('achievements', () {
    test('a post-flop bet with nothing that everyone folds to is a bluff', () {
      var h = dealHand(
        stacks: [1000, 1000],
        holes: ['2C 7D', 'AS AD'],
        board: 'KC QD 9H 4S 3C',
      );
      // Preflop: button calls, big blind checks. Flop: big blind checks,
      // the player bets and the aces fold.
      h = play(h, [call, call, call, raiseTo(20), fold]);
      expect(h.isComplete, isTrue);
      expect(checkHoldemAchievements(h), contains(HoldemAchievementIds.bluff));
    });

    test('a preflop steal is not a bluff', () {
      var h = dealHand(stacks: [1000, 1000], holes: ['2C 7D', 'AS AD']);
      h = play(h, [raiseTo(30), fold]);
      expect(checkHoldemAchievements(h), isEmpty);
    });

    test('winning an opponent\'s last chips is a knockout', () {
      var h = dealHand(
        stacks: [1000, 200],
        holes: ['AS AD', 'KS KD'],
        board: '3H 8S 9C JD 4H',
      );
      h = play(h, [raiseTo(1000), call]);
      expect(
        checkHoldemAchievements(h),
        contains(HoldemAchievementIds.knockout),
      );
    });

    test('quads at a showdown; nothing for a losing hand', () {
      var win = dealHand(
        stacks: [1000, 1000],
        holes: ['9S 9D', 'KS KD'],
        board: '9C 9H 2C 5D JS',
      );
      win = checkDown(win);
      expect(checkHoldemAchievements(win), {HoldemAchievementIds.quads});

      var lose = dealHand(
        stacks: [1000, 1000],
        holes: ['KS KD', '9S 9D'],
        board: '9C 9H 2C 5D JS',
      );
      lose = checkDown(lose);
      expect(checkHoldemAchievements(lose), isEmpty);
    });
  });
}

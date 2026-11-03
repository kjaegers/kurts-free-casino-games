import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_achievements.dart';
import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_bets.dart';
import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_game.dart';
import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_wheel.dart';
import 'package:kurts_free_casino_games/features/games/roulette/roulette_screen_controller.dart';

import '../../tools/roulette/return_check.dart';

RouletteBet _bet(String id) => rouletteBetById(id)!;

void main() {
  group('wheel', () {
    test('has each pocket once, 18 red and 18 black', () {
      expect(rouletteWheelOrder.toSet(), {for (var n = 0; n < 37; n++) n});
      expect(rouletteWheelOrder, hasLength(roulettePocketCount));
      final colors = [for (var n = 1; n <= 36; n++) rouletteColorOf(n)];
      expect(colors.where((c) => c == RouletteColor.red), hasLength(18));
      expect(colors.where((c) => c == RouletteColor.black), hasLength(18));
      expect(rouletteColorOf(0), RouletteColor.green);
      expect(roulettePocketLabel(17), '17 Black');
      expect(roulettePocketLabel(32), '32 Red');
    });

    test('red and black alternate around the wheel', () {
      for (var i = 1; i < roulettePocketCount - 1; i++) {
        expect(
          rouletteColorOf(rouletteWheelOrder[i]),
          isNot(rouletteColorOf(rouletteWheelOrder[i + 1])),
        );
      }
    });

    test('the fair picker lands every pocket about equally often', () {
      final pick = RouletteScreenController.fairPocketPicker(Random(11));
      final counts = List.filled(roulettePocketCount, 0);
      const spins = 370000;
      for (var i = 0; i < spins; i++) {
        counts[pick()]++;
      }
      for (final count in counts) {
        expect(count, closeTo(spins / 37, 300)); // ~5 standard deviations.
      }
    });
  });

  group('bets', () {
    test('every standard bet is on the table, once', () {
      final byKind = <RouletteBetKind, int>{};
      for (final bet in rouletteBets) {
        byKind[bet.kind] = (byKind[bet.kind] ?? 0) + 1;
      }
      expect(byKind, {
        RouletteBetKind.straight: 37,
        RouletteBetKind.split: 60,
        RouletteBetKind.street: 12,
        RouletteBetKind.trio: 2,
        RouletteBetKind.corner: 22,
        RouletteBetKind.firstFour: 1,
        RouletteBetKind.sixLine: 11,
        RouletteBetKind.column: 3,
        RouletteBetKind.dozen: 3,
        RouletteBetKind.red: 1,
        RouletteBetKind.black: 1,
        RouletteBetKind.odd: 1,
        RouletteBetKind.even: 1,
        RouletteBetKind.low: 1,
        RouletteBetKind.high: 1,
      });
      expect({for (final b in rouletteBets) b.id}, hasLength(157));
      expect(
        {for (final b in rouletteBets) b.numbers.join(',')},
        hasLength(157),
        reason: 'no two bets cover the same numbers',
      );
    });

    test('each bet covers as many numbers as its payout implies', () {
      for (final bet in rouletteBets) {
        expect(bet.numbers.length * (bet.pays + 1), 36, reason: bet.id);
      }
    });

    test('every bet returns exactly 36 for each 37 staked (97.30%)', () {
      expect(mispricedBets(), isEmpty);
    });

    test('outside bets cover the right numbers', () {
      final red = rouletteOutside(RouletteBetKind.red);
      expect(red.numbers, rouletteRedNumbers.toList()..sort());
      expect(rouletteOutside(RouletteBetKind.column).numbers.take(3), [
        1,
        4,
        7,
      ]);
      expect(rouletteOutside(RouletteBetKind.dozen, 2).numbers.first, 25);
      expect(rouletteOutside(RouletteBetKind.high).numbers.first, 19);
      for (final kind in RouletteBetKind.values.where((k) => !k.isInside)) {
        for (var i = 0; i < 3; i++) {
          if (i > 0 &&
              kind != RouletteBetKind.column &&
              kind != RouletteBetKind.dozen) {
            continue;
          }
          expect(rouletteOutside(kind, i).wins(0), isFalse, reason: '$kind');
        }
      }
    });

    test('pays to 1 with the stake back', () {
      expect(rouletteStraight(17).payoutFor(10), 360);
      expect(_bet('split:5-8').payoutFor(10), 180);
      expect(rouletteOutside(RouletteBetKind.red).payoutFor(10), 20);
      expect(_bet('firstFour:0-1-2-3').payoutFor(5), 45);
    });
  });

  group('tapping the table', () {
    test('a tap on each bet\'s spot places that bet', () {
      for (final bet in rouletteBets) {
        expect(rouletteBetAt(bet.spotU, bet.spotV), bet, reason: bet.id);
      }
    });

    test('the middle of a number bets on it; its edges on what is around', () {
      // 17 is street 5 (16-17-18), the middle column.
      expect(rouletteBetAt(5.5, 1.5), rouletteStraight(17));
      expect(rouletteBetAt(5.5, 1.1), _bet('split:16-17'));
      expect(rouletteBetAt(5.5, 1.9), _bet('split:17-18'));
      expect(rouletteBetAt(5.1, 1.5), _bet('split:14-17'));
      expect(rouletteBetAt(5.9, 1.5), _bet('split:17-20'));
      expect(rouletteBetAt(5.9, 1.9), _bet('corner:17-18-20-21'));
      expect(rouletteBetAt(5.1, 1.1), _bet('corner:13-14-16-17'));
      expect(rouletteBetAt(5.5, 0.1), _bet('street:16-17-18'));
      expect(rouletteBetAt(5.9, 0.1), _bet('sixLine:16-17-18-19-20-21'));
      // The far edge of the 3-6-9 column is just the number.
      expect(rouletteBetAt(5.5, 2.95), rouletteStraight(18));
      // The last row's outer edge doesn't split into the column bets.
      expect(rouletteBetAt(11.95, 1.5), rouletteStraight(35));
    });

    test('along 0: splits, trios and the first four', () {
      expect(rouletteBetAt(-0.5, 0.2), rouletteStraight(0));
      expect(rouletteBetAt(-0.1, 0.5), _bet('split:0-1'));
      expect(rouletteBetAt(0.1, 2.5), _bet('split:0-3'));
      expect(rouletteBetAt(0.05, 1.05), _bet('trio:0-1-2'));
      expect(rouletteBetAt(-0.05, 1.95), _bet('trio:0-2-3'));
      expect(rouletteBetAt(0.05, 0.05), _bet('firstFour:0-1-2-3'));
    });

    test('the boxes outside the numbers', () {
      expect(rouletteBetAt(12.5, 0.5), rouletteOutside(RouletteBetKind.column));
      expect(rouletteBetAt(7, -0.5), rouletteOutside(RouletteBetKind.dozen, 1));
      expect(rouletteBetAt(0.3, -1.2), rouletteOutside(RouletteBetKind.low));
      expect(rouletteBetAt(5, -1.5), rouletteOutside(RouletteBetKind.red));
      expect(rouletteBetAt(11.9, -1.9), rouletteOutside(RouletteBetKind.high));
    });

    test('off the table, or a blank corner, is no bet', () {
      expect(rouletteBetAt(-0.5, -0.5), isNull);
      expect(rouletteBetAt(12.5, -1.5), isNull);
      expect(rouletteBetAt(-1.5, 1), isNull);
      expect(rouletteBetAt(13, 1), isNull);
      expect(rouletteBetAt(5, 3), isNull);
      expect(rouletteBetAt(double.nan, 1), isNull);
    });
  });

  group('game', () {
    test('chips build up, undo and clear', () {
      final red = rouletteOutside(RouletteBetKind.red);
      var game = const RouletteGame.newTable()
          .place(red, 5)
          .place(rouletteStraight(17), 1)
          .place(red, 25);
      expect(game.totalBet, 31);
      expect(game.stakeOn(red), 30);
      expect(game.stakes.keys, [red, rouletteStraight(17)]);
      game = game.undo();
      expect(game.stakeOn(red), 5);
      expect(game.clear().totalBet, 0);
      expect(() => game.clear().undo(), throwsStateError);
    });

    test('the table limit is 1,000 on each bet', () {
      final bet = rouletteStraight(7);
      var game = const RouletteGame.newTable();
      for (var i = 0; i < 2; i++) {
        game = game.place(bet, 500);
      }
      expect(game.canPlace(bet, 1), isFalse);
      expect(() => game.place(bet, 1), throwsStateError);
      expect(game.canPlace(rouletteStraight(8), 500), isTrue);
    });

    test('a spin pays every bet covering the number', () {
      final game = const RouletteGame.newTable()
          .place(rouletteStraight(17), 10)
          .place(_bet('split:17-20'), 5)
          .place(rouletteOutside(RouletteBetKind.black), 25)
          .place(rouletteOutside(RouletteBetKind.red), 25)
          .spin(17);
      expect(game.isSpinning, isTrue);
      expect(game.payout, 0, reason: 'not paid until settled');
      expect(game.pendingPayout, 360 + 90 + 50);
      expect(() => game.place(rouletteStraight(1), 1), throwsStateError);
      final done = game.settle();
      expect(done.payout, 500);
      expect(done.wins.map((w) => w.bet.id), [
        'straight:17',
        'split:17-20',
        'black',
      ]);
    });

    test('0 beats every outside bet', () {
      final game = const RouletteGame.newTable()
          .place(rouletteOutside(RouletteBetKind.red), 100)
          .place(rouletteOutside(RouletteBetKind.even), 100)
          .place(rouletteOutside(RouletteBetKind.dozen), 100)
          .place(_bet('trio:0-1-2'), 1)
          .spin(0)
          .settle();
      expect(game.wins.single.bet.id, 'trio:0-1-2');
      expect(game.payout, 12);
    });

    test('chips stay for the next spin; changing them clears the result', () {
      final bet = rouletteStraight(3);
      final done = const RouletteGame.newTable().place(bet, 5).spin(3).settle();
      expect(done.canSpin, isTrue);
      expect(done.spin(4).totalBet, 5);
      final changed = done.place(bet, 5);
      expect(changed.phase, RoulettePhase.betting);
      expect(changed.pocket, 3, reason: 'the wheel still shows it');
      expect(changed.wins, isEmpty);
      expect(changed.payout, 0);
    });

    test('nothing to spin on an empty table; pockets are 0–36', () {
      expect(const RouletteGame.newTable().canSpin, isFalse);
      final game = const RouletteGame.newTable().place(rouletteStraight(1), 1);
      expect(() => game.spin(37), throwsArgumentError);
      expect(() => game.spin(-1), throwsArgumentError);
    });

    test('a rolling spin survives a save; anything else does not', () {
      final game = const RouletteGame.newTable()
          .place(_bet('corner:1-2-4-5'), 25)
          .place(rouletteStraight(0), 1)
          .place(_bet('corner:1-2-4-5'), 5)
          .spin(5);
      final restored = RouletteGame.fromJson(game.toJson())!;
      expect(restored.isSpinning, isTrue);
      expect(restored.pocket, 5);
      expect(restored.totalBet, 31);
      expect(restored.pendingPayout, game.pendingPayout);

      expect(RouletteGame.fromJson(game.settle().toJson()), isNull);
      Map<String, dynamic> broken(String key, Object? value) =>
          game.toJson()..[key] = value;
      expect(RouletteGame.fromJson(broken('version', 2)), isNull);
      expect(RouletteGame.fromJson(broken('pocket', 37)), isNull);
      expect(RouletteGame.fromJson(broken('placements', [])), isNull);
      expect(
        RouletteGame.fromJson(
          broken('placements', [
            ['straight:99', 5],
          ]),
        ),
        isNull,
      );
      expect(
        RouletteGame.fromJson(
          broken('placements', [
            ['red', 1001],
          ]),
        ),
        isNull,
      );
      expect(RouletteGame.fromJson(broken('placements', ['red'])), isNull);
    });
  });

  group('achievements', () {
    RouletteGame spun(Map<String, int> bets, int pocket) {
      var game = const RouletteGame.newTable();
      for (final MapEntry(:key, :value) in bets.entries) {
        game = game.place(_bet(key), value);
      }
      return game.spin(pocket).settle();
    }

    test('straight up, green zero and déjà vu', () {
      final check = checkRouletteAchievements(
        game: spun({'straight:0': 1}, 0),
        previousPocket: 0,
        insideKindsWon: const {},
      );
      expect(check.earned, {
        RouletteAchievementIds.straightUp,
        RouletteAchievementIds.greenZero,
        RouletteAchievementIds.dejaVu,
      });
      expect(check.insideKinds, {'straight'});

      final lost = checkRouletteAchievements(
        game: spun({'red': 5}, 0),
        previousPocket: 0,
        insideKindsWon: const {},
      );
      expect(lost.earned, isEmpty);
    });

    test('inside story collects the five inside kinds', () {
      final check = checkRouletteAchievements(
        game: spun({
          'split:4-5': 1,
          'street:4-5-6': 1,
          'corner:1-2-4-5': 1,
          'sixLine:1-2-3-4-5-6': 1,
        }, 5),
        previousPocket: null,
        insideKindsWon: const {},
      );
      expect(check.insideKinds, {'split', 'street', 'corner', 'sixLine'});
      expect(check.earned, isEmpty);
      final done = checkRouletteAchievements(
        game: spun({'straight:9': 1}, 9),
        previousPocket: 5,
        insideKindsWon: check.insideKinds,
      );
      expect(done.earned, {
        RouletteAchievementIds.straightUp,
        RouletteAchievementIds.insideStory,
      });
    });
  });
}

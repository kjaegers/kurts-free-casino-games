import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_achievements.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_game.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_paytable.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_reels.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/slots_cherry_run_screen_controller.dart';

import '../../tools/slots_cherry_run/return_check.dart';
import 'cherry_run_test_support.dart';

const _sev = CherryRunSymbol.seven;
const _tri = CherryRunSymbol.tripleBar;
const _dbl = CherryRunSymbol.doubleBar;
const _bar = CherryRunSymbol.bar;
const _bel = CherryRunSymbol.bell;
const _plm = CherryRunSymbol.plum;
const _lem = CherryRunSymbol.lemon;
const _chy = CherryRunSymbol.cherry;

void main() {
  group('reels', () {
    test('every reel carries the published symbols', () {
      const expected = {
        _sev: 1,
        _tri: 2,
        _dbl: 3,
        _bar: 4,
        _bel: 4,
        _plm: 5,
        _lem: 5,
        _chy: 4,
      };
      for (final reel in cherryRunReels) {
        expect(reel, hasLength(cherryRunStopCount));
        final counts = <CherryRunSymbol, int>{};
        for (final s in reel) {
          counts[s] = (counts[s] ?? 0) + 1;
        }
        expect(counts, expected);
      }
    });

    test('the window shows the stop in the middle, wrapping round', () {
      final rows = cherryRunWindow([0, 27, 13]);
      expect(rows[1], [
        cherryRunReels[0][0],
        cherryRunReels[1][27],
        cherryRunReels[2][13],
      ]);
      expect(rows[0], [
        cherryRunReels[0][27],
        cherryRunReels[1][26],
        cherryRunReels[2][12],
      ]);
      expect(rows[2], [
        cherryRunReels[0][1],
        cherryRunReels[1][0],
        cherryRunReels[2][14],
      ]);
    });
  });

  group('paytable', () {
    test('every line pays as published', () {
      final cases = <List<CherryRunSymbol>, CherryRunWin?>{
        [_sev, _sev, _sev]: CherryRunWin.sevens,
        [_tri, _tri, _tri]: CherryRunWin.tripleBars,
        [_dbl, _dbl, _dbl]: CherryRunWin.doubleBars,
        [_bar, _bar, _bar]: CherryRunWin.bars,
        [_bel, _bel, _bel]: CherryRunWin.bells,
        [_chy, _chy, _chy]: CherryRunWin.threeCherries,
        [_plm, _plm, _plm]: CherryRunWin.plums,
        [_lem, _lem, _lem]: CherryRunWin.lemons,
        [_bar, _tri, _dbl]: CherryRunWin.anyBars,
        [_tri, _tri, _bar]: CherryRunWin.anyBars,
        [_chy, _chy, _sev]: CherryRunWin.twoCherries,
        [_chy, _sev, _sev]: CherryRunWin.oneCherry,
        [_chy, _bel, _chy]: CherryRunWin.oneCherry,
        [_bel, _chy, _chy]: null,
        [_sev, _sev, _bar]: null,
        [_bar, _bar, _sev]: null,
        [_lem, _plm, _bel]: null,
      };
      for (final MapEntry(key: line, value: win) in cases.entries) {
        expect(evaluateCherryRunLine(line), win, reason: '$line');
      }
      expect(
        [for (final w in CherryRunWin.values) w.pays],
        [1000, 100, 50, 25, 20, 20, 15, 12, 5, 5, 2],
      );
    });

    test('each pattern pays the win it pictures', () {
      for (final win in CherryRunWin.values) {
        final line = [for (final s in win.pattern) s ?? _bel];
        expect(evaluateCherryRunLine(line), win, reason: win.name);
      }
    });

    test('the published return matches the exact return', () {
      expect(
        (cherryRunTheoreticalReturn() * 100).toStringAsFixed(2),
        cherryRunReturnPercent,
      );
      final counts = winCounts();
      expect(counts[CherryRunWin.sevens], 1, reason: '1 in 21,952');
      final hits = counts.values.reduce((a, b) => a + b);
      expect(hits / pow(cherryRunStopCount, 3), closeTo(0.19, 0.01));
    });
  });

  group('game', () {
    test('a new session is ready and clamps its bet', () {
      final game = CherryRunGame.newSession(lines: 9, betPerLine: 0);
      expect(game.phase, CherryRunPhase.ready);
      expect(game.lines, 3);
      expect(game.betPerLine, 1);
      expect(game.lineWins, isEmpty);
      expect(game.payout, 0);
    });

    test('lines map to rows: 1 middle, 2 top, 3 bottom', () {
      final stops = [0, 0, 0];
      final rows = cherryRunWindow(stops);
      final game = CherryRunGame.newSession(lines: 3).spin(stops).settle();
      for (final w in game.lineWins) {
        expect(evaluateCherryRunLine(rows[w.row]), w.win);
      }
      expect(cherryRunLineRows, [1, 0, 2]);
    });

    test('only the lines played pay, at the bet per line', () {
      final stops = stopsFor([_bel, _bel, _bel]);
      final middle = CherryRunGame.newSession(
        lines: 1,
        betPerLine: 3,
      ).spin(stops);
      expect(middle.isSpinning, isTrue);
      expect(middle.payout, 0, reason: 'not paid until settled');
      expect(middle.pendingPayout, 60);
      final paid = middle.settle();
      expect(paid.lineWins.single.line, 1);
      expect(paid.lineWins.single.win, CherryRunWin.bells);
      expect(paid.payout, 60);
      expect(paid.totalBet, 3);
    });

    test('several lines add up', () {
      for (var a = 0; a < cherryRunStopCount; a++) {
        final stops = [a, 0, 0];
        final game = CherryRunGame.newSession(
          lines: 3,
          betPerLine: 2,
        ).spin(stops).settle();
        final expected = [
          for (var line = 1; line <= 3; line++)
            evaluateCherryRunLine(game.window[cherryRunLineRows[line - 1]]),
        ];
        expect(
          game.lineWins.map((w) => w.win),
          expected.whereType<CherryRunWin>(),
        );
        expect(
          game.payout,
          expected.fold<int>(0, (sum, w) => sum + (w?.pays ?? 0) * 2),
        );
      }
    });

    test('illegal transitions throw', () {
      final ready = CherryRunGame.newSession();
      expect(ready.settle, throwsStateError);
      expect(() => ready.spin([0, 0]), throwsArgumentError);
      expect(() => ready.spin([0, 0, 28]), throwsArgumentError);
      expect(() => ready.withLines(4), throwsRangeError);
      expect(() => ready.withBetPerLine(6), throwsRangeError);
      final spinning = ready.spin([1, 2, 3]);
      expect(spinning.canChangeBet, isFalse);
      expect(() => spinning.spin([1, 2, 3]), throwsStateError);
      expect(() => spinning.withLines(1), throwsStateError);
      expect(() => spinning.withBetPerLine(2), throwsStateError);
      final complete = spinning.settle();
      expect(complete.canSpin, isTrue);
      expect(complete.withLines(1).lines, 1);
    });

    test('a spinning game round-trips through JSON', () {
      final game = CherryRunGame.newSession(
        lines: 2,
        betPerLine: 4,
      ).spin([5, 17, 27]);
      final restored = CherryRunGame.fromJson(game.toJson())!;
      expect(restored.isSpinning, isTrue);
      expect(restored.lines, 2);
      expect(restored.betPerLine, 4);
      expect(restored.stops, [5, 17, 27]);
    });

    test('malformed or finished saves are rejected', () {
      final good = CherryRunGame.newSession().spin([1, 2, 3]).toJson();
      final bad = <Map<String, dynamic>>[
        {...good, 'version': 2},
        {...good, 'phase': 'complete'},
        {...good, 'lines': 0},
        {...good, 'lines': '3'},
        {...good, 'betPerLine': 6},
        {...good, 'stops': 'abc'},
        {
          ...good,
          'stops': [1, 2],
        },
        {
          ...good,
          'stops': [1, 2, -1],
        },
        {
          ...good,
          'stops': [1, 2, 3.5],
        },
        CherryRunGame.newSession().toJson(),
      ];
      for (final json in bad) {
        expect(CherryRunGame.fromJson(json), isNull, reason: '$json');
      }
    });
  });

  group('achievements', () {
    test('three-of-a-kind lines and fruit salad', () {
      CherryRunAchievementCheck check(
        List<CherryRunSymbol> middle, [
        Set<String> fruits = const {},
      ]) => checkCherryRunAchievements(
        game: CherryRunGame.newSession(
          lines: 1,
        ).spin(stopsFor(middle)).settle(),
        fruitsWon: fruits,
      );

      expect(check([_sev, _sev, _sev]).earned, {
        CherryRunAchievementIds.luckySevens,
      });
      expect(check([_tri, _tri, _tri]).earned, {
        CherryRunAchievementIds.topBar,
      });
      expect(check([_bel, _bel, _bel]).earned, {
        CherryRunAchievementIds.bellRinger,
      });
      final cherries = check([_chy, _chy, _chy]);
      expect(cherries.earned, {CherryRunAchievementIds.cherryRun});
      expect(cherries.fruits, {'threeCherries'});
      expect(check([_plm, _plm, _plm], {'threeCherries'}).earned, isEmpty);
      expect(check([_lem, _lem, _lem], {'threeCherries', 'plums'}).earned, {
        CherryRunAchievementIds.fruitSalad,
      });
      expect(check([_chy, _chy, _bel]).fruits, isEmpty);
    });

    test('nothing is earned before a spin is paid', () {
      final spinning = CherryRunGame.newSession().spin(
        stopsFor([_sev, _sev, _sev]),
      );
      expect(
        checkCherryRunAchievements(game: spinning, fruitsWon: {}).earned,
        isEmpty,
      );
    });
  });

  test('the fair stop picker is uniform on every reel', () {
    final pick = CherryRunScreenController.fairStopPicker(Random(42));
    const draws = 28000;
    for (var reel = 0; reel < cherryRunReelCount; reel++) {
      final counts = List<int>.filled(cherryRunStopCount, 0);
      for (var i = 0; i < draws; i++) {
        counts[pick(reel)]++;
      }
      // Chi-square, 27 degrees of freedom: 55 is past the 0.1% tail.
      const expected = draws / cherryRunStopCount;
      final chi = counts.fold<double>(
        0,
        (sum, n) => sum + (n - expected) * (n - expected) / expected,
      );
      expect(chi, lessThan(55), reason: 'reel $reel');
    }
  });
}

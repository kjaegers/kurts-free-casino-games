import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_achievements.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_cascade.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_game.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_paytable.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_symbols.dart';

import '../../tools/slots_retro_tech/return_check.dart';
import 'retro_tech_test_support.dart';

const _chip = RetroTechSymbol.chip;

void main() {
  group('symbols', () {
    test('weights add up to the published total', () {
      expect(
        RetroTechSymbol.values.fold(0, (sum, s) => sum + s.weight),
        retroTechTotalWeight,
      );
    });

    test('the fair draw follows the weights', () {
      final draw = retroTechFairDraw(Random(3));
      const n = 200000;
      final counts = <RetroTechSymbol, int>{};
      for (var i = 0; i < n; i++) {
        final s = draw(i % retroTechColumns);
        counts[s] = (counts[s] ?? 0) + 1;
      }
      for (final s in RetroTechSymbol.values) {
        final p = s.weight / retroTechTotalWeight;
        // Within four standard errors.
        final tolerance = 4 * sqrt(p * (1 - p) / n);
        expect(counts[s]! / n, closeTo(p, tolerance), reason: s.label);
      }
    });

    test('the resting grid shows every symbol and no cluster', () {
      expect(retroTechRestingGrid.toSet(), RetroTechSymbol.values.toSet());
      expect(findRetroTechClusters(retroTechRestingGrid), isEmpty);
    });
  });

  group('paytable', () {
    test('every size maps to the right column', () {
      for (var size = 1; size <= retroTechCellCount; size++) {
        final tier = retroTechTierOf(size);
        if (size < retroTechMinCluster) {
          expect(tier, isNull, reason: '$size');
        } else {
          expect(retroTechTiers[tier!].contains(size), isTrue);
        }
      }
      expect(retroTechTierOf(4), 0);
      expect(retroTechTierOf(7), 3);
      expect(retroTechTierOf(8), 4);
      expect(retroTechTierOf(10), 4);
      expect(retroTechTierOf(11), 5);
      expect(retroTechTierOf(25), 5);
    });

    test('bigger clusters and rarer symbols never pay less', () {
      final symbols = RetroTechSymbol.values;
      for (var i = 0; i < symbols.length; i++) {
        final pays = retroTechPaytable[symbols[i]]!;
        expect(pays, hasLength(retroTechTiers.length));
        for (var t = 1; t < pays.length; t++) {
          expect(pays[t], greaterThan(pays[t - 1]));
        }
        if (i > 0) {
          final better = retroTechPaytable[symbols[i - 1]]!;
          for (var t = 0; t < pays.length; t++) {
            expect(better[t], greaterThanOrEqualTo(pays[t]));
          }
        }
      }
    });

    test('every paytable entry is paid as published', () {
      for (final symbol in RetroTechSymbol.values) {
        for (var t = 0; t < retroTechTiers.length; t++) {
          for (
            var size = retroTechTiers[t].min;
            size <= retroTechTiers[t].max;
            size++
          ) {
            expect(
              retroTechClusterPays(symbol, size),
              retroTechPaytable[symbol]![t],
            );
          }
        }
        expect(retroTechClusterPays(symbol, 3), 0);
      }
    });
  });

  group('clusters', () {
    test('four touching symbols make a cluster; diagonals do not', () {
      final clusters = findRetroTechClusters(gridOf(chipCornerRows));
      expect(clusters, hasLength(1));
      expect(clusters.single.symbol, _chip);
      expect(clusters.single.cells, [0, 1, 5, 10]);
      expect(clusters.single.pays, 10);

      // The same four chips joined only corner to corner don't pay.
      expect(
        findRetroTechClusters(
          gridOf(['XRXMF', 'RXMFG', 'XMFGC', 'MFGCX', 'FGCXT']),
        ),
        isEmpty,
      );
    });

    test('three is not enough, and separate clusters pay separately', () {
      expect(
        findRetroTechClusters(
          gridOf(['XXJMF', 'XRMFG', 'JMFGC', 'MFGCX', 'FGCXT']),
        ),
        isEmpty,
      );
      final clusters = findRetroTechClusters(
        gridOf(['XXJMF', 'XRMFG', 'XMFGC', 'MFTTT', 'FGCXT']),
      );
      expect(
        [for (final c in clusters) (c.symbol, c.size)],
        [(_chip, 4), (RetroTechSymbol.token, 4)],
      );
    });

    test('a whole grid of one symbol is one cluster of 25', () {
      final clusters = findRetroTechClusters(
        List.filled(retroTechCellCount, _chip),
      );
      expect(clusters.single.size, 25);
      expect(clusters.single.pays, retroTechPaytable[_chip]!.last);
    });
  });

  group('cascades', () {
    test('the first symbol drawn for a column lands at the bottom', () {
      final result = RetroTechSpinResult.replay(dropsFor(quietRows))!;
      expect(result.grids.single, gridOf(quietRows));
      expect(result.cascades, 0);
      expect(result.pays, 0);
      // Every cell falls a whole window height.
      expect(result.fallFrom.single[0], -5);
      expect(result.fallFrom.single[24], -1);
    });

    test('winners vanish, the rest fall and new symbols drop in', () {
      final result = RetroTechSpinResult.replay(
        dropsFor(chipCornerRows, ['TRJ', 'M', '', '', '']),
      )!;
      expect(result.cascades, 1);
      expect(result.pays, 10);
      expect(result.steps.single.removed, {0, 1, 5, 10});
      expect(
        result.finalGrid,
        gridOf(['JMJMF', 'RRMFG', 'TMFGC', 'MFGCX', 'FGCXT']),
      );
      final from = result.fallFrom[1];
      // Column 0: three new symbols, the first drawn lowest.
      expect(
        [for (var row = 0; row < 5; row++) from[row * 5]],
        [-3, -2, -1, 3, 4],
      );
      // Column 1: one new symbol on top, the rest where they were.
      expect(
        [for (var row = 0; row < 5; row++) from[row * 5 + 1]],
        [-1, 1, 2, 3, 4],
      );
      // Columns with no winners don't move.
      expect(from[2], 0);
    });

    test('survivors above a gap fall into it', () {
      // Four chips across the middle row; everything above drops one row.
      final rows = ['TRJMF', 'RJMFG', 'XXXXC', 'MFGCX', 'FGCXT'];
      final result = RetroTechSpinResult.replay(
        dropsFor(rows, ['C', 'J', 'G', 'T', '']),
      )!;
      expect(result.steps.single.removed, {10, 11, 12, 13});
      expect(result.finalGrid.sublist(0, 15), [
        ...symbolsOf('CJGTF'),
        ...symbolsOf('TRJMG'),
        ...symbolsOf('RJMFC'),
      ]);
      expect(result.fallFrom[1].sublist(0, 15), [
        -1, -1, -1, -1, 0, //
        0, 0, 0, 0, 1,
        1, 1, 1, 1, 2,
      ]);
    });

    test('new clusters keep cascading, every one paid', () {
      final result = RetroTechSpinResult.replay(
        dropsFor(chipCornerRows, ['XXXTRJ', 'XM', '', '', '']),
      )!;
      expect(result.cascades, 2);
      expect(result.grids, hasLength(3));
      expect(result.grids[1], gridOf(chipCornerRows));
      expect(result.pays, 20);
    });

    test('a spin stops after the cascade cap, the last one still paid', () {
      final result = RetroTechSpinResult.resolve((_) => _chip);
      expect(result.cascades, retroTechMaxCascades);
      expect(result.grids, hasLength(retroTechMaxCascades));
      expect(
        result.pays,
        retroTechMaxCascades * retroTechPaytable[_chip]!.last,
      );
    });

    test('a replay rebuilds the very same spin', () {
      final draw = retroTechFairDraw(Random(9));
      for (var i = 0; i < 200; i++) {
        final spin = RetroTechSpinResult.resolve(draw);
        final again = RetroTechSpinResult.replay(spin.drops)!;
        expect(again.grids, spin.grids);
        expect(again.pays, spin.pays);
        expect(again.fallFrom, spin.fallFrom);
      }
    });

    test('a replay rejects too few or too many symbols', () {
      final drops = dropsFor(chipCornerRows, ['TRJ', 'M', '', '', '']);
      expect(
        RetroTechSpinResult.replay([drops[0].sublist(0, 7), ...drops.skip(1)]),
        isNull,
      );
      expect(
        RetroTechSpinResult.replay([
          [...drops[0], _chip],
          ...drops.skip(1),
        ]),
        isNull,
      );
      expect(RetroTechSpinResult.replay(drops.sublist(1)), isNull);
    });
  });

  group('game', () {
    RetroTechSpinResult chips() => RetroTechSpinResult.replay(
      dropsFor(chipCornerRows, ['TRJ', 'M', '', '', '']),
    )!;

    test('bet levels are 10 to 50 credits', () {
      final game = RetroTechGame.newSession(betLevel: 9);
      expect(game.betLevel, 5);
      expect(game.totalBet, 50);
      expect(RetroTechGame.newSession(betLevel: 0).totalBet, 10);
      expect(() => game.withBetLevel(6), throwsRangeError);
      expect(game.withBetLevel(2).totalBet, 20);
    });

    test('a spin pays per bet level once settled', () {
      final ready = RetroTechGame.newSession(betLevel: 3);
      expect(ready.grid, retroTechRestingGrid);
      expect(() => ready.settle(), throwsStateError);
      final spinning = ready.spin(chips());
      expect(spinning.isSpinning, isTrue);
      expect(spinning.payout, 0);
      expect(spinning.pendingPayout, 30);
      expect(spinning.payoutAfter(0), 0);
      expect(spinning.payoutAfter(1), 30);
      expect(() => spinning.spin(chips()), throwsStateError);
      expect(() => spinning.withBetLevel(1), throwsStateError);
      final done = spinning.settle();
      expect(done.payout, 30);
      expect(done.grid, chips().finalGrid);
    });

    test('a spin in progress survives a save', () {
      final game = RetroTechGame.newSession(betLevel: 4).spin(chips());
      final restored = RetroTechGame.fromJson(game.toJson())!;
      expect(restored.isSpinning, isTrue);
      expect(restored.betLevel, 4);
      expect(restored.result!.grids, game.result!.grids);
      expect(restored.pendingPayout, 40);
    });

    test('bad saves are rejected', () {
      final json = RetroTechGame.newSession().spin(chips()).toJson();
      for (final bad in <Map<String, dynamic>>[
        {...json, 'version': 2},
        {...json, 'phase': 'complete'},
        {...json, 'betLevel': 6},
        {...json, 'betLevel': '2'},
        {...json, 'drops': 'XX'},
        {
          ...json,
          'drops': [
            ['chip', 'nope'],
          ],
        },
        {...json, 'drops': (json['drops'] as List).sublist(1)},
      ]) {
        expect(RetroTechGame.fromJson(bad), isNull, reason: '$bad');
      }
      expect(
        RetroTechGame.fromJson(RetroTechGame.newSession().toJson()),
        isNull,
        reason: 'only a spin in progress is saved',
      );
    });
  });

  group('achievements', () {
    RetroTechGame played(List<List<RetroTechSymbol>> drops) =>
        RetroTechGame.newSession()
            .spin(RetroTechSpinResult.replay(drops)!)
            .settle();

    test('chip wins count toward Full Collection only', () {
      final check = checkRetroTechAchievements(
        game: played(dropsFor(chipCornerRows, ['TRJ', 'M', '', '', ''])),
        symbolsWon: const {},
      );
      expect(check.earned, isEmpty);
      expect(check.symbols, {'chip'});
    });

    test('tokens, runners, mega clusters and the full set', () {
      final rows = ['TTRRX', 'TTRRX', 'FGCJX', 'JMFGX', 'FGCXX'];
      final check = checkRetroTechAchievements(
        game: played(dropsFor(rows, ['JM', 'MJ', 'JM', 'TRJ', 'TCXCF'])),
        symbolsWon: {
          for (final s in RetroTechSymbol.values)
            if (s != RetroTechSymbol.token) s.name,
        },
      );
      expect(check.earned, {
        RetroTechAchievementIds.tokenRush,
        RetroTechAchievementIds.playerOne,
        RetroTechAchievementIds.fullCollection,
      });

      final mega = checkRetroTechAchievements(
        game: RetroTechGame.newSession()
            .spin(RetroTechSpinResult.resolve((_) => _chip))
            .settle(),
        symbolsWon: const {},
      );
      expect(mega.earned, {
        RetroTechAchievementIds.megaCluster,
        RetroTechAchievementIds.chainReaction,
      });
    });

    test('a spin still playing earns nothing', () {
      final game = RetroTechGame.newSession().spin(
        RetroTechSpinResult.resolve((_) => _chip),
      );
      expect(
        checkRetroTechAchievements(game: game, symbolsWon: const {}).earned,
        isEmpty,
      );
    });
  });

  test('the simulated return matches the published figure', () {
    // A short run (standard error about 0.5%); the full check is
    // `dart run tools/slots_retro_tech/return_check.dart`.
    final sim = simulateRetroTech(spins: 200000, seed: 11);
    final published = double.parse(retroTechReturnPercent) / 100;
    expect(sim.mean, closeTo(published, 0.0005 + 3 * sim.standardError));
    expect(sim.hits / sim.spins, closeTo(0.34, 0.01));
  });
}

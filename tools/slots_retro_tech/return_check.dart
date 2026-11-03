// Measures Retro Tech's return, hit frequency, cascade lengths and how
// often each cluster pays, to check the figures printed in How to Play
// (`retroTechReturnPercent`).
//
// Dev-time only, runs offline:
//   dart run tools/slots_retro_tech/return_check.dart [spins] [seed]
//
// Method: a Monte Carlo simulation of spins played out by the real cascade
// logic with the real symbol weights. Cascades have too many outcomes to
// enumerate, so the result is an estimate: the printed standard error is
// about 0.05% at the default 20 million spins.

// ignore_for_file: avoid_print

import 'dart:math';

import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_cascade.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_paytable.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_symbols.dart';

/// What [spins] simulated spins came to.
class RetroTechSimulation {
  RetroTechSimulation(this.spins);

  final int spins;

  /// Paying spins, and spins paying more than the bet.
  int hits = 0;
  int wins = 0;

  /// Spins by number of paying cascades (index 0 = no win).
  final List<int> byCascades = List.filled(retroTechMaxCascades + 1, 0);

  /// Clusters paid, by symbol and then by size.
  final Map<RetroTechSymbol, List<int>> clusters = {
    for (final s in RetroTechSymbol.values)
      s: List.filled(retroTechCellCount + 1, 0),
  };

  double sum = 0;
  double sumSquares = 0;

  /// The mean share of the bet paid back per spin.
  double get mean => sum / spins;

  double get standardError => sqrt((sumSquares / spins - mean * mean) / spins);
}

/// Plays [spins] spins. Pays are per bet level, so the return per credit
/// bet is the same at every level.
RetroTechSimulation simulateRetroTech({required int spins, int seed = 1}) {
  final draw = retroTechFairDraw(Random(seed));
  final sim = RetroTechSimulation(spins);
  for (var i = 0; i < spins; i++) {
    final result = RetroTechSpinResult.resolve(draw);
    sim.byCascades[result.cascades]++;
    for (final step in result.steps) {
      for (final c in step.clusters) {
        sim.clusters[c.symbol]![c.size]++;
      }
    }
    final pays = result.pays;
    if (pays > 0) sim.hits++;
    if (pays > retroTechCreditsPerLevel) sim.wins++;
    final ratio = pays / retroTechCreditsPerLevel;
    sim.sum += ratio;
    sim.sumSquares += ratio * ratio;
  }
  return sim;
}

void main(List<String> args) {
  final spins = args.isEmpty ? 20000000 : int.parse(args.first);
  final seed = args.length < 2 ? 1 : int.parse(args[1]);
  final sim = simulateRetroTech(spins: spins, seed: seed);

  for (final symbol in RetroTechSymbol.values) {
    final sizes = sim.clusters[symbol]!;
    final perTier = [
      for (final tier in retroTechTiers)
        [
          for (var n = tier.min; n <= tier.max; n++) sizes[n],
        ].fold(0, (a, b) => a + b),
    ];
    var paid = 0.0;
    for (var t = 0; t < retroTechTiers.length; t++) {
      paid += perTier[t] * retroTechPaytable[symbol]![t];
    }
    print(
      '${symbol.label.padRight(15)} '
      '${[for (final n in perTier) '1 in ${n == 0 ? '-' : (spins / n).toStringAsFixed(0)}'.padLeft(13)].join()}'
      '  return ${(paid * 100 / spins / retroTechCreditsPerLevel).toStringAsFixed(2)}%',
    );
  }
  print(
    'Paying spins ${(sim.hits * 100 / spins).toStringAsFixed(2)}%, '
    'spins paying more than the bet ${(sim.wins * 100 / spins).toStringAsFixed(2)}%',
  );
  for (var n = 2; n < sim.byCascades.length; n++) {
    if (sim.byCascades[n] == 0) continue;
    print(
      '  $n cascades: 1 in ${(spins / sim.byCascades[n]).toStringAsFixed(0)}',
    );
  }
  final atLeast4 = sim.byCascades.skip(4).fold(0, (a, b) => a + b);
  print('4+ cascades: 1 in ${(spins / atLeast4).toStringAsFixed(0)}');

  final percent = sim.mean * 100;
  final error = sim.standardError * 100;
  print(
    'Return over $spins spins: ${percent.toStringAsFixed(3)}% '
    '± ${error.toStringAsFixed(3)}% (one standard error)',
  );
  final published = double.parse(retroTechReturnPercent);
  // The published figure is rounded to one decimal place.
  final ok = (percent - published).abs() <= 0.05 + 3 * error;
  print('Published $retroTechReturnPercent% ${ok ? 'OK' : 'MISMATCH'}');
  if (!ok) throw StateError('The published return does not match.');
}

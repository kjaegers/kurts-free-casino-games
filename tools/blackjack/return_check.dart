// Measures Blackjack's return for a player using perfect basic strategy, to
// check the figure printed in How to Play (`blackjackReturnPercent`).
//
// Dev-time only, runs offline:
//   dart run tools/blackjack/return_check.dart [rounds] [seed]
//
// Method: a Monte Carlo simulation that plays the real game logic, round
// after round through shuffled six-deck shoes with the cut card in place,
// and averages the return per credit of opening bet. Blackjack has too many
// card orders to enumerate, so the result is an estimate: the printed
// standard error is about 0.04% at the default 8 million rounds.

// ignore_for_file: avoid_print

import 'dart:math';

import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_game.dart';

import 'basic_strategy.dart';

/// Simulates [rounds] rounds at a 10-credit bet. Returns the mean and
/// standard error of the net result per credit bet.
({double mean, double standardError}) simulateBasicStrategy({
  required int rounds,
  int seed = 1,
}) {
  final random = Random(seed);
  var game = BlackjackGame.newSession(bet: 10);
  var sum = 0.0;
  var sumSquares = 0.0;
  for (var i = 0; i < rounds; i++) {
    game = game.deal(
      shuffledShoe: game.needsShuffle
          ? BlackjackGame.shuffledShoe((cards) => cards..shuffle(random))
          : null,
    );
    game = playBasicStrategy(game);
    final net = (game.payout - game.totalWagered) / game.bet;
    sum += net;
    sumSquares += net * net;
  }
  final mean = sum / rounds;
  final variance = sumSquares / rounds - mean * mean;
  return (mean: mean, standardError: sqrt(variance / rounds));
}

void main(List<String> args) {
  final rounds = args.isEmpty ? 8000000 : int.parse(args.first);
  final seed = args.length < 2 ? 1 : int.parse(args[1]);
  final result = simulateBasicStrategy(rounds: rounds, seed: seed);
  final percent = 100 + result.mean * 100;
  final error = result.standardError * 100;
  print(
    'Return over $rounds rounds: ${percent.toStringAsFixed(3)}% '
    '± ${error.toStringAsFixed(3)}% (one standard error)',
  );
  final published = double.parse(blackjackReturnPercent);
  // The published figure is rounded to one decimal place.
  final ok = (percent - published).abs() <= 0.05 + 3 * error;
  print('Published $blackjackReturnPercent% ${ok ? 'OK' : 'MISMATCH'}');
  if (!ok) throw StateError('The published return does not match.');
}

// Computes the theoretical return of each video poker variant with perfect
// play at the maximum bet, to check the figures printed in How to Play
// (`VideoPokerVariant.returnPercent`).
//
// Dev-time only, runs offline:
//   dart run tools/video_poker/return_check.dart [variantName ...]
//
// Method: for every k-card subset of the deck, sum the pay of all five-card
// hands that contain it. For a dealt hand D and a hold H, inclusion-exclusion
// over the discards D\H then gives the total pay of every draw that keeps H
// and can't redraw a discard. The best hold's average, over every possible
// deal, is the return.

// ignore_for_file: avoid_print

import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_evaluator.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_variant.dart';

void main(List<String> args) {
  final variants = args.isEmpty
      ? VideoPokerVariant.values
      : args.map(VideoPokerVariant.fromName).toList();
  var failed = false;
  for (final variant in variants) {
    final watch = Stopwatch()..start();
    final percent = theoreticalReturn(variant) * 100;
    final shown = percent.toStringAsFixed(2);
    final ok = shown == variant.returnPercent;
    failed |= !ok;
    print(
      '${variant.label.padRight(16)} $shown% '
      '(published ${variant.returnPercent}%) ${ok ? 'OK' : 'MISMATCH'} '
      '[${watch.elapsed.inSeconds}s]',
    );
  }
  if (failed) throw StateError('A published return does not match.');
}

double theoreticalReturn(VideoPokerVariant variant) {
  final n = variant.deckSize;
  final choose = _binomials(n);
  final sums = [for (var k = 0; k <= 5; k++) List<int>.filled(choose[n][k], 0)];

  // Colex rank of a sorted subset: sum of C(card_i, i + 1).
  final subsetRank = List<int>.filled(32, 0);
  final subsetSize = List<int>.filled(32, 0);
  final cards = List<int>.filled(5, 0);

  void forEachHand(void Function() visit) {
    for (var a = 0; a < n; a++) {
      cards[0] = a;
      for (var b = a + 1; b < n; b++) {
        cards[1] = b;
        for (var c = b + 1; c < n; c++) {
          cards[2] = c;
          for (var d = c + 1; d < n; d++) {
            cards[3] = d;
            for (var e = d + 1; e < n; e++) {
              cards[4] = e;
              for (var mask = 1; mask < 32; mask++) {
                var rank = 0;
                var size = 0;
                for (var i = 0; i < 5; i++) {
                  if (mask & (1 << i) != 0) {
                    size++;
                    rank += choose[cards[i]][size];
                  }
                }
                subsetRank[mask] = rank;
                subsetSize[mask] = size;
              }
              visit();
            }
          }
        }
      }
    }
  }

  // Pass 1: the pay of every final hand, added to all 32 of its subsets.
  forEachHand(() {
    final hand = evaluateVideoPokerCodes(cards, variant);
    final pay = variant.payout(hand, videoPokerMaxBet);
    if (pay == 0) return;
    sums[0][0] += pay;
    for (var mask = 1; mask < 32; mask++) {
      sums[subsetSize[mask]][subsetRank[mask]] += pay;
    }
  });

  // Pass 2: the best hold for every deal.
  final drawCounts = [
    for (var held = 0; held <= 5; held++) choose[n - 5][5 - held],
  ];
  final totals = List<int>.filled(32, 0);
  var bestSum = 0.0;
  forEachHand(() {
    totals[0] = sums[0][0];
    for (var mask = 1; mask < 32; mask++) {
      totals[mask] = sums[subsetSize[mask]][subsetRank[mask]];
    }
    // Remove draws that would bring back a discarded card.
    for (var bit = 1; bit < 32; bit <<= 1) {
      for (var mask = 0; mask < 32; mask++) {
        if (mask & bit == 0) totals[mask] -= totals[mask | bit];
      }
    }
    var best = 0.0;
    for (var mask = 0; mask < 32; mask++) {
      final ev = totals[mask] / drawCounts[subsetSize[mask]];
      if (ev > best) best = ev;
    }
    bestSum += best;
  });

  return bestSum / choose[n][5] / videoPokerMaxBet;
}

List<List<int>> _binomials(int n) {
  final table = [for (var i = 0; i <= n; i++) List<int>.filled(6, 0)];
  for (var i = 0; i <= n; i++) {
    table[i][0] = 1;
    for (var k = 1; k <= 5 && k <= i; k++) {
      table[i][k] = table[i - 1][k - 1] + (k <= i - 1 ? table[i - 1][k] : 0);
    }
  }
  return table;
}

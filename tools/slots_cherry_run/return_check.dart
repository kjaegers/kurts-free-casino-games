// Works out Cherry Run's theoretical return, hit frequency and the odds of
// each paying line, to check the figures printed in How to Play
// (`cherryRunReturnPercent`).
//
// Dev-time only, runs offline:
//   dart run tools/slots_cherry_run/return_check.dart
//
// Method: every stop is equally likely and each line is read from the same
// reels, so one line's odds are exact over all 28³ stop combinations, and
// they don't depend on how many lines are played or the bet.

// ignore_for_file: avoid_print

import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_paytable.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_reels.dart';

void main() {
  final counts = winCounts();
  const combinations =
      cherryRunStopCount * cherryRunStopCount * cherryRunStopCount;
  var hits = 0;
  for (final win in CherryRunWin.values) {
    final n = counts[win] ?? 0;
    hits += n;
    print(
      '${win.label.padRight(20)} pays ${'${win.pays}'.padLeft(4)}  '
      '${'$n'.padLeft(5)} / $combinations  '
      '(1 in ${(combinations / n).toStringAsFixed(1)})',
    );
  }
  final percent = (cherryRunTheoreticalReturn() * 100).toStringAsFixed(2);
  final ok = percent == cherryRunReturnPercent;
  print(
    'Hit frequency per line ${(hits * 100 / combinations).toStringAsFixed(2)}%',
  );
  print(
    'Return $percent% (published $cherryRunReturnPercent%) '
    '${ok ? 'OK' : 'MISMATCH'}',
  );
  if (!ok) throw StateError('The published return does not match.');
}

/// How many of the 28³ stop combinations make each win on a line.
Map<CherryRunWin, int> winCounts() {
  final counts = <CherryRunWin, int>{};
  for (final a in cherryRunReels[0]) {
    for (final b in cherryRunReels[1]) {
      for (final c in cherryRunReels[2]) {
        final win = evaluateCherryRunLine([a, b, c]);
        if (win != null) counts[win] = (counts[win] ?? 0) + 1;
      }
    }
  }
  return counts;
}

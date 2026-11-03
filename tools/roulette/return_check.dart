// Works out the exact return of every bet on the Roulette table, to check
// the figure printed in How to Play (97.30%: 36 back for every 37 bet).
//
// Dev-time only, runs offline:
//   dart run tools/roulette/return_check.dart
//
// Method: every one of the 37 pockets is equally likely, so a bet's return
// is exact over one pass of the wheel: what one credit on it pays back,
// summed over all 37 pockets, divided by 37.

// ignore_for_file: avoid_print

import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_bets.dart';
import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_wheel.dart';

/// Credits one credit on [bet] pays back over one pass of all 37 pockets.
int returnPer37(RouletteBet bet) => [
  for (var pocket = 0; pocket < roulettePocketCount; pocket++)
    if (bet.wins(pocket)) bet.payoutFor(1),
].fold(0, (sum, paid) => sum + paid);

/// The bets whose return is not exactly 36 / 37.
List<RouletteBet> mispricedBets() => [
  for (final bet in rouletteBets)
    if (returnPer37(bet) != 36) bet,
];

void main() {
  final byKind = <RouletteBetKind, List<RouletteBet>>{};
  for (final bet in rouletteBets) {
    (byKind[bet.kind] ??= []).add(bet);
  }
  for (final MapEntry(key: kind, value: bets) in byKind.entries) {
    final sample = bets.first;
    print(
      '${kind.label.padRight(12)} ${'${bets.length}'.padLeft(3)} spots  '
      'covers ${'${sample.numbers.length}'.padLeft(2)}  '
      'pays ${'${kind.pays}'.padLeft(2)} to 1  '
      'returns ${returnPer37(sample)} / 37',
    );
  }
  final bad = mispricedBets();
  print(
    '${rouletteBets.length} bets; return 97.30% (36 / 37) '
    '${bad.isEmpty ? 'OK for every bet' : 'MISMATCH: $bad'}',
  );
  if (bad.isNotEmpty) throw StateError('Some bets do not return 36 / 37.');
}

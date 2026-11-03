// Plays computer opponents against each other through the real hand logic
// and reports how they play: how often they put chips in before the flop,
// how often hands reach a showdown, and which difficulty wins chips from
// which. A sanity check that the difficulties really differ.
//
// Run: dart run tools/texas_holdem/ai_check.dart [hands] [seed]
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_ai.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_hand.dart';

void main(List<String> args) {
  final hands = args.isNotEmpty ? int.parse(args[0]) : 3000;
  final seed = args.length > 1 ? int.parse(args[1]) : 1;
  for (final (a, b) in const [
    (HoldemDifficulty.easy, HoldemDifficulty.normal),
    (HoldemDifficulty.normal, HoldemDifficulty.hard),
    (HoldemDifficulty.easy, HoldemDifficulty.hard),
  ]) {
    for (final seats in const [2, 6]) {
      _match(a, b, seats: seats, hands: hands, seed: seed);
    }
  }
}

/// [seats] players alternating between difficulties [a] and [b], each with
/// a random style, every hand dealt from 1,000-chip stacks.
void _match(
  HoldemDifficulty a,
  HoldemDifficulty b, {
  required int seats,
  required int hands,
  required int seed,
}) {
  final random = Random(seed);
  final net = {a: 0, b: 0};
  final voluntary = {a: 0, b: 0};
  final dealt = {a: 0, b: 0};
  var showdowns = 0;
  for (var hand = 0; hand < hands; hand++) {
    // Seats alternate difficulties, swapping every full orbit of the button
    // so both play every position equally often.
    final levels = [
      for (var i = 0; i < seats; i++) (i + hand ~/ seats).isEven ? a : b,
    ];
    final styles = [
      for (var i = 0; i < seats; i++)
        HoldemStyle.values[random.nextInt(HoldemStyle.values.length)],
    ];
    var h = HoldemHand.deal(
      stacks: List.filled(seats, 1000),
      button: hand % seats,
      deck: const CardDeckFactory().createShuffledDeck(random: random),
      smallBlind: 5,
      bigBlind: 10,
    );
    final putIn = List.filled(seats, false);
    while (h.isInPlay) {
      final seat = h.toAct;
      final decision = decideHoldemAction(
        HoldemAiView.of(h),
        style: styles[seat],
        difficulty: levels[seat],
        random: random,
      );
      if (h.street == HoldemStreet.preflop &&
          decision.kind != HoldemDecisionKind.fold &&
          !(decision.kind == HoldemDecisionKind.checkOrCall && h.canCheck)) {
        putIn[seat] = true;
      }
      h = h.act(decision);
    }
    if (h.showdown) showdowns++;
    for (var i = 0; i < seats; i++) {
      net[levels[i]] = net[levels[i]]! + h.seats[i].stack - 1000;
      dealt[levels[i]] = dealt[levels[i]]! + 1;
      if (putIn[i]) voluntary[levels[i]] = voluntary[levels[i]]! + 1;
    }
  }
  String pct(int x, int of) => '${(100 * x / of).toStringAsFixed(1)}%';
  String bb100(HoldemDifficulty d) =>
      (net[d]! / 10 / dealt[d]! * 100).toStringAsFixed(1);
  print(
    '${a.name} vs ${b.name}, $seats seats, $hands hands: '
    'showdowns ${pct(showdowns, hands)}; '
    '${a.name} plays ${pct(voluntary[a]!, dealt[a]!)} '
    '(${bb100(a)} bb/100), '
    '${b.name} plays ${pct(voluntary[b]!, dealt[b]!)} '
    '(${bb100(b)} bb/100)',
  );
}

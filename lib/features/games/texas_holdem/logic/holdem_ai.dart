import 'dart:math';

import '../../../../core/cards/playing_card.dart';
import 'holdem_evaluator.dart';
import 'holdem_hand.dart';

/// How well the computer opponents play. Every level follows the same rules
/// and sees only its own cards; harder levels just judge them better.
enum HoldemDifficulty {
  easy(
    label: 'Easy',
    subtitle: 'Loose, passive opponents who call too much and rarely bluff',
    iterations: 120,
    noise: 0.10,
    respect: 0,
    looseness: 0.08,
    aggression: 0.6,
    bluffing: 0.4,
  ),
  normal(
    label: 'Normal',
    subtitle: 'A mix of styles that bet strong hands and bluff now and then',
    iterations: 250,
    noise: 0.05,
    respect: 0.12,
    looseness: 0,
    aggression: 1,
    bluffing: 1,
  ),
  hard(
    label: 'Hard',
    subtitle: 'Sharper reads of their odds, more pressure and bluffs',
    iterations: 500,
    noise: 0.02,
    respect: 0.2,
    looseness: -0.02,
    aggression: 1.15,
    bluffing: 1.4,
  );

  const HoldemDifficulty({
    required this.label,
    required this.subtitle,
    required this.iterations,
    required this.noise,
    required this.respect,
    required this.looseness,
    required this.aggression,
    required this.bluffing,
  });

  final String label;
  final String subtitle;

  /// Random deals used to estimate the chance of winning.
  final int iterations;

  /// Random error added to that estimate (± this much).
  final double noise;

  /// How much a bet facing them lowers their estimate, as bettors usually
  /// hold better than a random hand. Easy opponents ignore it.
  final double respect;

  /// Added to their estimate when deciding whether to call.
  final double looseness;

  /// Scales how often they raise with a strong hand, and how often they
  /// bluff.
  final double aggression;
  final double bluffing;

  static HoldemDifficulty? byName(String? name) =>
      values.where((d) => d.name == name).firstOrNull;
}

/// Each opponent's personality, picked at random when they sit down.
enum HoldemStyle {
  /// Tight and passive: plays few hands, rarely raises.
  rock(raiseLevel: 1.45, aggression: 0.5, looseness: -0.03, bluff: 0.03),

  /// Tight and aggressive: plays good hands hard.
  shark(raiseLevel: 1.3, aggression: 0.8, looseness: 0, bluff: 0.08),

  /// Loose and aggressive: raises and bluffs a lot.
  maniac(raiseLevel: 1.15, aggression: 0.9, looseness: 0.04, bluff: 0.18),

  /// Loose and passive: calls with almost anything.
  station(raiseLevel: 1.5, aggression: 0.35, looseness: 0.07, bluff: 0.02);

  const HoldemStyle({
    required this.raiseLevel,
    required this.aggression,
    required this.looseness,
    required this.bluff,
  });

  /// Heads-up hand strength (chance of winning × players) needed to bet or
  /// raise for value; scaled up for more players.
  final double raiseLevel;
  final double aggression;
  final double looseness;
  final double bluff;
}

/// Everything a computer opponent may know when it acts: its own hole
/// cards, the board and the betting. Other players' cards and the deck are
/// deliberately left out.
class HoldemAiView {
  const HoldemAiView({
    required this.hole,
    required this.board,
    required this.pot,
    required this.toCall,
    required this.streetBet,
    required this.currentBet,
    required this.canRaise,
    required this.minRaiseTo,
    required this.maxRaiseTo,
    required this.opponentsLive,
    required this.bigBlind,
  });

  factory HoldemAiView.of(HoldemHand hand) {
    final seat = hand.actingSeat;
    if (seat == null) throw StateError('Nobody is to act');
    return HoldemAiView(
      hole: seat.hole,
      board: hand.board,
      pot: hand.pot,
      toCall: hand.toCall,
      streetBet: seat.streetBet,
      currentBet: hand.currentBet,
      canRaise: hand.canRaise,
      minRaiseTo: hand.minRaiseTo,
      maxRaiseTo: hand.maxRaiseTo,
      opponentsLive: hand.liveCount - 1,
      bigBlind: hand.bigBlind,
    );
  }

  final List<PlayingCard> hole;
  final List<PlayingCard> board;
  final int pot;
  final int toCall;
  final int streetBet;
  final int currentBet;
  final bool canRaise;
  final int minRaiseTo;
  final int maxRaiseTo;
  final int opponentsLive;
  final int bigBlind;

  bool get preflop => board.isEmpty;
}

/// Picks a computer opponent's action. It estimates its chance of winning
/// by dealing out random hands for the unseen cards, then compares that
/// with the price of calling and its style's thresholds. [random] only
/// drives this estimate and the opponent's choices; it never touches the
/// deck.
HoldemDecision decideHoldemAction(
  HoldemAiView view, {
  required HoldemStyle style,
  required HoldemDifficulty difficulty,
  required Random random,
}) {
  final opponents = max(1, view.opponentsLive);
  final players = opponents + 1;
  var equity = holdemEquity(
    hole: view.hole,
    board: view.board,
    opponents: opponents,
    iterations: difficulty.iterations,
    random: random,
  );
  equity += difficulty.noise * (random.nextDouble() * 2 - 1);

  final potBefore = max(view.pot, view.bigBlind);
  final pressure = min(1.0, view.toCall / potBefore);
  equity = (equity * (1 - difficulty.respect * pressure)).clamp(0.0, 1.0);

  // 1 = an average hand for this many players.
  final strength = equity * players;
  final valueLevel =
      1 + (style.raiseLevel - 1) * pow(players / 2, 0.8).toDouble();
  final aggression = min(1.0, style.aggression * difficulty.aggression);
  final bluff = style.bluff * difficulty.bluffing * (opponents <= 2 ? 1 : 0.3);

  if (view.toCall == 0) {
    if (view.canRaise) {
      if (strength >= valueLevel && random.nextDouble() < aggression) {
        return HoldemDecision.raiseTo(_sizeBet(view, equity, random));
      }
      if (!view.preflop && random.nextDouble() < bluff) {
        return HoldemDecision.raiseTo(_sizeBet(view, equity, random));
      }
    }
    return const HoldemDecision.checkOrCall();
  }

  // Facing a bet bigger than the pot, re-raising needs a stronger hand.
  final reraiseLevel = valueLevel + 0.25 + (pressure >= 1 ? 0.5 : 0);
  if (view.canRaise &&
      strength >= reraiseLevel &&
      random.nextDouble() < aggression) {
    return HoldemDecision.raiseTo(_sizeBet(view, equity, random));
  }
  // The share of the final pot a call must win to pay, counting on some of
  // the other players calling too.
  final need =
      view.toCall /
      (view.pot + view.toCall + view.toCall * 0.5 * (opponents - 1));
  if (equity + style.looseness + difficulty.looseness >= need) {
    return const HoldemDecision.checkOrCall();
  }
  if (view.canRaise && !view.preflop && random.nextDouble() < bluff * 0.3) {
    return HoldemDecision.raiseTo(_sizeBet(view, equity, random));
  }
  return const HoldemDecision.fold();
}

/// A bet or raise total: about three big blinds (plus the bet faced) before
/// the flop, half to all of the pot after it, rounded to the small blind and
/// kept legal. Most of a stack goes all-in instead.
int _sizeBet(HoldemAiView view, double equity, Random random) {
  final unit = max(1, view.bigBlind ~/ 2);
  int target;
  if (view.preflop) {
    target = view.currentBet * 3 + random.nextInt(2) * view.bigBlind;
  } else {
    const fractions = [0.5, 0.66, 0.75, 1.0];
    final fraction = fractions[random.nextInt(fractions.length)];
    target = view.currentBet + ((view.pot + view.toCall) * fraction).round();
  }
  target = (target / unit).round() * unit;
  target = target.clamp(view.minRaiseTo, view.maxRaiseTo);
  // A very strong hand sometimes just moves in.
  if (target >= view.maxRaiseTo * 0.6 ||
      (equity > 0.85 && random.nextDouble() < 0.25)) {
    return view.maxRaiseTo;
  }
  return target;
}

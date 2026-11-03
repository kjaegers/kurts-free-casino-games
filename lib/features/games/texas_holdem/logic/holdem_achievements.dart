import 'holdem_evaluator.dart';
import 'holdem_hand.dart';

/// Texas Hold'em's achievement IDs. These are persistence keys: never rename
/// one after it has shipped.
abstract final class HoldemAchievementIds {
  static const String knockout = 'texas_holdem.knockout';
  static const String bluff = 'texas_holdem.bluff';
  static const String quads = 'texas_holdem.quads';
  static const String straightFlush = 'texas_holdem.straight_flush';
  static const String everyDifficulty = 'texas_holdem.every_difficulty';
}

/// Whether the player (seat 0) collected any pot this hand (chips handed
/// back because nobody matched them don't count).
bool holdemPlayerWonPot(HoldemHand hand) =>
    hand.isComplete && hand.pots.any((p) => p.winners.contains(0));

/// The achievements a completed hand earns the player. They reward how the
/// hand was played, never the size of the pot or the balance.
Set<String> checkHoldemAchievements(HoldemHand hand) {
  if (!hand.isComplete || !holdemPlayerWonPot(hand)) return const {};
  final player = hand.seats[0];
  final category = hand.board.length >= 3
      ? holdemCategoryOf(hand.scoreOf(0))
      : null;
  final wonPots = hand.pots.where((p) => p.winners.contains(0));
  return {
    // An opponent who had chips in a pot the player won and is left with
    // none.
    for (final pot in wonPots)
      for (final seat in pot.eligible)
        if (seat != 0 && hand.seats[seat].stack == 0)
          HoldemAchievementIds.knockout,
    // Everyone folded to the player's bet after the flop while the player
    // held no more than high card.
    if (!hand.showdown &&
        hand.lastAggressor == 0 &&
        player.isLive &&
        category == HoldemHandCategory.highCard)
      HoldemAchievementIds.bluff,
    if (hand.showdown && category == HoldemHandCategory.fourOfAKind)
      HoldemAchievementIds.quads,
    if (hand.showdown && category == HoldemHandCategory.straightFlush)
      HoldemAchievementIds.straightFlush,
  };
}

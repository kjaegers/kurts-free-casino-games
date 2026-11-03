import 'blackjack_game.dart';
import 'blackjack_hand.dart';

/// Blackjack's achievement IDs. These are persistence keys: never rename
/// one after it has shipped.
abstract final class BlackjackAchievementIds {
  static const String natural = 'blackjack.natural';
  static const String doubleDown = 'blackjack.double_down';
  static const String fiveCardTwentyOne = 'blackjack.five_card_21';
  static const String fourHands = 'blackjack.four_hands';
  static const String cleanSweep = 'blackjack.clean_sweep';
}

/// The achievements a completed round earns. They reward how the round was
/// played, never the size of the bet or the balance.
Set<String> checkBlackjackAchievements(BlackjackGame game) {
  if (!game.isComplete) return const {};
  final outcomes = [for (final h in game.hands) game.outcomeOf(h)];
  bool won(BlackjackOutcome o) =>
      o == BlackjackOutcome.win || o == BlackjackOutcome.blackjack;
  return {
    if (outcomes.contains(BlackjackOutcome.blackjack))
      BlackjackAchievementIds.natural,
    for (var i = 0; i < game.hands.length; i++)
      if (game.hands[i].doubled && won(outcomes[i]))
        BlackjackAchievementIds.doubleDown,
    if (game.hands.any((h) => h.total == 21 && h.cards.length >= 5))
      BlackjackAchievementIds.fiveCardTwentyOne,
    if (game.hands.length == blackjackMaxHands)
      BlackjackAchievementIds.fourHands,
    if (game.hands.length > 1 && outcomes.every(won))
      BlackjackAchievementIds.cleanSweep,
  };
}

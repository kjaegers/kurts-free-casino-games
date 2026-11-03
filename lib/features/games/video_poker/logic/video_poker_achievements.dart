import 'video_poker_game.dart';
import 'video_poker_variant.dart';

/// Video Poker's achievement IDs. These are persistence keys: never rename
/// one after it has shipped.
abstract final class VideoPokerAchievementIds {
  static const String fourOfAKind = 'video_poker.four_of_a_kind';
  static const String straightFlush = 'video_poker.straight_flush';
  static const String fiveOfAKind = 'video_poker.five_of_a_kind';
  static const String fourDeuces = 'video_poker.four_deuces';
  static const String royalFlush = 'video_poker.royal_flush';
  static const String everyVariant = 'video_poker.every_variant';
}

/// What a completed hand earns: [earned] achievement IDs, plus the
/// variant to add to Every Variant's progress when the hand paid.
class VideoPokerAchievementCheck {
  const VideoPokerAchievementCheck({required this.earned, this.paidVariant});

  final Set<String> earned;
  final String? paidVariant;
}

/// Checks a completed hand. They reward the hands themselves, never the
/// size of the bet or the balance. [variantsPaid] are the variant names
/// already recorded for Every Variant (not including this hand).
VideoPokerAchievementCheck checkVideoPokerAchievements({
  required VideoPokerGame game,
  required Set<String> variantsPaid,
}) {
  if (!game.isComplete) return const VideoPokerAchievementCheck(earned: {});
  final hand = game.result;
  final paid = game.payout > 0;
  final variants = {...variantsPaid, if (paid) game.variant.name};
  final everyVariant = VideoPokerVariant.values.every(
    (v) => variants.contains(v.name),
  );
  return VideoPokerAchievementCheck(
    earned: {
      if (hand == VideoPokerHand.fourOfAKind)
        VideoPokerAchievementIds.fourOfAKind,
      if (hand == VideoPokerHand.straightFlush)
        VideoPokerAchievementIds.straightFlush,
      if (hand == VideoPokerHand.fiveOfAKind)
        VideoPokerAchievementIds.fiveOfAKind,
      if (hand == VideoPokerHand.fourDeuces)
        VideoPokerAchievementIds.fourDeuces,
      if (hand == VideoPokerHand.royalFlush)
        VideoPokerAchievementIds.royalFlush,
      if (everyVariant) VideoPokerAchievementIds.everyVariant,
    },
    paidVariant: paid ? game.variant.name : null,
  );
}

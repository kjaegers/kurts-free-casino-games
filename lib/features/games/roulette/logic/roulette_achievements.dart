import 'roulette_bets.dart';
import 'roulette_game.dart';

/// Roulette's achievement IDs. These are persistence keys: never rename
/// one after it has shipped.
abstract final class RouletteAchievementIds {
  static const String straightUp = 'roulette.straight_up';
  static const String greenZero = 'roulette.green_zero';
  static const String insideStory = 'roulette.inside_story';
  static const String dejaVu = 'roulette.deja_vu';
}

/// The inside bet kinds that count toward Inside Story.
const Set<RouletteBetKind> rouletteInsideStoryKinds = {
  RouletteBetKind.straight,
  RouletteBetKind.split,
  RouletteBetKind.street,
  RouletteBetKind.corner,
  RouletteBetKind.sixLine,
};

/// What a completed spin earns: [earned] achievement IDs, plus the inside
/// bet kinds it won to add to Inside Story's progress.
class RouletteAchievementCheck {
  const RouletteAchievementCheck({
    required this.earned,
    this.insideKinds = const {},
  });

  final Set<String> earned;
  final Set<String> insideKinds;
}

/// Checks a completed spin. They reward the bets won, never the size of
/// the stake or the balance. [previousPocket] is where the ball landed on
/// the spin before (null when unknown); [insideKindsWon] are the kind names
/// already recorded for Inside Story (not including this spin).
RouletteAchievementCheck checkRouletteAchievements({
  required RouletteGame game,
  required int? previousPocket,
  required Set<String> insideKindsWon,
}) {
  if (!game.isComplete) return const RouletteAchievementCheck(earned: {});
  final wins = game.wins;
  final straightWin = wins.any((w) => w.bet.kind == RouletteBetKind.straight);
  final kinds = {
    for (final w in wins)
      if (rouletteInsideStoryKinds.contains(w.bet.kind)) w.bet.kind.name,
  };
  final allKinds = {...insideKindsWon, ...kinds};
  return RouletteAchievementCheck(
    earned: {
      if (straightWin) RouletteAchievementIds.straightUp,
      if (game.pocket == 0 && wins.isNotEmpty) RouletteAchievementIds.greenZero,
      if (rouletteInsideStoryKinds.every((k) => allKinds.contains(k.name)))
        RouletteAchievementIds.insideStory,
      if (straightWin &&
          previousPocket != null &&
          previousPocket == game.pocket)
        RouletteAchievementIds.dejaVu,
    },
    insideKinds: kinds,
  );
}

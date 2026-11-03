import 'cherry_run_game.dart';
import 'cherry_run_paytable.dart';

/// Cherry Run's achievement IDs. These are persistence keys: never rename
/// one after it has shipped.
abstract final class CherryRunAchievementIds {
  static const String luckySevens = 'slots_cherry_run.lucky_sevens';
  static const String topBar = 'slots_cherry_run.top_bar';
  static const String bellRinger = 'slots_cherry_run.bell_ringer';
  static const String cherryRun = 'slots_cherry_run.cherry_run';
  static const String fruitSalad = 'slots_cherry_run.fruit_salad';
}

/// The three-of-a-kind fruit wins that count toward Fruit Salad.
const Set<CherryRunWin> cherryRunFruitWins = {
  CherryRunWin.threeCherries,
  CherryRunWin.plums,
  CherryRunWin.lemons,
};

/// What a completed spin earns: [earned] achievement IDs, plus the fruit
/// wins to add to Fruit Salad's progress.
class CherryRunAchievementCheck {
  const CherryRunAchievementCheck({
    required this.earned,
    this.fruits = const {},
  });

  final Set<String> earned;
  final Set<String> fruits;
}

/// Checks a completed spin. They reward the lines themselves, never the
/// size of the bet or the balance. [fruitsWon] are the fruit win names
/// already recorded for Fruit Salad (not including this spin).
CherryRunAchievementCheck checkCherryRunAchievements({
  required CherryRunGame game,
  required Set<String> fruitsWon,
}) {
  if (!game.isComplete) return const CherryRunAchievementCheck(earned: {});
  final wins = {for (final w in game.lineWins) w.win};
  final fruits = {
    for (final w in wins)
      if (cherryRunFruitWins.contains(w)) w.name,
  };
  final allFruits = {...fruitsWon, ...fruits};
  return CherryRunAchievementCheck(
    earned: {
      if (wins.contains(CherryRunWin.sevens))
        CherryRunAchievementIds.luckySevens,
      if (wins.contains(CherryRunWin.tripleBars))
        CherryRunAchievementIds.topBar,
      if (wins.contains(CherryRunWin.bells)) CherryRunAchievementIds.bellRinger,
      if (wins.contains(CherryRunWin.threeCherries))
        CherryRunAchievementIds.cherryRun,
      if (cherryRunFruitWins.every((w) => allFruits.contains(w.name)))
        CherryRunAchievementIds.fruitSalad,
    },
    fruits: fruits,
  );
}

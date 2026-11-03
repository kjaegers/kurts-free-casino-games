import 'retro_tech_game.dart';
import 'retro_tech_symbols.dart';

/// Retro Tech's achievement IDs. These are persistence keys: never rename
/// one after it has shipped.
abstract final class RetroTechAchievementIds {
  static const String tokenRush = 'slots_retro_tech.token_rush';
  static const String playerOne = 'slots_retro_tech.player_one';
  static const String chainReaction = 'slots_retro_tech.chain_reaction';
  static const String megaCluster = 'slots_retro_tech.mega_cluster';
  static const String fullCollection = 'slots_retro_tech.full_collection';
}

/// Paying cascades in one spin that earn Chain Reaction.
const int retroTechChainReactionCascades = 4;

/// The cluster size that earns Mega Cluster.
const int retroTechMegaClusterSize = 11;

/// What a completed spin earns: [earned] achievement IDs, plus the symbols
/// to add to Full Collection's progress.
class RetroTechAchievementCheck {
  const RetroTechAchievementCheck({
    required this.earned,
    this.symbols = const {},
  });

  final Set<String> earned;
  final Set<String> symbols;
}

/// Checks a completed spin. They reward what the grid does, never the size
/// of the bet or the balance. [symbolsWon] are the symbol names already
/// recorded for Full Collection (not including this spin).
RetroTechAchievementCheck checkRetroTechAchievements({
  required RetroTechGame game,
  required Set<String> symbolsWon,
}) {
  final result = game.result;
  if (!game.isComplete || result == null) {
    return const RetroTechAchievementCheck(earned: {});
  }
  final clusters = [for (final step in result.steps) ...step.clusters];
  final symbols = {for (final c in clusters) c.symbol.name};
  final all = {...symbolsWon, ...symbols};
  return RetroTechAchievementCheck(
    earned: {
      if (symbols.contains(RetroTechSymbol.token.name))
        RetroTechAchievementIds.tokenRush,
      if (symbols.contains(RetroTechSymbol.runner.name))
        RetroTechAchievementIds.playerOne,
      if (result.cascades >= retroTechChainReactionCascades)
        RetroTechAchievementIds.chainReaction,
      if (clusters.any((c) => c.size >= retroTechMegaClusterSize))
        RetroTechAchievementIds.megaCluster,
      if (RetroTechSymbol.values.every((s) => all.contains(s.name)))
        RetroTechAchievementIds.fullCollection,
    },
    symbols: symbols,
  );
}

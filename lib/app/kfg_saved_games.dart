import '../core/services/persistent_storage.dart';

/// Registry of every storage key under which a game keeps saved progress,
/// so Settings > Clear Saved Games can find and remove all of it.
///
/// Statistics, favourites and settings are deliberately not listed here:
/// they have their own reset paths.
///
/// When a game adds a save, register its key (or key prefix, for saves that
/// are stored one-per-day) below. `test/core/kfg_saved_games_test.dart`
/// fails if a save written through [persistentStorage] is left out.
abstract final class KfgSavedGames {
  /// Keys that each hold one game's in-progress save.
  static const List<String> keys = [
    'kfcg_video_poker_save_v1',
    'kfcg_slots_cherry_run_save_v1',
    'kfcg_slots_retro_tech_save_v1',
    'kfcg_blackjack_save_v1',
    'kfcg_roulette_save_v1',
    'kfcg_texas_holdem_save_v1',
  ];

  /// Prefixes of keys stored once per calendar day.
  static const List<String> keyPrefixes = [];

  /// Whether [key] belongs to a registered save.
  static bool isSaveKey(String key) =>
      keys.contains(key) || keyPrefixes.any(key.startsWith);

  /// Removes every registered save. Returns the keys that were removed.
  static Future<Set<String>> clearAll({PersistentStorage? storage}) async {
    final store = storage ?? persistentStorage;
    final targets = {
      ...keys,
      ...(await store.getKeys()).where(
        (key) => keyPrefixes.any(key.startsWith),
      ),
    };
    for (final key in targets) {
      await store.remove(key);
    }
    return targets;
  }
}

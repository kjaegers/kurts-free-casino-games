import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_saved_games.dart';
import 'package:kurts_free_casino_games/core/services/favorites_service.dart';
import 'package:kurts_free_casino_games/core/services/settings_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('KfgSavedGames', () {
    test('clearAll removes every registered save and dated save', () async {
      final dated = [
        for (final prefix in KfgSavedGames.keyPrefixes) '${prefix}2026-10-13',
      ];
      SharedPreferences.setMockInitialValues({
        for (final key in KfgSavedGames.keys) key: '{"saved":true}',
        for (final key in dated) key: '{"saved":true}',
        StatsService.storageKey: '{}',
        FavoritesService.storageKey: '[]',
        SettingsService.storageKey: '{}',
      });

      final removed = await KfgSavedGames.clearAll();

      expect(removed, containsAll([...KfgSavedGames.keys, ...dated]));
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getKeys(), {
        StatsService.storageKey,
        FavoritesService.storageKey,
        SettingsService.storageKey,
      });
    });

    // Add each game's save key literal here when it registers a save, so a
    // renamed key (which would orphan players' saves) fails a test.
    test('covers every known save key', () {
      expect(
        KfgSavedGames.keys,
        containsAll(<String>[
          'kfcg_video_poker_save_v1',
          'kfcg_slots_cherry_run_save_v1',
          'kfcg_slots_retro_tech_save_v1',
          'kfcg_blackjack_save_v1',
          'kfcg_roulette_save_v1',
          'kfcg_texas_holdem_save_v1',
        ]),
      );
      expect(KfgSavedGames.keyPrefixes, containsAll(<String>[]));
    });

    // Guards against a new game adding a save without registering it: every
    // storage-key constant declared next to a persistentStorage write in a
    // game's code must be a registered save.
    test('every storage key declared by a game is registered', () {
      final keyConstant = RegExp(
        r"static const String (\w*(?:[kK]ey|[pP]refix)) =\s*'([^']+)'",
      );
      final unregistered = <String>[];
      final gamesDir = Directory('lib/features/games');
      if (!gamesDir.existsSync()) return;
      final gameFiles = gamesDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in gameFiles) {
        final source = file.readAsStringSync();
        if (!source.contains('persistentStorage') &&
            !source.contains('PersistentStorage')) {
          continue;
        }
        for (final match in keyConstant.allMatches(source)) {
          final value = match.group(2)!;
          if (!KfgSavedGames.isSaveKey(value) &&
              !KfgSavedGames.keyPrefixes.contains(value)) {
            unregistered.add('${file.path}: ${match.group(1)} = $value');
          }
        }
      }
      expect(unregistered, isEmpty);
    });
  });
}

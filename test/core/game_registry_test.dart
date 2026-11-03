import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_router.dart';
import 'package:kurts_free_casino_games/core/achievements/achievement_catalog.dart';
import 'package:kurts_free_casino_games/core/models/game_definition.dart';
import 'package:kurts_free_casino_games/core/services/game_registry.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Game registry', () {
    test('ids are unique and every route is a /game/ route', () {
      final games = GameRegistry.instance.games;
      final ids = games.map((g) => g.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final game in games) {
        // /game/ routes get the clamped game text scale.
        expect(game.routeName, startsWith('/game/'), reason: game.id);
        expect(game.title, isNotEmpty, reason: game.id);
        expect(game.description, isNotEmpty, reason: game.id);
      }
    });

    test('every ready id belongs to a registered game', () {
      final ids = GameRegistry.instance.games.map((g) => g.id).toSet();
      expect(ids, containsAll(kReadyPlayableGameIds));
    });

    testWidgets('every registered route opens a page', (tester) async {
      SharedPreferences.setMockInitialValues({});
      for (final game in GameRegistry.instance.games) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(game.id),
            onGenerateRoute: KfgRouter.onGenerateRoute,
            initialRoute: game.routeName,
          ),
        );
        await tester.pump();
        expect(find.text('Page not found'), findsNothing, reason: game.id);
      }
    });

    testWidgets('an unknown route shows Page not found', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: KfgRouter.onGenerateRoute,
          initialRoute: '/game/not-a-game',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page not found'), findsOneWidget);
    });
  });

  test('achievement IDs are unique and belong to a registered game', () {
    final ids = AchievementCatalog.all.map((a) => a.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    final gameIds = GameRegistry.instance.games.map((g) => g.id).toSet();
    for (final a in AchievementCatalog.all) {
      expect(gameIds, contains(a.gameId), reason: a.id);
      expect(a.id, startsWith('${a.gameId}.'));
      expect(a.title, isNotEmpty);
      expect(a.description, isNotEmpty);
    }
  });

  test('stats key is namespaced apart from Kurt\'s Free Games', () {
    // On web both apps can share an origin, and so localStorage.
    expect(StatsService.storageKey, startsWith('kfcg_'));
  });
}

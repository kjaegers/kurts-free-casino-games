import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_saved_games.dart';
import 'package:kurts_free_casino_games/core/services/settings_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/core/widgets/kfg_settings_scope.dart';
import 'package:kurts_free_casino_games/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    KfgSettingsScope(
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      for (final key in KfgSavedGames.keys) key: '{"saved":true}',
    });
    await StatsService.instance.ensureLoaded(forceReload: true);
    StatsService.instance.reset();
    await SettingsService.instance.ensureLoaded(forceReload: true);
  });

  testWidgets('has no Music toggle', (tester) async {
    await _pumpSettings(tester);
    expect(find.text('Music'), findsNothing);
    expect(find.text('Sound Effects'), findsOneWidget);
    expect(find.text('Haptic Feedback'), findsOneWidget);
    expect(find.text('Large Text'), findsOneWidget);
    expect(find.text('Follow Device'), findsOneWidget);
  });

  testWidgets('toggling a switch updates and persists the setting', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.tap(find.text('Haptic Feedback'));
    await tester.pumpAndSettle();
    expect(SettingsService.instance.settings.hapticsEnabled, isFalse);

    await tester.tap(find.text('Full Neon'));
    await tester.pumpAndSettle();
    expect(
      SettingsService.instance.settings.themeIntensity,
      ThemeIntensity.fullNeon,
    );

    await tester.ensureVisible(find.text('Off'));
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(SettingsService.instance.settings.animations, AnimationsSetting.off);

    await tester.runAsync(() async {
      await SettingsService.instance.saveNowForTest();
      await SettingsService.instance.ensureLoaded(forceReload: true);
    });
    expect(SettingsService.instance.settings.hapticsEnabled, isFalse);
    expect(
      SettingsService.instance.settings.themeIntensity,
      ThemeIntensity.fullNeon,
    );
    expect(SettingsService.instance.settings.animations, AnimationsSetting.off);
  });

  testWidgets('Reset Statistics really clears statistics', (tester) async {
    StatsService.instance.recordGameFinished('blackjack', won: true);
    expect(StatsService.instance.stats.totalGamesPlayed, 1);

    await _pumpSettings(tester);
    await tester.tap(find.text('Reset Statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET'));
    await tester.pumpAndSettle();

    expect(StatsService.instance.stats.totalGamesPlayed, 0);
    expect(find.text('Statistics reset.'), findsOneWidget);

    await tester.runAsync(
      () => StatsService.instance.ensureLoaded(forceReload: true),
    );
    expect(StatsService.instance.stats.totalGamesPlayed, 0);
  });

  testWidgets('cancelling Reset Statistics keeps statistics', (tester) async {
    StatsService.instance.recordGameFinished('blackjack', won: true);

    await _pumpSettings(tester);
    await tester.tap(find.text('Reset Statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(StatsService.instance.stats.totalGamesPlayed, 1);
  });

  testWidgets('Clear Saved Games removes every saved game', (tester) async {
    await _pumpSettings(tester);
    await tester.tap(find.text('Clear Saved Games'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CLEAR'));
    await tester.pumpAndSettle();

    expect(find.text('Saved games cleared.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    for (final key in KfgSavedGames.keys) {
      expect(prefs.getString(key), isNull, reason: key);
    }
  });
}

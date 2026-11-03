import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_app.dart';
import 'package:kurts_free_casino_games/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.ensureLoaded(forceReload: true);
  });

  tearDown(() => SettingsService.instance.update(const AppSettings()));

  for (final width in [320.0, 412.0]) {
    testWidgets('Large Text menus lay out without overflow at ${width}dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, width * 3 * 2.1);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      SettingsService.instance.update(
        const AppSettings(
          largeText: true,
          themeIntensity: ThemeIntensity.fullNeon,
        ),
      );

      await tester.pumpWidget(const KfgApp());
      await tester.pumpAndSettle();

      for (final tab in ['Stats', 'Settings', 'About', 'Games']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }
}

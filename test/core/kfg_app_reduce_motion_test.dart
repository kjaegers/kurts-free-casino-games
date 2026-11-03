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

  // Browsers on Windows report reduce motion whenever Windows' "Animation
  // effects" is off; the Animations setting must still win on every screen.
  for (final (setting, expected) in const [
    (AnimationsSetting.on, false),
    (AnimationsSetting.off, true),
    (AnimationsSetting.followDevice, true),
  ]) {
    testWidgets('screens see disableAnimations $expected when Animations is '
        '${setting.name} and the device asks to reduce motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      SettingsService.instance.update(AppSettings(animations: setting));

      await tester.pumpWidget(const KfgApp());
      await tester.pumpAndSettle();

      final screen = tester.element(find.byType(Scaffold).first);
      expect(MediaQuery.disableAnimationsOf(screen), expected);
    });
  }
}

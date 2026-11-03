import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/animation/kfg_web_animation_speed.dart';
import 'package:kurts_free_casino_games/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const duration = Duration(milliseconds: 200);

  tearDown(() {
    debugKfgReduceMotionOverride = null;
    SettingsService.instance.update(const AppSettings());
  });

  test('the Animations setting overrides the device', () {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService.instance;
    final device =
        PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;

    expect(kfgReduceMotion, device, reason: 'follows the device');
    settings.update(const AppSettings(animations: AnimationsSetting.on));
    expect(kfgReduceMotion, isFalse);
    expect(kfgAnimDuration(duration), duration);
    settings.update(const AppSettings(animations: AnimationsSetting.off));
    expect(kfgReduceMotion, isTrue);
    expect(kfgAnimDuration(duration), Duration.zero);
  });

  test('passes durations through when motion is allowed', () {
    debugKfgReduceMotionOverride = false;
    // Tests run on the VM, never web, so no web stretch applies.
    expect(kfgAnimDuration(duration), duration);
  });

  test('collapses durations to zero when reduced motion is requested', () {
    debugKfgReduceMotionOverride = true;
    expect(kfgAnimDuration(duration), Duration.zero);
  });

  testWidgets('kfgAnimDurationOf honours MediaQuery.disableAnimations', (
    tester,
  ) async {
    debugKfgReduceMotionOverride = false;
    late Duration reduced;
    late Duration normal;
    await tester.pumpWidget(
      Column(
        children: [
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reduced = kfgAnimDurationOf(context, duration);
                return const SizedBox();
              },
            ),
          ),
          MediaQuery(
            data: const MediaQueryData(),
            child: Builder(
              builder: (context) {
                normal = kfgAnimDurationOf(context, duration);
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
    expect(reduced, Duration.zero);
    expect(normal, duration);
  });
}

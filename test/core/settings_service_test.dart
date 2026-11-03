import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService persistence', () {
    final service = SettingsService.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await service.ensureLoaded(forceReload: true);
    });

    test('defaults when nothing is stored', () {
      final s = service.settings;
      expect(s.soundEnabled, isTrue);
      expect(s.hapticsEnabled, isTrue);
      expect(s.themeIntensity, ThemeIntensity.normal);
      expect(s.largeText, isFalse);
      expect(s.animations, AnimationsSetting.followDevice);
    });

    test('round-trips every setting through storage', () async {
      service.update(
        const AppSettings(
          soundEnabled: false,
          hapticsEnabled: false,
          themeIntensity: ThemeIntensity.fullNeon,
          largeText: true,
          animations: AnimationsSetting.on,
        ),
      );
      await service.saveNowForTest();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(SettingsService.storageKey);
      expect(raw, isNotNull);
      expect(jsonDecode(raw!), {
        'soundEnabled': false,
        'hapticsEnabled': false,
        'themeIntensity': 'fullNeon',
        'largeText': true,
        'animations': 'on',
      });

      // Simulate a fresh launch: reset memory (letting its own save of the
      // defaults finish), then restore the stored copy and reload it.
      service.update(const AppSettings());
      await pumpEventQueue();
      expect(service.settings.soundEnabled, isTrue);
      await prefs.setString(SettingsService.storageKey, raw);
      await service.ensureLoaded(forceReload: true);

      final s = service.settings;
      expect(s.soundEnabled, isFalse);
      expect(s.hapticsEnabled, isFalse);
      expect(s.themeIntensity, ThemeIntensity.fullNeon);
      expect(s.largeText, isTrue);
      expect(s.animations, AnimationsSetting.on);
    });

    test('corrupt JSON falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({
        SettingsService.storageKey: '{not json',
      });
      await service.ensureLoaded(forceReload: true);

      final s = service.settings;
      expect(s.soundEnabled, isTrue);
      expect(s.hapticsEnabled, isTrue);
      expect(s.themeIntensity, ThemeIntensity.normal);
      expect(s.largeText, isFalse);
    });

    test('wrong types fall back per field and keep valid ones', () async {
      SharedPreferences.setMockInitialValues({
        SettingsService.storageKey: jsonEncode({
          'soundEnabled': 'yes',
          'hapticsEnabled': false,
          'themeIntensity': 'blinding',
          'largeText': 1,
          'animations': 'sometimes',
          // Left over from builds that had a Music toggle.
          'musicEnabled': false,
        }),
      });
      await service.ensureLoaded(forceReload: true);

      final s = service.settings;
      expect(s.soundEnabled, isTrue);
      expect(s.hapticsEnabled, isFalse);
      expect(s.themeIntensity, ThemeIntensity.normal);
      expect(s.largeText, isFalse);
      expect(s.animations, AnimationsSetting.followDevice);
    });

    test('a non-object JSON value falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({
        SettingsService.storageKey: '[1, 2, 3]',
      });
      await service.ensureLoaded(forceReload: true);
      expect(service.settings.hapticsEnabled, isTrue);
    });
  });
}

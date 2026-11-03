import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'persistent_storage.dart';

/// Intensity of the neon glow drawn around cards and buttons.
enum ThemeIntensity {
  subtle(0.35),
  normal(1.0),
  fullNeon(1.8);

  const ThemeIntensity(this.glowScale);

  /// Multiplier applied to glow opacity and blur radius.
  final double glowScale;
}

/// Whether animations play: as the device's reduce-motion setting says, or
/// always on or off whatever it says.
enum AnimationsSetting { followDevice, on, off }

/// Snapshot of all user-configurable settings.
class AppSettings {
  const AppSettings({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.themeIntensity = ThemeIntensity.normal,
    this.largeText = false,
    this.animations = AnimationsSetting.followDevice,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;
  final ThemeIntensity themeIntensity;

  /// Enlarges text on menu, stats and settings screens. Game boards keep
  /// their own fitted sizing so they never overflow.
  final bool largeText;

  /// Overrides the device's reduce-motion setting when not
  /// [AnimationsSetting.followDevice]. Browsers on Windows, for one, report
  /// reduce motion whenever Windows' "Animation effects" is off.
  final AnimationsSetting animations;

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    ThemeIntensity? themeIntensity,
    bool? largeText,
    AnimationsSetting? animations,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      themeIntensity: themeIntensity ?? this.themeIntensity,
      largeText: largeText ?? this.largeText,
      animations: animations ?? this.animations,
    );
  }

  Map<String, dynamic> toJson() => {
    'soundEnabled': soundEnabled,
    'hapticsEnabled': hapticsEnabled,
    'themeIntensity': themeIntensity.name,
    'largeText': largeText,
    'animations': animations.name,
  };

  /// Parses [raw] leniently: anything missing or malformed falls back to its
  /// default rather than discarding the other settings.
  factory AppSettings.fromJson(Object? raw) {
    const defaults = AppSettings();
    if (raw is! Map) return defaults;

    bool readBool(String key, bool fallback) {
      final value = raw[key];
      return value is bool ? value : fallback;
    }

    final intensityName = raw['themeIntensity'];
    final animationsName = raw['animations'];
    return AppSettings(
      soundEnabled: readBool('soundEnabled', defaults.soundEnabled),
      hapticsEnabled: readBool('hapticsEnabled', defaults.hapticsEnabled),
      themeIntensity: ThemeIntensity.values.firstWhere(
        (v) => v.name == intensityName,
        orElse: () => defaults.themeIntensity,
      ),
      largeText: readBool('largeText', defaults.largeText),
      animations: AnimationsSetting.values.firstWhere(
        (v) => v.name == animationsName,
        orElse: () => defaults.animations,
      ),
    );
  }
}

/// Manages app-wide settings, persisted locally under [storageKey].
class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  @visibleForTesting
  static const String storageKey = 'kfcg_settings_v1';

  AppSettings _settings = const AppSettings();
  Future<void>? _loadFuture;
  bool _loaded = false;

  /// Set when the player changes a setting before the stored copy finished
  /// loading, so the late load doesn't overwrite their choice.
  bool _changedBeforeLoad = false;

  AppSettings get settings => _settings;

  /// Loads persisted settings. Safe to call multiple times; [forceReload]
  /// re-reads storage (used by tests).
  Future<void> ensureLoaded({bool forceReload = false}) async {
    if (forceReload) {
      _loaded = false;
      _loadFuture = null;
      _changedBeforeLoad = false;
    }
    if (_loaded) return;
    _loadFuture ??= _loadFromStorage();
    await _loadFuture;
  }

  void update(AppSettings newSettings) {
    if (!_loaded) _changedBeforeLoad = true;
    _settings = newSettings;
    notifyListeners();
    unawaited(_saveToStorage());
  }

  @visibleForTesting
  Future<void> saveNowForTest() => _saveToStorage();

  Future<void> _saveToStorage() async {
    try {
      await persistentStorage.setString(
        storageKey,
        jsonEncode(_settings.toJson()),
      );
    } catch (e, st) {
      debugPrint('SettingsService: failed to save settings: $e\n$st');
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final raw = await persistentStorage.getString(storageKey);
      if (raw != null && raw.isNotEmpty && !_changedBeforeLoad) {
        _settings = AppSettings.fromJson(jsonDecode(raw));
      } else if (!_changedBeforeLoad) {
        _settings = const AppSettings();
      }
    } catch (e, st) {
      debugPrint('SettingsService: failed to load settings: $e\n$st');
      if (!_changedBeforeLoad) _settings = const AppSettings();
    } finally {
      _loaded = true;
      _loadFuture = null;
      notifyListeners();
    }
  }
}

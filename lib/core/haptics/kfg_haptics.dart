import 'package:flutter/services.dart';

import '../services/settings_service.dart';

/// Haptic feedback that respects Settings > Haptic Feedback.
///
/// Use these instead of calling [HapticFeedback] directly so turning haptics
/// off actually silences them everywhere.
abstract final class KfgHaptics {
  static bool get _enabled => SettingsService.instance.settings.hapticsEnabled;

  static Future<void> selection() async {
    if (_enabled) await HapticFeedback.selectionClick();
  }

  static Future<void> light() async {
    if (_enabled) await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (_enabled) await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    if (_enabled) await HapticFeedback.heavyImpact();
  }
}

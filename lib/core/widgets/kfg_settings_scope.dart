import 'package:flutter/widgets.dart';

import '../services/settings_service.dart';

/// Makes [SettingsService] changes rebuild the widgets that read settings
/// through [KfgSettingsScope.of], so a toggle takes effect immediately on
/// every screen, not only the next time a screen is built.
class KfgSettingsScope extends InheritedNotifier<SettingsService> {
  KfgSettingsScope({super.key, required super.child})
    : super(notifier: SettingsService.instance);

  /// Current settings, registering [context] for rebuilds when they change.
  /// Falls back to the service directly when no scope is present (e.g. in
  /// isolated widget tests).
  static AppSettings of(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<KfgSettingsScope>();
    return SettingsService.instance.settings;
  }
}

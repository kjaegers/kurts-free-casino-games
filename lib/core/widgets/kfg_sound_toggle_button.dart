import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// The standard game AppBar action that flips the app-wide Sound Effects
/// setting. Rebuilds whenever the setting changes, including from Settings.
class KfgSoundToggleButton extends StatelessWidget {
  const KfgSoundToggleButton({super.key});

  static void toggle() {
    final settings = SettingsService.instance;
    settings.update(
      settings.settings.copyWith(soundEnabled: !settings.settings.soundEnabled),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        final on = SettingsService.instance.settings.soundEnabled;
        return IconButton(
          tooltip: on ? 'Sound on (tap to mute)' : 'Sound off',
          icon: Icon(on ? Icons.volume_up : Icons.volume_off),
          onPressed: toggle,
        );
      },
    );
  }
}

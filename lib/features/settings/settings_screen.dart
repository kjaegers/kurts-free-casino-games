import 'package:flutter/material.dart';

import '../../app/kfg_saved_games.dart';
import '../../app/kfg_theme.dart';
import '../../core/services/credits_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/stats_service.dart';
import '../../core/widgets/kfg_confirm_dialog.dart';
import '../../core/widgets/kfg_neon_button.dart';
import '../../core/widgets/kfg_neon_card.dart';
import '../../core/widgets/kfg_section_header.dart';
import '../../core/widgets/kfg_settings_scope.dart';

/// App settings screen shown on the Settings tab.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _update(AppSettings updated) {
    SettingsService.instance.update(updated);
  }

  Future<void> _resetStatistics(BuildContext context) async {
    final confirmed = await showKfgConfirmDialog(
      context,
      title: 'Reset Statistics?',
      message:
          'All game statistics and achievements will be cleared. '
          'This cannot be undone.',
      confirmLabel: 'RESET',
      confirmColor: KfgColors.error,
    );
    if (!confirmed) return;
    StatsService.instance.reset();
    await StatsService.instance.saveNow();
    if (context.mounted) _showDone(context, 'Statistics reset.');
  }

  Future<void> _resetCredits(BuildContext context) async {
    final confirmed = await showKfgConfirmDialog(
      context,
      title: 'Reset Credits?',
      message:
          'Your credit balance will be set back to '
          '${formatCredits(CreditsService.startingBalance)}. Credits are '
          'play money only.',
      confirmLabel: 'RESET',
      confirmColor: KfgColors.warning,
    );
    if (!confirmed) return;
    CreditsService.instance.reset();
    await CreditsService.instance.saveNow();
    if (context.mounted) _showDone(context, 'Credits reset.');
  }

  Future<void> _clearSavedGames(BuildContext context) async {
    final confirmed = await showKfgConfirmDialog(
      context,
      title: 'Clear Saved Games?',
      message:
          'All saved game progress will be deleted. This cannot be undone.',
      confirmLabel: 'CLEAR',
      confirmColor: KfgColors.error,
    );
    if (!confirmed) return;
    await KfgSavedGames.clearAll();
    if (context.mounted) _showDone(context, 'Saved games cleared.');
  }

  void _showDone(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = KfgSettingsScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(),
          const SizedBox(height: 20),

          // ── Audio ──────────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Audio'),
          const SizedBox(height: 10),
          _SwitchCard(
            label: 'Sound Effects',
            value: settings.soundEnabled,
            onChanged: (v) => _update(settings.copyWith(soundEnabled: v)),
          ),
          const SizedBox(height: 20),

          // ── Feedback ───────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Feedback'),
          const SizedBox(height: 10),
          _SwitchCard(
            label: 'Haptic Feedback',
            value: settings.hapticsEnabled,
            onChanged: (v) => _update(settings.copyWith(hapticsEnabled: v)),
          ),
          const SizedBox(height: 20),

          // ── Display ────────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Display'),
          const SizedBox(height: 10),
          _ThemeIntensityCard(
            value: settings.themeIntensity,
            onChanged: (v) => _update(settings.copyWith(themeIntensity: v)),
          ),
          const SizedBox(height: 8),
          _SwitchCard(
            label: 'Large Text',
            subtitle: 'Menus, stats and settings. Game boards size to fit.',
            value: settings.largeText,
            onChanged: (v) => _update(settings.copyWith(largeText: v)),
          ),
          const SizedBox(height: 8),
          _AnimationsCard(
            value: settings.animations,
            onChanged: (v) => _update(settings.copyWith(animations: v)),
          ),
          const SizedBox(height: 20),

          // ── Data ───────────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Data'),
          const SizedBox(height: 10),
          KfgNeonButton(
            label: 'Reset Statistics',
            icon: Icons.bar_chart,
            color: KfgColors.warning,
            onPressed: () => _resetStatistics(context),
          ),
          const SizedBox(height: 8),
          KfgNeonButton(
            label: 'Reset Credits',
            icon: Icons.toll,
            color: KfgColors.warning,
            onPressed: () => _resetCredits(context),
          ),
          const SizedBox(height: 8),
          KfgNeonButton(
            label: 'Clear Saved Games',
            icon: Icons.delete_outline,
            color: KfgColors.error,
            onPressed: () => _clearSavedGames(context),
          ),
        ],
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  // ignore: unused_element
  const _PageTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'SETTINGS',
      style: TextStyle(
        color: KfgColors.primary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 3,
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return KfgNeonCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          activeThumbColor: KfgColors.primary,
        ),
      ),
    );
  }
}

class _ThemeIntensityCard extends StatelessWidget {
  const _ThemeIntensityCard({required this.value, required this.onChanged});

  final ThemeIntensity value;
  final ValueChanged<ThemeIntensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return KfgNeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neon Intensity', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 2),
          Text(
            'Glow around menu cards and buttons.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeIntensity>(
            segments: const [
              ButtonSegment(
                value: ThemeIntensity.subtle,
                label: Text('Subtle'),
              ),
              ButtonSegment(
                value: ThemeIntensity.normal,
                label: Text('Normal'),
              ),
              ButtonSegment(
                value: ThemeIntensity.fullNeon,
                label: Text('Full Neon'),
              ),
            ],
            selected: {value},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) onChanged(set.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return KfgColors.primary.withValues(alpha: 0.15);
                }
                return KfgColors.surfaceVariant;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return KfgColors.primary;
                }
                return KfgColors.textMuted;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimationsCard extends StatelessWidget {
  const _AnimationsCard({required this.value, required this.onChanged});

  final AnimationsSetting value;
  final ValueChanged<AnimationsSetting> onChanged;

  @override
  Widget build(BuildContext context) {
    return KfgNeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Animations', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 2),
          Text(
            'Spinning reels, dealt cards and other motion. Follow Device '
            'turns them off when the device asks to reduce motion.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<AnimationsSetting>(
            segments: const [
              ButtonSegment(
                value: AnimationsSetting.followDevice,
                label: Text('Follow Device'),
              ),
              ButtonSegment(value: AnimationsSetting.on, label: Text('On')),
              ButtonSegment(value: AnimationsSetting.off, label: Text('Off')),
            ],
            selected: {value},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) onChanged(set.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return KfgColors.primary.withValues(alpha: 0.15);
                }
                return KfgColors.surfaceVariant;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return KfgColors.primary;
                }
                return KfgColors.textMuted;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import '../models/achievement.dart';
import 'kfg_achievements_unlocked.dart';

/// One `label  value` line in a result dialog.
class KfgDialogStat {
  const KfgDialogStat(this.label, this.value);

  final String label;
  final String value;
}

/// Shows the standard end-of-game dialog and resolves once it closes.
///
/// It can't be dismissed by tapping outside. **BACK TO GAMES** closes the
/// dialog and pops the game screen; **NEW GAME** closes it and calls
/// [onNewGame]. Record stats before calling this, at the moment the game
/// ends, not from inside the dialog.
///
/// An optional secondary action (e.g. **REPLAY**) sits before the standard
/// pair; it closes the dialog and calls [onSecondaryAction].
///
/// [newGameLabel] relabels the primary button for games where "new game"
/// means something more specific, e.g. **NEXT LEVEL**.
///
/// [newAchievements] are the achievements this game unlocked for the first
/// time (record them before calling this). When non-empty they're listed
/// in an **Achievements Unlocked** block after the stats.
Future<void> showKfgResultDialog(
  BuildContext context, {
  required bool won,
  required String title,
  required VoidCallback onNewGame,
  String? subtitle,
  IconData? subtitleIcon,
  Color? subtitleIconColor,
  Widget? extraContent,
  List<KfgDialogStat> stats = const [],
  double statLabelWidth = KfgDialogStatRow.defaultLabelWidth,
  Color? accentColor,
  String? secondaryActionLabel,
  VoidCallback? onSecondaryAction,
  String newGameLabel = KfgResultDialog.defaultNewGameLabel,
  List<AchievementDefinition> newAchievements = const [],
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => KfgResultDialog(
      won: won,
      title: title,
      subtitle: subtitle,
      subtitleIcon: subtitleIcon,
      subtitleIconColor: subtitleIconColor,
      extraContent: extraContent,
      stats: stats,
      statLabelWidth: statLabelWidth,
      accentColor: accentColor,
      secondaryActionLabel: secondaryActionLabel,
      newGameLabel: newGameLabel,
      newAchievements: newAchievements,
      onSecondaryAction: onSecondaryAction == null
          ? null
          : () {
              Navigator.of(dialogContext).pop();
              onSecondaryAction();
            },
      onBackToGames: () {
        Navigator.of(dialogContext)
          ..pop()
          ..pop();
      },
      onNewGame: () {
        Navigator.of(dialogContext).pop();
        onNewGame();
      },
    ),
  );
}

/// The standard end-of-game dialog body. Prefer [showKfgResultDialog].
class KfgResultDialog extends StatelessWidget {
  const KfgResultDialog({
    super.key,
    required this.won,
    required this.title,
    required this.onBackToGames,
    required this.onNewGame,
    this.subtitle,
    this.subtitleIcon,
    this.subtitleIconColor,
    this.extraContent,
    this.stats = const [],
    this.statLabelWidth = KfgDialogStatRow.defaultLabelWidth,
    this.accentColor,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.newGameLabel = defaultNewGameLabel,
    this.newAchievements = const [],
  });

  static const String defaultNewGameLabel = 'NEW GAME';

  /// The primary button's label.
  final String newGameLabel;

  /// Picks the success or error accent for the border and title.
  final bool won;

  /// Overrides the [won]-based accent, e.g. a neutral border for games where
  /// not winning isn't a failure.
  final Color? accentColor;

  /// Optional extra action shown before **BACK TO GAMES**.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final String title;
  final VoidCallback onBackToGames;
  final VoidCallback onNewGame;

  /// Short line under the title, prefixed by [subtitleIcon].
  final String? subtitle;

  /// Defaults to a trophy when [won], otherwise a disappointed face.
  final IconData? subtitleIcon;

  /// Defaults to the accent colour.
  final Color? subtitleIconColor;

  /// Game-specific content shown between the subtitle and the stats
  /// (e.g. revealing the secret code).
  final Widget? extraContent;

  final List<KfgDialogStat> stats;
  final double statLabelWidth;

  /// Achievements first unlocked by this game; shown only when non-empty.
  final List<AchievementDefinition> newAchievements;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? (won ? KfgColors.success : KfgColors.error);

    return AlertDialog(
      // Scrolls only when the content can't fit, e.g. on a short landscape
      // screen or with large text.
      scrollable: true,
      backgroundColor: KfgColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null)
            Row(
              children: [
                Icon(
                  subtitleIcon ??
                      (won ? Icons.emoji_events : Icons.sentiment_dissatisfied),
                  size: 18,
                  color: subtitleIconColor ?? accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle!,
                    style: const TextStyle(color: KfgColors.textSecondary),
                  ),
                ),
              ],
            ),
          if (extraContent != null) ...[
            const SizedBox(height: 10),
            extraContent!,
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final stat in stats)
              KfgDialogStatRow(
                label: stat.label,
                value: stat.value,
                labelWidth: statLabelWidth,
              ),
          ],
          if (newAchievements.isNotEmpty) ...[
            const SizedBox(height: 12),
            KfgAchievementsUnlocked(achievements: newAchievements),
          ],
        ],
      ),
      actions: [
        if (secondaryActionLabel != null && onSecondaryAction != null)
          TextButton(
            onPressed: onSecondaryAction,
            child: Text(secondaryActionLabel!),
          ),
        TextButton(
          onPressed: onBackToGames,
          child: const Text('BACK TO GAMES'),
        ),
        FilledButton(onPressed: onNewGame, child: Text(newGameLabel)),
      ],
    );
  }
}

/// A muted label column followed by a bold value, as used in result dialogs.
class KfgDialogStatRow extends StatelessWidget {
  const KfgDialogStatRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = defaultLabelWidth,
  });

  static const double defaultLabelWidth = 110;

  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                color: KfgColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: KfgColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

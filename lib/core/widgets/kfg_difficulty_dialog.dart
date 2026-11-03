import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';

/// One choice in a [KfgDifficultyDialog].
class KfgDifficultyOption<T> {
  const KfgDifficultyOption({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.value,
  });

  /// Shown uppercased, e.g. `EASY`.
  final String label;

  /// States the real parameters, e.g. `4 pegs • 6 colors • 10 guesses`.
  final String subtitle;

  /// Conventionally success / primary / warning from easiest to hardest.
  final Color color;

  /// Returned from the dialog when this option is picked.
  final T value;
}

/// The standard `SELECT DIFFICULTY` dialog: one full-width outlined button per
/// option plus **CLOSE**. Pops with the chosen option's value, or `null`.
class KfgDifficultyDialog<T> extends StatelessWidget {
  const KfgDifficultyDialog({
    super.key,
    required this.options,
    this.title = 'SELECT DIFFICULTY',
  });

  final List<KfgDifficultyOption<T>> options;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KfgColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: KfgColors.primary, width: 1.5),
      ),
      // Scrolls when the options outgrow a short (e.g. landscape) screen.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: KfgColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < options.length; i++) ...[
              _DifficultyButton<T>(option: options[i]),
              if (i != options.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyButton<T> extends StatelessWidget {
  const _DifficultyButton({required this.option});

  final KfgDifficultyOption<T> option;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: option.color, width: 1.3),
          foregroundColor: KfgColors.textPrimary,
          backgroundColor: KfgColors.surfaceVariant.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onPressed: () => Navigator.of(context).pop(option.value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.label.toUpperCase(),
              style: TextStyle(
                color: option.color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              option.subtitle,
              style: const TextStyle(
                color: KfgColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

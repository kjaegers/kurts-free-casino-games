import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../logic/video_poker_variant.dart';

/// Picks the variant for a new session. Pops with the choice, or null on
/// CLOSE (keeping the current one).
class VideoPokerVariantDialog extends StatelessWidget {
  const VideoPokerVariantDialog({super.key, required this.current});

  final VideoPokerVariant current;

  static const Map<VideoPokerVariant, Color> _colors = {
    VideoPokerVariant.jokerPoker: KfgColors.secondary,
    VideoPokerVariant.jacksOrBetter: KfgColors.primary,
    VideoPokerVariant.deucesWild: KfgColors.success,
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KfgColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: KfgColors.primary, width: 1.5),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CHOOSE A GAME',
              style: TextStyle(
                color: KfgColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 14),
            for (final variant in VideoPokerVariant.values) ...[
              _ChoiceButton(
                title: variant.label,
                summary:
                    '${variant.summary} Returns ${variant.returnPercent}% '
                    'with perfect play at 5 coins.',
                color: _colors[variant]!,
                current: variant == current,
                onPressed: () => Navigator.of(context).pop(variant),
              ),
              const SizedBox(height: 8),
            ],
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

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.title,
    required this.summary,
    required this.color,
    required this.current,
    required this.onPressed,
  });

  final String title;
  final String summary;
  final Color color;
  final bool current;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: current ? 2.2 : 1.3),
          foregroundColor: KfgColors.textPrimary,
          backgroundColor: KfgColors.surfaceVariant.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${title.toUpperCase()}${current ? '  (current)' : ''}',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              summary,
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

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';

/// The row of machine actions: Variant, Bet One and Bet Max.
class VideoPokerControls extends StatelessWidget {
  const VideoPokerControls({
    super.key,
    required this.onVariant,
    required this.onBetOne,
    required this.onBetMax,
  });

  /// Null disables the action.
  final VoidCallback? onVariant;
  final VoidCallback? onBetOne;
  final VoidCallback? onBetMax;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _ActionCard(
        tooltip: 'Choose a variant between hands (V)',
        label: 'Variant',
        icon: Icons.style_outlined,
        onTap: onVariant,
      ),
      _ActionCard(
        tooltip: 'Bet one more coin, 5 wraps to 1 (B)',
        label: 'Bet One',
        icon: Icons.exposure_plus_1,
        onTap: onBetOne,
      ),
      _ActionCard(
        tooltip: 'Bet 5 coins and deal (M)',
        label: 'Bet Max',
        icon: Icons.keyboard_double_arrow_up,
        onTap: onBetMax,
      ),
    ];
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: actions[i]),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? KfgColors.textPrimary : KfgColors.textMuted;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: enabled
                    ? KfgColors.surfaceVariant.withValues(alpha: 0.72)
                    : KfgColors.surface.withValues(alpha: 0.75),
                border: Border.all(
                  color: enabled
                      ? KfgColors.cardBorder
                      : KfgColors.textMuted.withValues(alpha: 0.55),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 16, color: color),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

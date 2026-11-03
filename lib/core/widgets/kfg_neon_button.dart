import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import 'kfg_settings_scope.dart';

/// A neon-styled button with an optional icon.
///
/// Pass [onPressed] as null to render a disabled state. The glow strength
/// follows Settings > Neon Intensity.
class KfgNeonButton extends StatelessWidget {
  const KfgNeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = KfgColors.primary,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  /// When true, the button stretches to fill available width.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    final effectiveColor = active ? color : KfgColors.textMuted;
    final glowScale = KfgSettingsScope.of(context).themeIntensity.glowScale;

    final content = GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: effectiveColor, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: effectiveColor.withValues(
                      alpha: (0.25 * glowScale).clamp(0.0, 1.0),
                    ),
                    blurRadius: 10 * glowScale,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: effectiveColor, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: effectiveColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return expanded
        ? SizedBox(width: double.infinity, child: content)
        : content;
  }
}

import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import 'kfg_settings_scope.dart';

/// A card styled with the neon arcade theme.
///
/// Optionally add a coloured glow by providing [glowColor]. Its strength
/// follows Settings > Neon Intensity.
class KfgNeonCard extends StatelessWidget {
  const KfgNeonCard({
    super.key,
    required this.child,
    this.borderColor = KfgColors.cardBorder,
    this.glowColor,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color borderColor;

  /// When set, a soft outer glow is drawn around the card border.
  final Color? glowColor;

  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final glowScale = KfgSettingsScope.of(context).themeIntensity.glowScale;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: KfgColors.surface,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          boxShadow: glowColor != null
              ? [
                  BoxShadow(
                    color: glowColor!.withValues(
                      alpha: (0.22 * glowScale).clamp(0.0, 1.0),
                    ),
                    blurRadius: 14 * glowScale,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

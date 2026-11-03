import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';

/// A compact single-line `icon  Label value` chip for in-game status panels.
///
/// Place several in a `Row` of `Expanded`s; long values ellipsize rather
/// than overflow.
class KfgStatChip extends StatelessWidget {
  const KfgStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
    this.monospaceDigits = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;

  /// Use tabular figures so a ticking timer doesn't jitter.
  final bool monospaceDigits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(
        color: KfgColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: KfgColors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(
                    color: KfgColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        fontFeatures: monospaceDigits
                            ? const [FontFeature.tabularFigures()]
                            : null,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

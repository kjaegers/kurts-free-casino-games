import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import '../animation/kfg_web_animation_speed.dart';

class CardPileWidget extends StatelessWidget {
  const CardPileWidget({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.count,
    this.semanticLabel,
    this.semanticHint,
    this.statusLabel,
    this.selected = false,
    this.highlighted = false,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final int? count;
  final String? semanticLabel;
  final String? semanticHint;
  final String? statusLabel;
  final bool selected;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = count == null ? label : '$label $count';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: semanticLabel ?? resolvedLabel,
          hint: semanticHint,
          button: onTap != null || onDoubleTap != null,
          selected: selected,
          enabled: onTap != null || onDoubleTap != null,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(child: child),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          resolvedLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: KfgColors.textSecondary,
            fontSize: 10,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(
            height: 11,
            child: Center(
              child: AnimatedSwitcher(
                duration: kfgAnimDuration(const Duration(milliseconds: 120)),
                child: statusLabel == null
                    ? const SizedBox.shrink()
                    : Text(
                        statusLabel!,
                        key: ValueKey<String>(statusLabel!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: KfgColors.highlight,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

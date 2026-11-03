import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';

/// A labelled section header with a neon left-border accent.
class KfgSectionHeader extends StatelessWidget {
  const KfgSectionHeader({super.key, required this.title, this.trailing});

  final String title;

  /// Optional widget placed at the far right (e.g. a text button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: const BoxDecoration(
            color: KfgColors.primary,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: KfgColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

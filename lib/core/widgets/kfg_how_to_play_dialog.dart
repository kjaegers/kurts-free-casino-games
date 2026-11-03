import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';

/// One titled block of instructions in a [KfgHowToPlayDialog].
class KfgHowToPlaySection {
  const KfgHowToPlaySection({
    required this.title,
    required this.body,
    this.illustration,
  });

  /// Short uppercase heading, e.g. `OBJECTIVE`.
  final String title;
  final String body;

  /// Optional small visual shown under [body], e.g. a legend of pieces. Use
  /// only when a picture genuinely explains more than the text.
  final Widget? illustration;
}

/// Shows the standard scrollable **HOW TO PLAY** dialog.
Future<void> showKfgHowToPlayDialog(
  BuildContext context, {
  required List<KfgHowToPlaySection> sections,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => KfgHowToPlayDialog(sections: sections),
  );
}

/// The standard **HOW TO PLAY** dialog: scrollable titled sections and a
/// **GOT IT** button.
class KfgHowToPlayDialog extends StatelessWidget {
  const KfgHowToPlayDialog({super.key, required this.sections});

  final List<KfgHowToPlaySection> sections;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KfgColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: KfgColors.cardBorder),
      ),
      title: const Text(
        'HOW TO PLAY',
        style: TextStyle(
          color: KfgColors.primary,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in sections) _Section(section: section),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('GOT IT'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final KfgHowToPlaySection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              color: KfgColors.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            section.body,
            style: const TextStyle(
              color: KfgColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (section.illustration != null) ...[
            const SizedBox(height: 8),
            section.illustration!,
          ],
        ],
      ),
    );
  }
}

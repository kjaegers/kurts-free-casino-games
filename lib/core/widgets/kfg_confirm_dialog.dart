import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';

/// Shows the standard confirmation dialog: a title, a message, **CANCEL** and
/// an uppercase [confirmLabel] verb (e.g. `LEAVE`, `NEW GAME`).
///
/// Resolves to `true` only when the player confirms; dismissing it by tapping
/// outside or pressing back counts as cancel.
Future<bool> showKfgConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: KfgColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: KfgColors.cardBorder),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: KfgColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: KfgColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: confirmColor == null
              ? null
              : TextButton.styleFrom(foregroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import '../services/credits_service.dart';

/// The player's credit balance, kept up to date. Every game screen shows
/// one in its AppBar actions so the balance is always visible, and the home
/// screen shows one in its header.
class KfgCreditsBadge extends StatelessWidget {
  const KfgCreditsBadge({super.key, this.credits, this.large = false});

  /// Defaults to [CreditsService.instance].
  final CreditsService? credits;

  /// A bigger badge for the home screen header.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final service = credits ?? CreditsService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final text = formatCredits(service.balance);
        return Tooltip(
          message: 'Your play-money credits',
          child: Semantics(
            label: 'Credits: $text',
            liveRegion: true,
            excludeSemantics: true,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: large ? 12 : 8,
                vertical: large ? 6 : 3,
              ),
              decoration: BoxDecoration(
                color: KfgColors.surface,
                borderRadius: BorderRadius.circular(large ? 12 : 9),
                border: Border.all(
                  color: KfgColors.warning.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.toll,
                    size: large ? 20 : 15,
                    color: KfgColors.warning,
                  ),
                  SizedBox(width: large ? 6 : 4),
                  Text(
                    text,
                    maxLines: 1,
                    style: TextStyle(
                      color: KfgColors.warning,
                      fontSize: large ? 17 : 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (large) ...[
                    const SizedBox(width: 6),
                    const Text(
                      'CREDITS',
                      style: TextStyle(
                        color: KfgColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

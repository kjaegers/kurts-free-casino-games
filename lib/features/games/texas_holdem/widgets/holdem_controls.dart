import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';

/// One action in the [HoldemControls] row.
class HoldemAction {
  const HoldemAction({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String tooltip;

  /// Null disables the action.
  final VoidCallback? onTap;
}

/// The row of table actions: bet sizes on the player's turn, table
/// settings between hands.
class HoldemControls extends StatelessWidget {
  const HoldemControls({super.key, required this.actions});

  final List<HoldemAction> actions;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _ActionCard(action: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final HoldemAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    final color = enabled ? KfgColors.textPrimary : KfgColors.textMuted;

    return Tooltip(
      message: action.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: action.label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: action.onTap,
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
                      Icon(action.icon, size: 16, color: color),
                      const SizedBox(height: 1),
                      Text(
                        action.label,
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

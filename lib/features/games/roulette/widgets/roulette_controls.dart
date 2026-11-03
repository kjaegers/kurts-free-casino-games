import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../logic/roulette_game.dart';
import 'roulette_chip.dart';

/// The row of table actions: the chip values to pick from, then Undo and
/// Clear.
class RouletteControls extends StatelessWidget {
  const RouletteControls({
    super.key,
    required this.chip,
    required this.onSelectChip,
    required this.onUndo,
    required this.onClear,
  });

  /// The chip value in hand.
  final int chip;

  /// Null disables the action.
  final ValueChanged<int>? onSelectChip;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      for (var i = 0; i < rouletteChipValues.length; i++)
        _ChipButton(
          value: rouletteChipValues[i],
          shortcut: i + 1,
          selected: rouletteChipValues[i] == chip,
          onTap: onSelectChip == null
              ? null
              : () => onSelectChip!(rouletteChipValues[i]),
        ),
      _ActionCard(
        tooltip: 'Take back the last chip (U)',
        label: 'Undo',
        icon: Icons.undo,
        onTap: onUndo,
      ),
      _ActionCard(
        tooltip: 'Take every chip off the table (C)',
        label: 'Clear',
        icon: Icons.clear_all,
        onTap: onClear,
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

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.value,
    required this.shortcut,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final int shortcut;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = rouletteChipColor(value);
    return Tooltip(
      message: 'Bet $value-credit chips ($shortcut)',
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: '$value-credit chip',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: selected
                    ? color.withValues(alpha: 0.18)
                    : KfgColors.surface.withValues(alpha: 0.75),
                border: Border.all(
                  color: selected ? color : KfgColors.cardBorder,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: enabled ? color : color.withValues(alpha: 0.4),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.35),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        rouletteChipLabel(value),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
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

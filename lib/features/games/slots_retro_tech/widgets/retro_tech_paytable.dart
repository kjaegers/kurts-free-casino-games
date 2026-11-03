import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/services/credits_service.dart';
import '../logic/retro_tech_paytable.dart';
import '../logic/retro_tech_symbols.dart';
import 'retro_tech_symbol.dart';

/// The paytable: one row per symbol, one column per cluster size, showing
/// what each cluster pays at the current bet. Entries paid by the spin on
/// show are lit.
///
/// Rows share the height they're given, so the table fits any space.
class RetroTechPaytable extends StatelessWidget {
  const RetroTechPaytable({
    super.key,
    required this.betLevel,
    this.paid = const {},
  });

  final int betLevel;

  /// (symbol, paytable column) pairs to light.
  final Set<(RetroTechSymbol, int)> paid;

  @override
  Widget build(BuildContext context) {
    final summary = [
      for (final symbol in RetroTechSymbol.values)
        '${symbol.label}: ${[for (var t = 0; t < retroTechTiers.length; t++) '${retroTechTiers[t].label} pay ${formatCredits(retroTechPaytable[symbol]![t] * betLevel)}'].join(', ')}',
    ].join('. ');
    return Semantics(
      container: true,
      label:
          'Paytable for a ${formatCredits(betLevel * retroTechCreditsPerLevel)}'
          '-credit bet, by cluster size. $summary.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KfgColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KfgColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: _CellText(
                        'SIZE',
                        color: KfgColors.textMuted,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    for (final tier in retroTechTiers)
                      Expanded(
                        flex: 5,
                        child: _CellText(
                          tier.label,
                          color: KfgColors.primary,
                          alignment: Alignment.centerRight,
                        ),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              for (final symbol in RetroTechSymbol.values)
                Expanded(
                  child: _PayRow(
                    symbol: symbol,
                    betLevel: betLevel,
                    paidTiers: {
                      for (final (s, tier) in paid)
                        if (s == symbol) tier,
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.symbol,
    required this.betLevel,
    required this.paidTiers,
  });

  final RetroTechSymbol symbol;
  final int betLevel;
  final Set<int> paidTiers;

  @override
  Widget build(BuildContext context) {
    final pays = retroTechPaytable[symbol]!;
    final rowPaid = paidTiers.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: rowPaid ? KfgColors.warning.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: LayoutBuilder(
                builder: (context, constraints) => RetroTechSymbolIcon(
                  symbol: symbol,
                  size: constraints.maxHeight.clamp(0.0, 30.0),
                ),
              ),
            ),
          ),
          for (var t = 0; t < pays.length; t++)
            Expanded(
              flex: 5,
              child: _CellText(
                formatCredits(pays[t] * betLevel),
                color: paidTiers.contains(t)
                    ? KfgColors.warning
                    : KfgColors.textSecondary,
                alignment: Alignment.centerRight,
                bold: paidTiers.contains(t),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(
    this.text, {
    required this.color,
    required this.alignment,
    this.bold = false,
  });

  final String text;
  final Color color;
  final Alignment alignment;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keeps neighbouring numbers apart when they're scaled down.
      padding: const EdgeInsets.only(left: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

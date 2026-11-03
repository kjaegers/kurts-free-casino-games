import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/services/credits_service.dart';
import '../logic/cherry_run_paytable.dart';
import 'cherry_run_symbol.dart';

/// The paytable: one row per paying line, showing its symbols and what it
/// pays at the current bet per line. Rows paid by the last spin are lit.
///
/// Rows share the height they're given, so the table fits any space.
class CherryRunPaytable extends StatelessWidget {
  const CherryRunPaytable({
    super.key,
    required this.betPerLine,
    this.paidWins = const {},
  });

  final int betPerLine;
  final Set<CherryRunWin> paidWins;

  @override
  Widget build(BuildContext context) {
    final summary = [
      for (final win in CherryRunWin.values)
        '${win.label} pays ${formatCredits(win.pays * betPerLine)}',
    ].join(', ');
    return Semantics(
      container: true,
      label: 'Paytable for $betPerLine per line: $summary.',
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
                      flex: 12,
                      child: _CellText(
                        'PAYS PER LINE',
                        color: KfgColors.textMuted,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _CellText(
                          'BET $betPerLine',
                          color: KfgColors.primary,
                          alignment: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final win in CherryRunWin.values)
                Expanded(
                  child: _PayRow(
                    win: win,
                    pays: win.pays * betPerLine,
                    paid: paidWins.contains(win),
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
  const _PayRow({required this.win, required this.pays, required this.paid});

  final CherryRunWin win;
  final int pays;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final color = paid ? KfgColors.warning : KfgColors.textSecondary;
    return Container(
      decoration: BoxDecoration(
        color: paid ? KfgColors.warning.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(5),
        border: paid
            ? Border.all(color: KfgColors.warning.withValues(alpha: 0.8))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxHeight.clamp(0.0, 30.0);
                return Row(
                  children: [
                    for (final symbol in win.pattern)
                      SizedBox(
                        width: size + 2,
                        child: symbol == null
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: _CellText(
                                  'ANY',
                                  color: KfgColors.textMuted,
                                  alignment: Alignment.center,
                                  fontSize: 8,
                                ),
                              )
                            : CherryRunSymbolIcon(symbol: symbol, size: size),
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            flex: 7,
            child: _CellText(
              win.label.toUpperCase(),
              color: color,
              alignment: Alignment.centerLeft,
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: _CellText(
                formatCredits(pays),
                color: paid ? KfgColors.warning : KfgColors.primary,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
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
    this.fontSize = 12,
  });

  final String text;
  final Color color;
  final Alignment alignment;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

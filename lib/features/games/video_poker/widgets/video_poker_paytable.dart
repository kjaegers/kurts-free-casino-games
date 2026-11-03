import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/services/credits_service.dart';
import '../logic/video_poker_variant.dart';

/// The variant's paytable: one row per paying hand, one column per bet of
/// 1–5 coins. The current bet's column is lit, and so is the row of the
/// hand on the table ([hand]): outlined while holding, filled once paid.
///
/// Rows share the height they're given, so the table fits any space.
class VideoPokerPaytable extends StatelessWidget {
  const VideoPokerPaytable({
    super.key,
    required this.variant,
    required this.bet,
    this.hand,
    this.paid = false,
  });

  final VideoPokerVariant variant;
  final int bet;
  final VideoPokerHand? hand;

  /// [hand] is the final, paid hand rather than the dealt one.
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final lines = variant.paytable;
    final summary = [
      for (final line in lines)
        '${variant.labelFor(line.hand)} pays '
            '${formatCredits(variant.payout(line.hand, bet))}',
    ].join(', ');
    return Semantics(
      container: true,
      label: 'Paytable for a $bet-coin bet: $summary.',
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
              for (final line in lines)
                Expanded(
                  child: _PayRow(
                    label: variant.labelFor(line.hand),
                    values: [
                      for (
                        var coins = videoPokerMinBet;
                        coins <= videoPokerMaxBet;
                        coins++
                      )
                        variant.payout(line.hand, coins),
                    ],
                    bet: bet,
                    state: line.hand != hand
                        ? _RowState.plain
                        : paid
                        ? _RowState.paid
                        : _RowState.dealt,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RowState { plain, dealt, paid }

class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.label,
    required this.values,
    required this.bet,
    required this.state,
  });

  final String label;
  final List<int> values;
  final int bet;
  final _RowState state;

  @override
  Widget build(BuildContext context) {
    final rowColor = switch (state) {
      _RowState.paid => KfgColors.warning,
      _RowState.dealt => KfgColors.textPrimary,
      _RowState.plain => KfgColors.textSecondary,
    };
    return Container(
      decoration: BoxDecoration(
        color: state == _RowState.paid
            ? KfgColors.warning.withValues(alpha: 0.16)
            : null,
        borderRadius: BorderRadius.circular(5),
        border: state == _RowState.plain
            ? null
            : Border.all(color: rowColor.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 9,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _CellText(
                label.toUpperCase(),
                color: rowColor,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          for (var i = 0; i < values.length; i++)
            Expanded(
              flex: 4,
              child: Container(
                color: i + 1 == bet
                    ? KfgColors.primary.withValues(alpha: 0.16)
                    : null,
                padding: const EdgeInsets.only(right: 4),
                child: _CellText(
                  formatCredits(values[i]),
                  color: i + 1 == bet && state == _RowState.plain
                      ? KfgColors.primary
                      : rowColor,
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
  const _CellText(this.text, {required this.color, required this.alignment});

  final String text;
  final Color color;
  final Alignment alignment;

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
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/services/credits_service.dart';
import '../logic/roulette_bets.dart';
import '../logic/roulette_game.dart';
import '../logic/roulette_wheel.dart';
import 'roulette_chip.dart';

/// The betting layout: 0, the numbers 1–36, the column bets, the dozens
/// and the even-money boxes, with the chips on each bet.
///
/// Tapping places the chip in hand on the bet under the finger: the middle
/// of a number bets on it, its edges and corners on the splits, corners,
/// streets and lines around it (see [rouletteBetAt]). [vertical] runs the
/// numbers down the screen, three across, for portrait screens; otherwise
/// they run across in three rows, as on a real table.
class RouletteBoard extends StatelessWidget {
  const RouletteBoard({
    super.key,
    required this.game,
    required this.vertical,
    required this.onBet,
  });

  final RouletteGame game;
  final bool vertical;

  /// Null while bets can't be placed.
  final ValueChanged<RouletteBet>? onBet;

  /// The layout is 14 cells along (0, twelve streets, the column bets) by
  /// 5 across (three columns of numbers, the dozens, the even-money boxes).
  static const int _along = 14;
  static const int _across = 5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = vertical ? _across : _along;
        final rows = vertical ? _along : _across;
        var cellW = constraints.maxWidth / cols;
        var cellH = constraints.maxHeight / rows;
        // Keep cells from stretching into long slivers on big screens.
        cellW = math.min(cellW, cellH * 2.4);
        cellH = math.min(cellH, cellW * 1.6);
        final geometry = _BoardGeometry(
          vertical: vertical,
          cellW: cellW,
          cellH: cellH,
        );
        final size = Size(cols * cellW, rows * cellH);
        final stakes = game.stakes;
        return Center(
          child: Semantics(
            container: true,
            label: 'Roulette table',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onBet == null
                  ? null
                  : (details) {
                      final bet = geometry.betAt(details.localPosition);
                      if (bet != null) onBet!(bet);
                    },
              child: SizedBox.fromSize(
                size: size,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BoardPainter(
                          geometry: geometry,
                          stakes: stakes,
                          game: game,
                        ),
                      ),
                    ),
                    // Screen readers get a button for each number and box;
                    // the splits, corners and lines are touch-only.
                    for (final bet in rouletteBets)
                      if (bet.kind == RouletteBetKind.straight ||
                          !bet.kind.isInside)
                        Positioned.fromRect(
                          rect: geometry.cellRectOf(bet),
                          child: Semantics(
                            button: true,
                            enabled: onBet != null,
                            label: _semanticsLabel(bet, stakes[bet]),
                            onTap: onBet == null ? null : () => onBet!(bet),
                            child: const SizedBox.expand(),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _semanticsLabel(RouletteBet bet, int? stake) {
    final name = bet.kind == RouletteBetKind.straight
        ? roulettePocketLabel(bet.numbers.single)
        : bet.label;
    final parts = [
      name,
      'pays ${bet.pays} to 1',
      if (stake != null) '${formatCredits(stake)} on it',
      if (game.isComplete && stake != null && bet.wins(game.pocket!)) 'won',
      if (game.isComplete &&
          bet.kind == RouletteBetKind.straight &&
          bet.numbers.single == game.pocket)
        'the number that came up',
    ];
    return parts.join(', ');
  }
}

/// Converts between the layout's grid units (see [RouletteBet]) and pixels.
class _BoardGeometry {
  const _BoardGeometry({
    required this.vertical,
    required this.cellW,
    required this.cellH,
  });

  final bool vertical;
  final double cellW;
  final double cellH;

  /// The pixel position of grid point ([u], [v]).
  Offset toScreen(double u, double v) => vertical
      ? Offset((v + 2) * cellW, (u + 1) * cellH)
      : Offset((u + 1) * cellW, (3 - v) * cellH);

  /// The pixel rectangle of the grid area [u0]…[u1] × [v0]…[v1].
  Rect rect(double u0, double u1, double v0, double v1) =>
      Rect.fromPoints(toScreen(u0, v0), toScreen(u1, v1));

  /// The bet under pixel [p]. The band that counts as "on a line" is about
  /// 10 px wide, but never less than a fifth of a cell or more than a
  /// little over a quarter, so every spot stays reachable.
  RouletteBet? betAt(Offset p) {
    final double u, v, alongCell, acrossCell;
    if (vertical) {
      u = p.dy / cellH - 1;
      v = p.dx / cellW - 2;
      alongCell = cellH;
      acrossCell = cellW;
    } else {
      u = p.dx / cellW - 1;
      v = 3 - p.dy / cellH;
      alongCell = cellW;
      acrossCell = cellH;
    }
    double edge(double cell) => (10 / cell).clamp(0.2, 0.28);
    return rouletteBetAt(u, v, edgeU: edge(alongCell), edgeV: edge(acrossCell));
  }

  /// The cell or box a straight-up or outside bet is drawn in.
  Rect cellRectOf(RouletteBet bet) {
    switch (bet.kind) {
      case RouletteBetKind.straight:
        final n = bet.numbers.single;
        if (n == 0) return rect(-1, 0, 0, 3);
        final row = (n - 1) ~/ 3;
        final col = (n - 1) % 3;
        return rect(row.toDouble(), row + 1.0, col.toDouble(), col + 1.0);
      case RouletteBetKind.column:
        final col = bet.spotV.floor();
        return rect(12, 13, col.toDouble(), col + 1.0);
      case RouletteBetKind.dozen:
        final start = bet.spotU - 2;
        return rect(start, start + 4, -1, 0);
      default:
        final start = bet.spotU - 1;
        return rect(start, start + 2, -2, -1);
    }
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.geometry,
    required this.stakes,
    required this.game,
  });

  final _BoardGeometry geometry;
  final Map<RouletteBet, int> stakes;
  final RouletteGame game;

  static final List<RouletteBet> _cells = [
    for (final bet in rouletteBets)
      if (bet.kind == RouletteBetKind.straight || !bet.kind.isInside) bet,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(geometry.cellW, geometry.cellH);
    final landed = game.isComplete ? game.pocket : null;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final bet in _cells) {
      final r = geometry.cellRectOf(bet).deflate(0.5);
      canvas.drawRect(r, Paint()..color = _fillFor(bet));
      canvas.drawRect(r, line);
      final shift = stakes.containsKey(bet) ? _outsideShift(bet) : null;
      _label(
        canvas,
        r,
        shift == null
            ? r.center
            : geometry.toScreen(
                bet.spotU + shift.labelU,
                bet.spotV + shift.labelV,
              ),
        _textFor(bet),
        unit,
        bet.kind == RouletteBetKind.straight,
      );
    }

    if (landed != null) {
      final r = geometry.cellRectOf(rouletteStraight(landed)).deflate(1.5);
      canvas.drawRect(
        r,
        Paint()
          ..color = KfgColors.warning.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawRect(
        r,
        Paint()
          ..color = KfgColors.warning
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    final radius = (unit * 0.34).clamp(6.0, 18.0);
    for (final MapEntry(key: bet, value: stake) in stakes.entries) {
      final won = landed != null && bet.wins(landed);
      final shift = _outsideShift(bet);
      _chip(
        canvas,
        geometry.toScreen(
          bet.spotU + (shift?.chipU ?? 0),
          bet.spotV + (shift?.chipV ?? 0),
        ),
        radius,
        stake,
        won: won,
        dimmed: landed != null && !won,
      );
    }
  }

  /// On a box outside the numbers, a stake's chip sits towards one end and
  /// the box's name moves towards the other, so both stay readable. In grid
  /// units from the bet's spot; null for the inside bets.
  static ({double chipU, double chipV, double labelU, double labelV})?
  _outsideShift(RouletteBet bet) => switch (bet.kind) {
    _ when bet.kind.isInside => null,
    RouletteBetKind.column => (chipU: 0, chipV: -0.25, labelU: 0, labelV: 0.25),
    RouletteBetKind.dozen => (chipU: -1.2, chipV: 0, labelU: 0.4, labelV: 0),
    _ => (chipU: -0.5, chipV: 0, labelU: 0.4, labelV: 0),
  };

  Color _fillFor(RouletteBet bet) => switch (bet.kind) {
    RouletteBetKind.straight => roulettePocketColor(bet.numbers.single),
    RouletteBetKind.red => rouletteRed.withValues(alpha: 0.75),
    RouletteBetKind.black => rouletteBlack,
    _ => KfgColors.surfaceVariant,
  };

  String _textFor(RouletteBet bet) => switch (bet.kind) {
    RouletteBetKind.straight => '${bet.numbers.single}',
    RouletteBetKind.column => '2 to 1',
    RouletteBetKind.red => 'RED',
    RouletteBetKind.black => 'BLACK',
    RouletteBetKind.odd => 'ODD',
    RouletteBetKind.even => 'EVEN',
    _ => bet.label,
  };

  void _label(
    Canvas canvas,
    Rect r,
    Offset at,
    String text,
    double unit,
    bool number,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: number ? unit * 0.42 : unit * 0.3,
          fontWeight: number ? FontWeight.w900 : FontWeight.w800,
          letterSpacing: number ? 0 : 0.5,
          fontFamily: KfgFonts.family,
          fontFamilyFallback: KfgFonts.fallback,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // Shrink anything too wide for its box rather than clipping it.
    final scale = math.min(1.0, (r.width - 4) / painter.width);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(scale);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    painter.dispose();
  }

  void _chip(
    Canvas canvas,
    Offset at,
    double radius,
    int stake, {
    required bool won,
    required bool dimmed,
  }) {
    final alpha = dimmed ? 0.45 : 1.0;
    if (won) {
      canvas.drawCircle(
        at,
        radius + 3,
        Paint()
          ..color = KfgColors.warning
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawCircle(
      at.translate(0, 1.5),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.45 * alpha),
    );
    canvas.drawCircle(
      at,
      radius,
      Paint()..color = rouletteChipColor(stake).withValues(alpha: alpha),
    );
    canvas.drawCircle(
      at,
      radius * 0.72,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, radius * 0.12),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: rouletteChipLabel(stake),
        style: TextStyle(
          color: Colors.black.withValues(alpha: alpha),
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w900,
          fontFamily: KfgFonts.family,
          fontFamilyFallback: KfgFonts.fallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final scale = math.min(1.0, radius * 1.3 / painter.width);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(scale);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) =>
      oldDelegate.game != game ||
      oldDelegate.geometry.vertical != geometry.vertical ||
      oldDelegate.geometry.cellW != geometry.cellW ||
      oldDelegate.geometry.cellH != geometry.cellH;
}

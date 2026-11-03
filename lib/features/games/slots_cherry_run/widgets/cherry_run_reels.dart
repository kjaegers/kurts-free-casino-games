import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../logic/cherry_run_game.dart';
import '../logic/cherry_run_reels.dart';
import 'cherry_run_symbol.dart';

/// The machine's window: three reels of three rows, the line numbers down
/// each side (lit when played) and, once a spin is paid, its winning lines
/// marked across the reels.
class CherryRunReelWindow extends StatelessWidget {
  const CherryRunReelWindow({
    super.key,
    required this.game,
    required this.spinToken,
    required this.reelDurations,
    this.reelsStopped = 0,
    required this.cellSize,
  });

  final CherryRunGame game;
  final int spinToken;
  final List<Duration> reelDurations;

  /// Reels, from the left, already at rest on a spin still turning.
  final int reelsStopped;

  /// The side of one symbol's square.
  final double cellSize;

  static const double markerWidth = 22;
  static const double reelGap = 4;
  static const double _frame = 4;

  /// The window's width for [cellSize], markers included.
  static double widthFor(double cellSize) =>
      2 * markerWidth + 3 * cellSize + 2 * reelGap + 2 * _frame + 8;

  /// The window's height for [cellSize].
  static double heightFor(double cellSize) =>
      cherryRunRowCount * cellSize + 2 * _frame;

  /// The largest cell that fits [width] × [height].
  static double cellSizeFor({required double width, required double height}) {
    final byWidth = (width - widthFor(0)) / 3;
    final byHeight = (height - heightFor(0)) / cherryRunRowCount;
    return byWidth < byHeight ? byWidth : byHeight;
  }

  @override
  Widget build(BuildContext context) {
    final winRows = game.isComplete
        ? {for (final w in game.lineWins) w.row}
        : const <int>{};
    final activeRows = {
      for (var line = 1; line <= game.lines; line++)
        cherryRunLineRows[line - 1],
    };
    return Semantics(
      container: true,
      label: _semanticsLabel(),
      excludeSemantics: true,
      child: SizedBox(
        width: widthFor(cellSize),
        height: heightFor(cellSize),
        child: Row(
          children: [
            _LineMarkers(
              cellSize: cellSize,
              activeRows: activeRows,
              winRows: winRows,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF02020A),
                      Color(0xFF0C0C2A),
                      Color(0xFF02020A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: KfgColors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: KfgColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_frame - 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: CustomPaint(
                      foregroundPainter: _LinesPainter(
                        activeRows: activeRows,
                        winRows: winRows,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (
                            var reel = 0;
                            reel < cherryRunReelCount;
                            reel++
                          ) ...[
                            if (reel > 0) const _ReelDivider(),
                            _Reel(
                              reel: reel,
                              stop: game.stops[reel],
                              spinning: game.isSpinning,
                              spinToken: spinToken,
                              duration: reelDurations[reel],
                              cellSize: cellSize,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _LineMarkers(
              cellSize: cellSize,
              activeRows: activeRows,
              winRows: winRows,
            ),
          ],
        ),
      ),
    );
  }

  String _semanticsLabel() {
    if (game.isSpinning) {
      return reelsStopped == 0
          ? 'Reels spinning'
          : 'Reels spinning, $reelsStopped of $cherryRunReelCount stopped';
    }
    const rowNames = ['Top', 'Middle', 'Bottom'];
    final rows = game.window;
    return [
      'Reels',
      for (var row = 0; row < cherryRunRowCount; row++)
        '${rowNames[row]} row: ${rows[row].map((s) => s.label).join(', ')}',
    ].join('. ');
  }
}

/// The line numbers beside each row: line 1 in the middle, 2 on top, 3 at
/// the bottom. Lit when played, gold when paid.
class _LineMarkers extends StatelessWidget {
  const _LineMarkers({
    required this.cellSize,
    required this.activeRows,
    required this.winRows,
  });

  final double cellSize;
  final Set<int> activeRows;
  final Set<int> winRows;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CherryRunReelWindow.markerWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var row = 0; row < cherryRunRowCount; row++)
            SizedBox(
              height: cellSize,
              child: Center(child: _marker(row)),
            ),
        ],
      ),
    );
  }

  Widget _marker(int row) {
    final line = cherryRunLineRows.indexOf(row) + 1;
    final active = activeRows.contains(row);
    final won = winRows.contains(row);
    final color = won
        ? KfgColors.warning
        : active
        ? KfgColors.primary
        : KfgColors.textMuted;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color.withValues(alpha: 0.2) : null,
        border: Border.all(color: color, width: active ? 2 : 1),
      ),
      child: Center(
        child: Text(
          '$line',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// A thin glowing cyan rule between two reels.
class _ReelDivider extends StatelessWidget {
  const _ReelDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CherryRunReelWindow.reelGap,
      child: Center(
        child: Container(
          width: 1.5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                KfgColors.primary.withValues(alpha: 0.1),
                KfgColors.primary.withValues(alpha: 0.7),
                KfgColors.primary.withValues(alpha: 0.1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: KfgColors.primary.withValues(alpha: 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shading at the top and bottom edges so the reels read as turning drums,
/// faint guides along the lines played and bold gold bars along the lines
/// paid, drawn over the reels.
class _LinesPainter extends CustomPainter {
  const _LinesPainter({required this.activeRows, required this.winRows});

  final Set<int> activeRows;
  final Set<int> winRows;

  @override
  void paint(Canvas canvas, Size size) {
    final rowHeight = size.height / cherryRunRowCount;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x99000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0x99000000),
          ],
          stops: [0, 0.14, 0.86, 1],
        ).createShader(Offset.zero & size),
    );
    for (final row in activeRows) {
      final y = rowHeight * (row + 0.5);
      final won = winRows.contains(row);
      if (won) {
        canvas.drawRect(
          Rect.fromLTWH(0, row * rowHeight, size.width, rowHeight),
          Paint()..color = KfgColors.warning.withValues(alpha: 0.18),
        );
      }
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = won
              ? KfgColors.warning.withValues(alpha: 0.85)
              : KfgColors.primary.withValues(alpha: 0.35)
          ..strokeWidth = won ? 3 : 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter oldDelegate) =>
      !_sameSet(oldDelegate.activeRows, activeRows) ||
      !_sameSet(oldDelegate.winRows, winRows);

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// One reel. When [spinToken] changes while [spinning], it turns downward
/// at a steady speed for [duration], braking briefly at the end to halt on
/// [stop]; if the spin is settled early it jumps straight there.
class _Reel extends StatefulWidget {
  const _Reel({
    required this.reel,
    required this.stop,
    required this.spinning,
    required this.spinToken,
    required this.duration,
    required this.cellSize,
  });

  final int reel;
  final int stop;
  final bool spinning;
  final int spinToken;
  final Duration duration;
  final double cellSize;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this);

  /// Full speed, in stops per second.
  static const double _speed = 24;

  /// How long the reel takes to brake to a halt.
  static const double _brakeSeconds = 0.45;

  /// Where the spin started, how many stops it travels and how.
  double _from = 0;
  double _distance = 0;
  Curve _curve = const _SpinCurve(0.8);

  @override
  void didUpdateWidget(_Reel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning &&
        widget.spinToken != oldWidget.spinToken &&
        widget.duration > Duration.zero) {
      // Whole turns plus the way down to the new stop, as close as that
      // allows to the distance covered at full speed, so every reel moves
      // at much the same pace however long it turns.
      final seconds = widget.duration.inMicroseconds / 1e6;
      final cruise = 1 - math.min(_brakeSeconds, seconds / 2) / seconds;
      final atSpeed = _speed * seconds * (1 + cruise) / 2;
      final offset = (oldWidget.stop - widget.stop) % cherryRunStopCount;
      final turns = math.max(
        1,
        ((atSpeed - offset) / cherryRunStopCount).round(),
      );
      _from = oldWidget.stop.toDouble();
      _distance = (turns * cherryRunStopCount + offset).toDouble();
      _curve = _SpinCurve(cruise);
      _animation
        ..duration = widget.duration
        ..forward(from: 0);
    } else if (!widget.spinning && _animation.isAnimating) {
      _animation.stop();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  /// The strip position on the middle row; it falls as the reel turns, so
  /// the symbols move down.
  double get _position => _animation.isAnimating
      ? _from - _distance * _curve.transform(_animation.value)
      : widget.stop.toDouble();

  @override
  Widget build(BuildContext context) {
    final cell = widget.cellSize;
    return SizedBox(
      width: cell,
      height: cell * cherryRunRowCount,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final position = _position;
          final first = position.floor() - 2;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var index = first; index <= first + 4; index++)
                Positioned(
                  left: 0,
                  top: (index - position + 1) * cell,
                  width: cell,
                  height: cell,
                  child: Padding(
                    padding: EdgeInsets.all(cell * 0.1),
                    // Symbols slide but don't change while a reel turns, so
                    // their glow is painted once rather than every frame.
                    child: RepaintBoundary(
                      child: CherryRunSymbolIcon(
                        symbol: cherryRunSymbolAt(
                          widget.reel,
                          index % cherryRunStopCount,
                        ),
                        size: cell * 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A reel's progress over its spin: full speed until [cruise], then a
/// steady brake to a halt at the end.
class _SpinCurve extends Curve {
  const _SpinCurve(this.cruise);

  /// The fraction of the spin at full speed.
  final double cruise;

  @override
  double transformInternal(double t) {
    // Full speed is 2 / (1 + cruise), so the whole spin covers exactly 1.
    final speed = 2 / (1 + cruise);
    if (t <= cruise) return speed * t;
    final braking = t - cruise;
    return speed * (cruise + braking - braking * braking / (2 * (1 - cruise)));
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/animation/kfg_web_animation_speed.dart'
    show kfgReduceMotion;
import '../logic/retro_tech_cascade.dart';
import '../logic/retro_tech_game.dart';
import '../logic/retro_tech_symbols.dart';
import '../slots_retro_tech_screen_controller.dart';
import 'retro_tech_symbol.dart';

/// The 5 × 5 grid on a glowing neon backdrop. While a spin plays out it
/// shows the grid [gridIndex] of the spin: symbols falling in on a falling
/// beat (after the last cascade's winners vanish), the winning clusters
/// lit on a winning beat.
class RetroTechGridView extends StatefulWidget {
  const RetroTechGridView({
    super.key,
    required this.game,
    required this.gridIndex,
    required this.beat,
    required this.beatToken,
    required this.beatDuration,
    required this.litClusters,
    required this.cellSize,
  });

  final RetroTechGame game;
  final int gridIndex;
  final RetroTechBeat beat;
  final int beatToken;
  final Duration beatDuration;
  final List<RetroTechCluster> litClusters;

  /// The side of one symbol's square.
  final double cellSize;

  static const double _frame = 4;

  /// The grid's width (and height) for [cellSize].
  static double sizeFor(double cellSize) =>
      retroTechColumns * cellSize + 2 * _frame;

  /// The largest cell that fits [width] × [height].
  static double cellSizeFor({required double width, required double height}) =>
      (math.min(width, height) - sizeFor(0)) / retroTechColumns;

  @override
  State<RetroTechGridView> createState() => _RetroTechGridViewState();
}

class _RetroTechGridViewState extends State<RetroTechGridView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    value: 1,
  );

  /// Share of a cascade's fall spent fading out the cells that won.
  static const double _vanish = 0.3;

  /// Delay before each column of the first fill starts to fall, as a share
  /// of the beat, so the grid fills left to right.
  static const double _columnDelay = 0.07;

  bool get _reduceMotion =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
      kfgReduceMotion;

  @override
  void didUpdateWidget(RetroTechGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.beatToken == oldWidget.beatToken) return;
    if (widget.game.isSpinning &&
        widget.beat == RetroTechBeat.falling &&
        widget.beatDuration > Duration.zero &&
        !_reduceMotion) {
      _animation
        ..duration = widget.beatDuration
        ..forward(from: 0);
    } else {
      _animation.value = 1;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cell = widget.cellSize;
    final side = RetroTechGridView.sizeFor(cell);
    return Semantics(
      container: true,
      label: _semanticsLabel(),
      excludeSemantics: true,
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF02020A), Color(0xFF0C0C2A), Color(0xFF02020A)],
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
        padding: const EdgeInsets.all(RetroTechGridView._frame - 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: CustomPaint(
            painter: const _GridLinesPainter(),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) =>
                  Stack(clipBehavior: Clip.hardEdge, children: _cells(cell)),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _cells(double cell) {
    final game = widget.game;
    final result = game.result;
    if (!game.isSpinning || result == null) {
      return [
        for (var i = 0; i < retroTechCellCount; i++)
          _symbol(game.grid[i], i, cell, top: i ~/ retroTechColumns * cell),
      ];
    }
    final index = widget.gridIndex.clamp(0, result.grids.length - 1);
    final grid = result.grids[index];
    final from = result.fallFrom[index];
    final t = _animation.value;
    final lit = {for (final c in widget.litClusters) ...c.cells};
    final winning = widget.beat == RetroTechBeat.winning && lit.isNotEmpty;
    final cells = <Widget>[];

    // The winners of the previous step shrink away before the rest fall.
    if (index > 0 && t < _vanish) {
      final before = result.grids[index - 1];
      final fade = 1 - t / _vanish;
      for (final i in result.steps[index - 1].removed) {
        cells.add(
          _symbol(
            before[i],
            i,
            cell,
            top: i ~/ retroTechColumns * cell,
            vanishing: fade,
            lit: true,
          ),
        );
      }
    }
    for (var i = 0; i < retroTechCellCount; i++) {
      final row = i ~/ retroTechColumns;
      final column = i % retroTechColumns;
      final double progress;
      if (index == 0) {
        final start = column * _columnDelay;
        final span = 1 - (retroTechColumns - 1) * _columnDelay;
        progress = ((t - start) / span).clamp(0.0, 1.0);
      } else {
        progress = ((t - _vanish) / (1 - _vanish)).clamp(0.0, 1.0);
      }
      final y = from[i] + (row - from[i]) * Curves.easeIn.transform(progress);
      cells.add(
        _symbol(
          grid[i],
          i,
          cell,
          top: y * cell,
          lit: lit.contains(i),
          dimmed: winning && !lit.contains(i),
        ),
      );
    }
    return cells;
  }

  Widget _symbol(
    RetroTechSymbol symbol,
    int index,
    double cell, {
    required double top,
    double? vanishing,
    bool lit = false,
    bool dimmed = false,
  }) {
    final column = index % retroTechColumns;
    Widget child = Padding(
      padding: EdgeInsets.all(cell * 0.08),
      // Symbols move but don't change while falling, so each is painted
      // once rather than every frame.
      child: RepaintBoundary(
        child: RetroTechSymbolIcon(
          symbol: symbol,
          size: cell * 0.84,
          dimmed: dimmed,
        ),
      ),
    );
    if (lit) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: KfgColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(cell * 0.12),
          border: Border.all(color: KfgColors.warning, width: 2),
          boxShadow: [
            BoxShadow(
              color: KfgColors.warning.withValues(alpha: 0.45),
              blurRadius: cell * 0.12,
            ),
          ],
        ),
        child: child,
      );
    }
    // A winner on its way out shrinks and fades from 1 to 0, beside the
    // symbol falling into its place.
    if (vanishing != null) {
      final fade = vanishing.clamp(0.0, 1.0);
      child = Opacity(
        opacity: fade,
        child: Transform.scale(scale: fade, child: child),
      );
    }
    return Positioned(
      key: ValueKey('cell-$index-${vanishing == null ? 'in' : 'out'}'),
      left: column * cell,
      top: top,
      width: cell,
      height: cell,
      child: child,
    );
  }

  String _semanticsLabel() {
    final game = widget.game;
    if (game.isSpinning) {
      return widget.litClusters.isEmpty
          ? 'Grid filling'
          : 'Winning: ${describeRetroTechClusters(widget.litClusters)}';
    }
    return [
      'Grid',
      for (var row = 0; row < retroTechRows; row++)
        'Row ${row + 1}: ${[for (var column = 0; column < retroTechColumns; column++) game.grid[retroTechIndex(row, column)].label].join(', ')}',
    ].join('. ');
  }
}

/// Faint glowing cyan lines between the cells, like a light-cycle arena.
class _GridLinesPainter extends CustomPainter {
  const _GridLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = KfgColors.primary.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    final cellW = size.width / retroTechColumns;
    final cellH = size.height / retroTechRows;
    for (var i = 1; i < retroTechColumns; i++) {
      canvas.drawLine(
        Offset(i * cellW, 0),
        Offset(i * cellW, size.height),
        paint,
      );
    }
    for (var i = 1; i < retroTechRows; i++) {
      canvas.drawLine(
        Offset(0, i * cellH),
        Offset(size.width, i * cellH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridLinesPainter oldDelegate) => false;
}

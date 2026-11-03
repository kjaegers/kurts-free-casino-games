import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../logic/cherry_run_reels.dart';

/// One reel symbol, painted to fill a [size] square as neon line art. Each
/// symbol differs in shape as well as colour, and the bars carry one, two or
/// three plates.
class CherryRunSymbolIcon extends StatelessWidget {
  const CherryRunSymbolIcon({
    super.key,
    required this.symbol,
    required this.size,
    this.dimmed = false,
  });

  final CherryRunSymbol symbol;
  final double size;

  /// Faded, for symbols off the paying lines.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: CherryRunSymbolPainter(symbol: symbol, dimmed: dimmed),
      ),
    );
  }
}

/// Paints each symbol as a glowing neon tube: a soft halo, the coloured
/// tube and a hot white core, over a faint tinted fill.
class CherryRunSymbolPainter extends CustomPainter {
  const CherryRunSymbolPainter({required this.symbol, this.dimmed = false});

  final CherryRunSymbol symbol;
  final bool dimmed;

  static const Color _red = Color(0xFFFF2B4A);
  static const Color _cherry = Color(0xFFFF4F9A);
  static const Color _amber = Color(0xFFFFA000);
  static const Color _lemon = Color(0xFFFFEE58);
  static const Color _plum = Color(0xFF9D7BFF);
  static const Color _leaf = KfgColors.highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    if (dimmed) {
      canvas.saveLayer(
        Offset.zero & Size.square(s),
        Paint()..color = const Color(0x73FFFFFF),
      );
    }
    switch (symbol) {
      case CherryRunSymbol.seven:
        _paintSeven(canvas, s);
      case CherryRunSymbol.tripleBar:
        _paintBars(canvas, s, 3, KfgColors.highlight);
      case CherryRunSymbol.doubleBar:
        _paintBars(canvas, s, 2, KfgColors.secondary);
      case CherryRunSymbol.bar:
        _paintBars(canvas, s, 1, KfgColors.primary);
      case CherryRunSymbol.bell:
        _paintBell(canvas, s);
      case CherryRunSymbol.plum:
        _paintPlum(canvas, s);
      case CherryRunSymbol.lemon:
        _paintLemon(canvas, s);
      case CherryRunSymbol.cherry:
        _paintCherries(canvas, s);
    }
    if (dimmed) canvas.restore();
    canvas.restore();
  }

  /// Draws [path] as a neon tube [width] wide (a fraction of [s]), with an
  /// optional translucent [fill] of the same colour inside it.
  static void _neon(
    Canvas canvas,
    Path path,
    Color color,
    double s, {
    double width = 0.04,
    double fill = 0,
  }) {
    if (fill > 0) {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: fill));
    }
    final w = s * width;
    canvas.drawPath(
      path,
      _stroke(color.withValues(alpha: 0.6), w * 2.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.035),
    );
    canvas.drawPath(path, _stroke(color, w));
    canvas.drawPath(
      path,
      _stroke(Color.lerp(color, Colors.white, 0.7)!, w * 0.35),
    );
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Path _polygon(double s, List<(double, double)> points) {
    final path = Path()..moveTo(points.first.$1 * s, points.first.$2 * s);
    for (final (x, y) in points.skip(1)) {
      path.lineTo(x * s, y * s);
    }
    return path..close();
  }

  /// A small white glint arc on the upper left of a round shape.
  static void _glint(Canvas canvas, Offset centre, double r, double s) {
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r),
      math.pi * 1.05,
      math.pi * 0.35,
      false,
      _stroke(Colors.white.withValues(alpha: 0.8), s * 0.022),
    );
  }

  void _paintSeven(Canvas canvas, double s) {
    final seven = _polygon(s, const [
      (0.18, 0.14),
      (0.82, 0.14),
      (0.82, 0.27),
      (0.52, 0.86),
      (0.34, 0.86),
      (0.62, 0.29),
      (0.18, 0.29),
    ]);
    // A cross stroke on the stem, so the seven reads apart from any glyph.
    final cross = Path()
      ..moveTo(s * 0.38, s * 0.575)
      ..lineTo(s * 0.76, s * 0.575);
    _neon(canvas, seven, _red, s, fill: 0.22);
    _neon(canvas, cross, _red, s);
  }

  void _paintBars(Canvas canvas, double s, int count, Color color) {
    final plateH = s * 0.22;
    final gap = s * 0.055;
    final width = s * 0.84;
    final total = count * plateH + (count - 1) * gap;
    var top = (s - total) / 2;
    final text = TextPainter(
      text: TextSpan(
        text: 'BAR',
        style: TextStyle(
          fontFamily: KfgFonts.family,
          fontFamilyFallback: KfgFonts.fallback,
          fontSize: plateH * 0.66,
          fontWeight: FontWeight.w900,
          letterSpacing: plateH * 0.12,
          height: 1,
          color: Color.lerp(color, Colors.white, 0.45),
          shadows: [Shadow(color: color, blurRadius: s * 0.05)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final left = (s - width) / 2;
    final cut = plateH * 0.32;
    for (var i = 0; i < count; i++) {
      // Chamfered corners rather than rounded ones, for a circuit look.
      final plate = Path()
        ..moveTo(left + cut, top)
        ..lineTo(left + width - cut, top)
        ..lineTo(left + width, top + cut)
        ..lineTo(left + width, top + plateH - cut)
        ..lineTo(left + width - cut, top + plateH)
        ..lineTo(left + cut, top + plateH)
        ..lineTo(left, top + plateH - cut)
        ..lineTo(left, top + cut)
        ..close();
      _neon(canvas, plate, color, s, width: 0.03, fill: 0.14);
      text.paint(
        canvas,
        Offset(
          (s - text.width) / 2 + plateH * 0.06,
          top + (plateH - text.height) / 2,
        ),
      );
      top += plateH + gap;
    }
    text.dispose();
  }

  void _paintBell(Canvas canvas, double s) {
    final body = Path()
      ..moveTo(s * 0.5, s * 0.16)
      ..cubicTo(s * 0.26, s * 0.16, s * 0.28, s * 0.42, s * 0.25, s * 0.57)
      ..quadraticBezierTo(s * 0.23, s * 0.68, s * 0.13, s * 0.74)
      ..lineTo(s * 0.87, s * 0.74)
      ..quadraticBezierTo(s * 0.77, s * 0.68, s * 0.75, s * 0.57)
      ..cubicTo(s * 0.72, s * 0.42, s * 0.74, s * 0.16, s * 0.5, s * 0.16)
      ..close();
    final band = Path()
      ..moveTo(s * 0.27, s * 0.5)
      ..quadraticBezierTo(s * 0.5, s * 0.56, s * 0.73, s * 0.5);
    _neon(canvas, body, _amber, s, fill: 0.2);
    _neon(canvas, band, _amber, s, width: 0.028);
    _neon(
      canvas,
      Path()..addOval(
        Rect.fromCircle(center: Offset(s * 0.5, s * 0.84), radius: s * 0.065),
      ),
      _amber,
      s,
      fill: 0.3,
    );
    _neon(
      canvas,
      Path()..addOval(
        Rect.fromCircle(center: Offset(s * 0.5, s * 0.1), radius: s * 0.045),
      ),
      _amber,
      s,
      width: 0.03,
    );
    _glint(canvas, Offset(s * 0.48, s * 0.4), s * 0.16, s);
  }

  void _paintPlum(Canvas canvas, double s) {
    final centre = Offset(s * 0.5, s * 0.57);
    _neon(
      canvas,
      Path()
        ..moveTo(s * 0.5, s * 0.3)
        ..quadraticBezierTo(s * 0.52, s * 0.18, s * 0.6, s * 0.1),
      _leaf,
      s,
      width: 0.035,
    );
    _neon(
      canvas,
      Path()..addOval(
        Rect.fromCenter(center: centre, width: s * 0.64, height: s * 0.58),
      ),
      _plum,
      s,
      fill: 0.22,
    );
    _neon(
      canvas,
      Path()
        ..moveTo(s * 0.5, s * 0.32)
        ..quadraticBezierTo(s * 0.46, s * 0.56, s * 0.52, s * 0.8),
      _plum,
      s,
      width: 0.024,
    );
    _drawLeaf(canvas, s, Offset(s * 0.58, s * 0.16), s * 0.24, -0.5);
    _glint(canvas, centre, s * 0.22, s);
  }

  void _paintLemon(Canvas canvas, double s) {
    canvas.save();
    canvas.translate(s * 0.5, s * 0.52);
    canvas.rotate(-math.pi / 9);
    final lemon = Path()
      ..moveTo(-s * 0.41, 0)
      ..quadraticBezierTo(-s * 0.36, -s * 0.06, -s * 0.33, -s * 0.12)
      ..cubicTo(-s * 0.22, -s * 0.35, s * 0.22, -s * 0.35, s * 0.33, -s * 0.12)
      ..quadraticBezierTo(s * 0.36, -s * 0.06, s * 0.41, 0)
      ..quadraticBezierTo(s * 0.36, s * 0.06, s * 0.33, s * 0.12)
      ..cubicTo(s * 0.22, s * 0.35, -s * 0.22, s * 0.35, -s * 0.33, s * 0.12)
      ..quadraticBezierTo(-s * 0.36, s * 0.06, -s * 0.41, 0)
      ..close();
    _neon(canvas, lemon, _lemon, s, fill: 0.2);
    // A rind line just inside the edge.
    _neon(
      canvas,
      Path()
        ..moveTo(-s * 0.2, s * 0.17)
        ..quadraticBezierTo(s * 0.02, s * 0.25, s * 0.22, s * 0.15),
      _lemon,
      s,
      width: 0.022,
    );
    _glint(canvas, Offset(0, s * 0.02), s * 0.18, s);
    canvas.restore();
  }

  void _paintCherries(Canvas canvas, double s) {
    final top = Offset(s * 0.58, s * 0.12);
    _neon(
      canvas,
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(s * 0.4, s * 0.3, s * 0.3, s * 0.52),
      _leaf,
      s,
      width: 0.035,
    );
    _neon(
      canvas,
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(s * 0.66, s * 0.36, s * 0.68, s * 0.52),
      _leaf,
      s,
      width: 0.035,
    );
    _drawLeaf(canvas, s, top, s * 0.26, 0.35);
    for (final centre in [
      Offset(s * 0.3, s * 0.7),
      Offset(s * 0.68, s * 0.7),
    ]) {
      _neon(
        canvas,
        Path()..addOval(Rect.fromCircle(center: centre, radius: s * 0.17)),
        _cherry,
        s,
        fill: 0.24,
      );
      _glint(canvas, centre, s * 0.1, s);
    }
  }

  static void _drawLeaf(
    Canvas canvas,
    double s,
    Offset base,
    double length,
    double tilt,
  ) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    _neon(
      canvas,
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(length * 0.5, -length * 0.4, length, 0)
        ..quadraticBezierTo(length * 0.5, length * 0.3, 0, 0)
        ..close(),
      _leaf,
      s,
      width: 0.028,
      fill: 0.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CherryRunSymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.dimmed != dimmed;
}

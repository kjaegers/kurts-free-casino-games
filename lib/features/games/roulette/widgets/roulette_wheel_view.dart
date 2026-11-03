import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../logic/roulette_wheel.dart';
import 'roulette_chip.dart';

/// The wheel and ball. When [spinToken] changes while [spinning], the wheel
/// turns clockwise and the ball rolls the other way for [duration], both
/// slowing until the ball drops into [pocket] at the top; if the spin is
/// settled early it jumps straight there. At rest the latest number is
/// shown in the middle.
class RouletteWheelView extends StatefulWidget {
  const RouletteWheelView({
    super.key,
    required this.pocket,
    required this.spinning,
    required this.spinToken,
    required this.duration,
    required this.size,
  });

  /// Where the ball lands (or has landed); null before the first spin.
  final int? pocket;
  final bool spinning;
  final int spinToken;
  final Duration duration;
  final double size;

  @override
  State<RouletteWheelView> createState() => _RouletteWheelViewState();
}

class _RouletteWheelViewState extends State<RouletteWheelView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this);

  static const double _step = 2 * math.pi / roulettePocketCount;

  /// The ball's laps of the wheel over a spin.
  static const int _ballTurns = 6;

  double _from = 0;
  double _to = 0;

  static double _restAngle(int? pocket) =>
      pocket == null ? 0 : -rouletteWheelOrder.indexOf(pocket) * _step;

  @override
  void initState() {
    super.initState();
    _to = _restAngle(widget.pocket);
  }

  @override
  void didUpdateWidget(RouletteWheelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning &&
        widget.spinToken != oldWidget.spinToken &&
        widget.duration > Duration.zero) {
      // Two to three clockwise turns, ending with the pocket at the top.
      _from = _restAngle(oldWidget.pocket);
      final target = _restAngle(widget.pocket);
      final extra = (target - _from) % (2 * math.pi);
      _to = _from + 4 * math.pi + extra;
      _animation
        ..duration = widget.duration
        ..forward(from: 0);
    } else if (!widget.spinning) {
      _animation.stop();
      _to = _restAngle(widget.pocket);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pocket = widget.pocket;
    final label = widget.spinning
        ? 'Roulette wheel, ball rolling'
        : pocket == null
        ? 'Roulette wheel'
        : 'Roulette wheel, landed on ${roulettePocketLabel(pocket)}';
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final rolling = widget.spinning && _animation.isAnimating;
            final t = rolling ? _animation.value : 1.0;
            final wheel = rolling
                ? _from + (_to - _from) * Curves.easeOutCubic.transform(t)
                : _to;
            // The ball runs the other way, ending at the top.
            final ball =
                -math.pi / 2 -
                (1 - Curves.easeOutQuad.transform(t)) *
                    _ballTurns *
                    2 *
                    math.pi;
            // It rides the outer track, then drops into the pockets.
            final drop = Curves.easeIn.transform(
              ((t - 0.6) / 0.3).clamp(0.0, 1.0),
            );
            return CustomPaint(
              painter: _WheelPainter(
                wheelAngle: wheel,
                ballAngle: ball,
                ballDrop: drop,
                showBall: pocket != null,
                centerNumber: rolling ? null : pocket,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({
    required this.wheelAngle,
    required this.ballAngle,
    required this.ballDrop,
    required this.showBall,
    required this.centerNumber,
  });

  final double wheelAngle;
  final double ballAngle;

  /// 0 on the outer track, 1 resting in a pocket.
  final double ballDrop;
  final bool showBall;
  final int? centerNumber;

  static const double _step = 2 * math.pi / roulettePocketCount;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Rim and ball track.
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3A2414));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = KfgColors.primary.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, r * 0.86, Paint()..color = const Color(0xFF1E1E28));

    // Pockets, from the outside of the ring to the inside.
    final outer = r * 0.84;
    final inner = r * 0.6;
    final ring = Rect.fromCircle(center: c, radius: (outer + inner) / 2);
    final divider = Paint()
      ..color = const Color(0xFFD4B26A)
      ..strokeWidth = math.max(0.6, r * 0.01);
    for (var i = 0; i < roulettePocketCount; i++) {
      final mid = wheelAngle + i * _step - math.pi / 2;
      canvas.drawArc(
        ring,
        mid - _step / 2,
        _step,
        false,
        Paint()
          ..color = roulettePocketColor(rouletteWheelOrder[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = outer - inner,
      );
      final edge = mid - _step / 2;
      canvas.drawLine(
        c + Offset(math.cos(edge), math.sin(edge)) * inner,
        c + Offset(math.cos(edge), math.sin(edge)) * outer,
        divider,
      );
    }
    if (r >= 60) {
      for (var i = 0; i < roulettePocketCount; i++) {
        final mid = wheelAngle + i * _step - math.pi / 2;
        _text(
          canvas,
          '${rouletteWheelOrder[i]}',
          c + Offset(math.cos(mid), math.sin(mid)) * (outer - r * 0.07),
          r * 0.075,
          rotation: mid + math.pi / 2,
        );
      }
    }

    // The cone in the middle, with the latest number on it.
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF5A3A22), Color(0xFF2A1A10)],
        ).createShader(Rect.fromCircle(center: c, radius: inner)),
    );
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..color = const Color(0xFFD4B26A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.02),
    );
    final number = centerNumber;
    if (number != null) {
      canvas.drawCircle(
        c,
        inner * 0.62,
        Paint()..color = roulettePocketColor(number),
      );
      canvas.drawCircle(
        c,
        inner * 0.62,
        Paint()
          ..color = KfgColors.warning
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, r * 0.025),
      );
      _text(canvas, '$number', c, inner * 0.62, bold: true);
    } else {
      canvas.drawCircle(
        c,
        inner * 0.18,
        Paint()..color = const Color(0xFFD4B26A),
      );
    }

    if (showBall) {
      final track = r * 0.93;
      final rest = (outer + inner) / 2 + (outer - inner) * 0.18;
      final at = track + (rest - track) * ballDrop;
      final ball = c + Offset(math.cos(ballAngle), math.sin(ballAngle)) * at;
      final ballRadius = math.max(2.5, r * 0.055);
      canvas.drawCircle(
        ball.translate(0.8, 1.2),
        ballRadius,
        Paint()..color = Colors.black.withValues(alpha: 0.5),
      );
      canvas.drawCircle(ball, ballRadius, Paint()..color = Colors.white);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    double fontSize, {
    double rotation = 0,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          fontFamily: KfgFonts.family,
          fontFamilyFallback: KfgFonts.fallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rotation);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.wheelAngle != wheelAngle ||
      oldDelegate.ballAngle != ballAngle ||
      oldDelegate.ballDrop != ballDrop ||
      oldDelegate.showBall != showBall ||
      oldDelegate.centerNumber != centerNumber;
}

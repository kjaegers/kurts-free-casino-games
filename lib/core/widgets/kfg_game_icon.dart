import 'package:flutter/material.dart';

import '../models/game_definition.dart';

/// A game's menu icon: its [GameDefinition.iconBuilder] when it has one
/// (for glyphs Material Icons lacks), otherwise its [GameDefinition.icon].
class KfgGameIcon extends StatelessWidget {
  const KfgGameIcon({
    super.key,
    required this.game,
    required this.color,
    required this.size,
  });

  final GameDefinition game;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final builder = game.iconBuilder;
    if (builder == null) return Icon(game.icon, color: color, size: size);
    return ExcludeSemantics(child: builder(color, size));
  }
}

/// A two-cherry glyph, painted in one colour on a 24-unit grid like a
/// Material icon so it sits alongside them.
Widget kfgCherryIcon(Color color, double size) => SizedBox.square(
  dimension: size,
  child: CustomPaint(painter: _CherryIconPainter(color)),
);

class _CherryIconPainter extends CustomPainter {
  const _CherryIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Stems from each cherry up to a shared joint.
    canvas.drawPath(
      Path()
        ..moveTo(7, 13)
        ..quadraticBezierTo(8.5, 7, 14.5, 3.5)
        ..moveTo(17, 12)
        ..quadraticBezierTo(14.5, 8, 14.5, 3.5),
      stroke,
    );
    // Leaf off the joint.
    canvas.drawPath(
      Path()
        ..moveTo(14.5, 3.5)
        ..quadraticBezierTo(18, 1, 21.5, 3.5)
        ..quadraticBezierTo(18, 6.5, 14.5, 3.5)
        ..close(),
      fill,
    );
    canvas.drawCircle(const Offset(7, 17), 4.5, fill);
    canvas.drawCircle(const Offset(17, 16), 4.5, fill);
  }

  @override
  bool shouldRepaint(_CherryIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

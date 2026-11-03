import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../logic/roulette_game.dart';
import '../logic/roulette_wheel.dart';

/// The colour of a chip worth [value]; a stack takes the colour of the
/// largest chip value it reaches.
Color rouletteChipColor(int value) {
  var color = _chipColors.first;
  for (var i = 0; i < rouletteChipValues.length; i++) {
    if (value >= rouletteChipValues[i]) color = _chipColors[i];
  }
  return color;
}

const List<Color> _chipColors = [
  Color(0xFFE0E0E0),
  KfgColors.primary,
  KfgColors.highlight,
  KfgColors.secondary,
  KfgColors.warning,
];

/// [value] short enough for a chip: `1K` for a thousand.
String rouletteChipLabel(int value) =>
    value >= 1000 && value % 1000 == 0 ? '${value ~/ 1000}K' : '$value';

/// The felt colours of the numbers.
const Color rouletteRed = Color(0xFFC62828);
const Color rouletteBlack = Color(0xFF16161F);
const Color rouletteGreen = Color(0xFF1B7F3B);

Color roulettePocketColor(int number) => switch (rouletteColorOf(number)) {
  RouletteColor.red => rouletteRed,
  RouletteColor.black => rouletteBlack,
  RouletteColor.green => rouletteGreen,
};

/// A small round marker for a number that came up, in its colour.
class RouletteNumberBadge extends StatelessWidget {
  const RouletteNumberBadge({super.key, required this.number, this.size = 22});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: roulettePocketColor(number),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.48,
          ),
        ),
      ),
    );
  }
}

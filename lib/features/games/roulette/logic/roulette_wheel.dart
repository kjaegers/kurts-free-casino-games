/// The pockets of a European (single-zero) roulette wheel: 0 to 36, each
/// equally likely.
const int roulettePocketCount = 37;

/// The pockets in order clockwise around the wheel, starting from 0.
const List<int> rouletteWheelOrder = [
  0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, //
  5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
];

/// The red numbers; every other number from 1 to 36 is black, and 0 is
/// green.
const Set<int> rouletteRedNumbers = {
  1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36, //
};

enum RouletteColor {
  red('Red'),
  black('Black'),
  green('Green');

  const RouletteColor(this.label);

  final String label;
}

RouletteColor rouletteColorOf(int number) {
  if (number == 0) return RouletteColor.green;
  return rouletteRedNumbers.contains(number)
      ? RouletteColor.red
      : RouletteColor.black;
}

/// [number] with its colour, e.g. `17 Black`.
String roulettePocketLabel(int number) =>
    '$number ${rouletteColorOf(number).label}';

bool isRoulettePocket(Object? number) =>
    number is int && number >= 0 && number < roulettePocketCount;

import 'dart:math';

/// The symbols that drop into Retro Tech's grid, from the top of the
/// paytable down. [weight] is how many chances in [retroTechTotalWeight]
/// each new symbol has of being this one; the weights are published in
/// How to Play.
enum RetroTechSymbol {
  token('Arcade Token', 6),
  runner('Pixel Runner', 8),
  joystick('Joystick', 10),
  monitor('CRT Monitor', 11),
  floppy('Floppy Disk', 13),
  cartridge('Game Cartridge', 15),
  cassette('Cassette Tape', 17),
  chip('Microchip', 20);

  const RetroTechSymbol(this.label, this.weight);

  final String label;
  final int weight;
}

/// The sum of every symbol's [RetroTechSymbol.weight] (checked by a test).
const int retroTechTotalWeight = 100;

const int retroTechColumns = 5;
const int retroTechRows = 5;
const int retroTechCellCount = retroTechColumns * retroTechRows;

/// A grid of symbols, read row by row from the top left: the cell at
/// `row`, `column` is at [retroTechIndex].
typedef RetroTechGrid = List<RetroTechSymbol>;

int retroTechIndex(int row, int column) => row * retroTechColumns + column;

/// Draws the next symbol to drop into [column]. Columns are drawn
/// independently; the real game uses [retroTechFairDraw].
typedef RetroTechSymbolDraw = RetroTechSymbol Function(int column);

/// Every symbol drawn with the chance its weight gives it, from [random],
/// whatever column it drops into and whatever is already on the grid.
RetroTechSymbolDraw retroTechFairDraw(Random random) => (_) {
  var n = random.nextInt(retroTechTotalWeight);
  for (final symbol in RetroTechSymbol.values) {
    if (n < symbol.weight) return symbol;
    n -= symbol.weight;
  }
  throw StateError('Symbol weights do not add up to $retroTechTotalWeight');
};

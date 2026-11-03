import 'roulette_wheel.dart';

/// The kinds of bet on the table, with what each pays to 1.
///
/// Every kind returns the same 36 for every 37 bet in the long run
/// (97.30%): a bet covering n numbers pays 36 / n − 1 to 1.
enum RouletteBetKind {
  straight(35, 'Straight up'),
  split(17, 'Split'),
  street(11, 'Street'),
  trio(11, 'Trio'),
  corner(8, 'Corner'),
  firstFour(8, 'First four'),
  sixLine(5, 'Six line'),
  column(2, 'Column'),
  dozen(2, 'Dozen'),
  red(1, 'Red'),
  black(1, 'Black'),
  odd(1, 'Odd'),
  even(1, 'Even'),
  low(1, '1 to 18'),
  high(1, '19 to 36');

  const RouletteBetKind(this.pays, this.label);

  /// Winnings per credit staked, on top of the stake returned.
  final int pays;
  final String label;

  /// Bets on the numbers themselves, as opposed to the boxes outside them.
  bool get isInside => index <= sixLine.index;
}

/// One place to bet on the table. Every legal bet is in [rouletteBets];
/// look one up by [id] with [rouletteBetById].
///
/// The board is laid out in grid units: `u` runs along the table, one unit
/// per street of three numbers (0 sits in −1…0, the streets in 0…12 and the
/// column bets in 12…13), and `v` runs across it, one unit per column
/// (the 1-4-7 column is 0…1, then 1…2 and 2…3; the dozens are −1…0 and the
/// even-money boxes −2…−1). [spotU] and [spotV] are where the bet's chips
/// sit, which is also where tapping places it.
class RouletteBet {
  const RouletteBet._({
    required this.id,
    required this.kind,
    required this.numbers,
    required this.label,
    required this.spotU,
    required this.spotV,
  });

  /// A stable persistence key, e.g. `split:5-8` or `red`.
  final String id;
  final RouletteBetKind kind;

  /// The numbers covered, in ascending order.
  final List<int> numbers;

  /// A short name, e.g. `Split 5/8` or `1st 12`.
  final String label;
  final double spotU;
  final double spotV;

  int get pays => kind.pays;

  bool wins(int pocket) => numbers.contains(pocket);

  /// What a winning stake of [stake] pays back, the stake included.
  int payoutFor(int stake) => stake * (pays + 1);

  @override
  String toString() => id;
}

/// Every bet on the table, inside bets first.
final List<RouletteBet> rouletteBets = List.unmodifiable(_buildBets());

final Map<String, RouletteBet> _byId = {for (final b in rouletteBets) b.id: b};

/// The bet with [id], or null when there is none.
RouletteBet? rouletteBetById(Object? id) => id is String ? _byId[id] : null;

/// The number in street [row] (0–11) and column [col] (0–2).
int rouletteNumberAt(int row, int col) => row * 3 + col + 1;

/// Shortcuts for the bets a test or the controller needs by name.
RouletteBet rouletteStraight(int number) => _byId['straight:$number']!;
RouletteBet rouletteOutside(RouletteBetKind kind, [int index = 0]) =>
    switch (kind) {
      RouletteBetKind.column => _byId['column:${index + 1}']!,
      RouletteBetKind.dozen => _byId['dozen:${index + 1}']!,
      _ => _byId[kind.name]!,
    };

List<RouletteBet> _buildBets() {
  RouletteBet inside(
    RouletteBetKind kind,
    List<int> numbers,
    String label,
    double u,
    double v,
  ) {
    final sorted = List<int>.unmodifiable(List.of(numbers)..sort());
    return RouletteBet._(
      id: '${kind.name}:${sorted.join('-')}',
      kind: kind,
      numbers: sorted,
      label: label,
      spotU: u,
      spotV: v,
    );
  }

  final bets = <RouletteBet>[
    inside(RouletteBetKind.straight, [0], '0', -0.5, 1.5),
    for (var row = 0; row < 12; row++)
      for (var col = 0; col < 3; col++)
        inside(
          RouletteBetKind.straight,
          [rouletteNumberAt(row, col)],
          '${rouletteNumberAt(row, col)}',
          row + 0.5,
          col + 0.5,
        ),
    for (var col = 0; col < 3; col++)
      inside(
        RouletteBetKind.split,
        [0, col + 1],
        'Split 0/${col + 1}',
        0,
        col + 0.5,
      ),
    for (var row = 0; row < 12; row++)
      for (var col = 0; col < 2; col++)
        inside(
          RouletteBetKind.split,
          [rouletteNumberAt(row, col), rouletteNumberAt(row, col + 1)],
          'Split ${rouletteNumberAt(row, col)}/${rouletteNumberAt(row, col + 1)}',
          row + 0.5,
          col + 1.0,
        ),
    for (var row = 0; row < 11; row++)
      for (var col = 0; col < 3; col++)
        inside(
          RouletteBetKind.split,
          [rouletteNumberAt(row, col), rouletteNumberAt(row + 1, col)],
          'Split ${rouletteNumberAt(row, col)}/${rouletteNumberAt(row + 1, col)}',
          row + 1.0,
          col + 0.5,
        ),
    for (var row = 0; row < 12; row++)
      inside(
        RouletteBetKind.street,
        [for (var col = 0; col < 3; col++) rouletteNumberAt(row, col)],
        'Street ${rouletteNumberAt(row, 0)}–${rouletteNumberAt(row, 2)}',
        row + 0.5,
        0,
      ),
    inside(RouletteBetKind.trio, [0, 1, 2], 'Trio 0/1/2', 0, 1),
    inside(RouletteBetKind.trio, [0, 2, 3], 'Trio 0/2/3', 0, 2),
    for (var row = 0; row < 11; row++)
      for (var col = 0; col < 2; col++)
        inside(
          RouletteBetKind.corner,
          [
            rouletteNumberAt(row, col),
            rouletteNumberAt(row, col + 1),
            rouletteNumberAt(row + 1, col),
            rouletteNumberAt(row + 1, col + 1),
          ],
          'Corner ${rouletteNumberAt(row, col)}/'
          '${rouletteNumberAt(row, col + 1)}/'
          '${rouletteNumberAt(row + 1, col)}/'
          '${rouletteNumberAt(row + 1, col + 1)}',
          row + 1.0,
          col + 1.0,
        ),
    inside(RouletteBetKind.firstFour, [0, 1, 2, 3], 'First four 0–3', 0, 0),
    for (var row = 0; row < 11; row++)
      inside(
        RouletteBetKind.sixLine,
        [for (var n = 0; n < 6; n++) rouletteNumberAt(row, 0) + n],
        'Six line ${rouletteNumberAt(row, 0)}–${rouletteNumberAt(row + 1, 2)}',
        row + 1.0,
        0,
      ),
  ];

  RouletteBet outside(
    String id,
    RouletteBetKind kind,
    bool Function(int n) covers,
    String label,
    double u,
    double v,
  ) => RouletteBet._(
    id: id,
    kind: kind,
    numbers: List.unmodifiable([
      for (var n = 1; n <= 36; n++)
        if (covers(n)) n,
    ]),
    label: label,
    spotU: u,
    spotV: v,
  );

  const ordinals = ['1st', '2nd', '3rd'];
  return [
    ...bets,
    for (var col = 0; col < 3; col++)
      outside(
        'column:${col + 1}',
        RouletteBetKind.column,
        (n) => (n - 1) % 3 == col,
        'Column ${col + 1}–${34 + col}',
        12.5,
        col + 0.5,
      ),
    for (var d = 0; d < 3; d++)
      outside(
        'dozen:${d + 1}',
        RouletteBetKind.dozen,
        (n) => (n - 1) ~/ 12 == d,
        '${ordinals[d]} 12',
        d * 4 + 2.0,
        -0.5,
      ),
    // Along the table in the usual order: 1–18, Even, Red, Black, Odd, 19–36.
    outside('low', RouletteBetKind.low, (n) => n <= 18, '1–18', 1, -1.5),
    outside('even', RouletteBetKind.even, (n) => n.isEven, 'Even', 3, -1.5),
    outside(
      'red',
      RouletteBetKind.red,
      (n) => rouletteColorOf(n) == RouletteColor.red,
      'Red',
      5,
      -1.5,
    ),
    outside(
      'black',
      RouletteBetKind.black,
      (n) => rouletteColorOf(n) == RouletteColor.black,
      'Black',
      7,
      -1.5,
    ),
    outside('odd', RouletteBetKind.odd, (n) => n.isOdd, 'Odd', 9, -1.5),
    outside('high', RouletteBetKind.high, (n) => n > 18, '19–36', 11, -1.5),
  ];
}

/// The even-money boxes in order along the table, two streets each.
const List<RouletteBetKind> rouletteEvenMoneyOrder = [
  RouletteBetKind.low,
  RouletteBetKind.even,
  RouletteBetKind.red,
  RouletteBetKind.black,
  RouletteBetKind.odd,
  RouletteBetKind.high,
];

/// The bet placed by a tap at ([u], [v]) in grid units (see [RouletteBet]),
/// or null where there is none (off the table, or a blank corner).
///
/// A tap well inside a number bets on it. Near a line between two numbers
/// it splits them, near a crossing it takes the corner, and on the outer
/// edge of the 1-4-7 column it takes the street (or, at a crossing, the
/// six line). Along 0 the same rules give its splits, the trios and the
/// first four. [edgeU] and [edgeV] are how close, as a fraction of a cell,
/// a tap must be to a line to count as on it.
RouletteBet? rouletteBetAt(
  double u,
  double v, {
  double edgeU = 0.25,
  double edgeV = 0.25,
}) {
  if (u.isNaN || v.isNaN || u < -1 || u >= 13 || v < -2 || v >= 3) {
    return null;
  }
  if (v < 0) {
    if (u < 0 || u >= 12) return null;
    if (v < -1) {
      return rouletteOutside(rouletteEvenMoneyOrder[u ~/ 2]);
    }
    return rouletteOutside(RouletteBetKind.dozen, u ~/ 4);
  }
  final col = v.floor();
  if (u >= 12) return rouletteOutside(RouletteBetKind.column, col);

  final row = u.floor();
  final fu = u - row;
  final fv = v - col;
  // The line between streets the tap is on (0 = the line along 0), if any.
  int? line = fu < edgeU
      ? row
      : fu > 1 - edgeU
      ? row + 1
      : null;
  if (line != null && (line < 0 || line > 11)) line = null;
  // The line between columns (0 = the outer, street edge), if any; the far
  // edge of the 3-6-9 column takes no bet.
  int? edge = fv < edgeV
      ? col
      : fv > 1 - edgeV
      ? col + 1
      : null;
  if (edge == 3) edge = null;

  if (row < 0 && line == null) return rouletteStraight(0);
  if (line == 0) {
    return switch (edge) {
      null => _byId['split:0-${col + 1}'],
      0 => _byId['firstFour:0-1-2-3'],
      final e => _byId['trio:0-$e-${e + 1}'],
    };
  }
  if (line == null) {
    return switch (edge) {
      null => rouletteStraight(rouletteNumberAt(row, col)),
      0 => _betCovering(RouletteBetKind.street, rouletteNumberAt(row, 0)),
      final e =>
        _byId['split:${rouletteNumberAt(row, e - 1)}-'
            '${rouletteNumberAt(row, e)}'],
    };
  }
  return switch (edge) {
    null =>
      _byId['split:${rouletteNumberAt(line - 1, col)}-'
          '${rouletteNumberAt(line, col)}'],
    0 => _betCovering(RouletteBetKind.sixLine, rouletteNumberAt(line - 1, 0)),
    final e => _betCovering(
      RouletteBetKind.corner,
      rouletteNumberAt(line - 1, e - 1),
    ),
  };
}

/// The bet of [kind] whose lowest number is [lowest].
RouletteBet? _betCovering(RouletteBetKind kind, int lowest) {
  for (final bet in rouletteBets) {
    if (bet.kind == kind && bet.numbers.first == lowest) return bet;
  }
  return null;
}

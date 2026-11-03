/// The symbols on Cherry Run's reels, from the top of the paytable down.
enum CherryRunSymbol {
  seven('Seven'),
  tripleBar('Triple Bar'),
  doubleBar('Double Bar'),
  bar('Bar'),
  bell('Bell'),
  plum('Plum'),
  lemon('Lemon'),
  cherry('Cherry');

  const CherryRunSymbol(this.label);

  final String label;

  bool get isBar => this == bar || this == doubleBar || this == tripleBar;
}

const int cherryRunReelCount = 3;

/// Rows visible in the window: top, middle and bottom.
const int cherryRunRowCount = 3;

const _sev = CherryRunSymbol.seven;
const _tri = CherryRunSymbol.tripleBar;
const _dbl = CherryRunSymbol.doubleBar;
const _bar = CherryRunSymbol.bar;
const _bel = CherryRunSymbol.bell;
const _plm = CherryRunSymbol.plum;
const _lem = CherryRunSymbol.lemon;
const _chy = CherryRunSymbol.cherry;

// dart format off
/// The three reel strips, read top to bottom. Every reel carries the same
/// 28 symbols (one 7, two Triple Bars, three Double Bars, four Bars, four
/// Bells, five Plums, five Lemons and four Cherries), only in a different
/// order, and every stop is equally likely. What the player sees is the
/// whole reel: there are no hidden virtual stops weighting the odds.
const List<List<CherryRunSymbol>> cherryRunReels = [
  [
    _sev, _lem, _bar, _plm, _chy, _dbl, _bel,
    _lem, _plm, _bar, _chy, _tri, _plm, _bel,
    _lem, _dbl, _chy, _bar, _plm, _bel, _lem,
    _tri, _chy, _plm, _dbl, _bel, _lem, _bar,
  ],
  [
    _chy, _plm, _sev, _bel, _lem, _bar, _plm,
    _dbl, _chy, _lem, _bel, _tri, _plm, _bar,
    _lem, _chy, _dbl, _plm, _bel, _bar, _lem,
    _tri, _chy, _plm, _bel, _dbl, _lem, _bar,
  ],
  [
    _bel, _bar, _lem, _chy, _plm, _tri, _lem,
    _bel, _dbl, _plm, _chy, _bar, _sev, _plm,
    _lem, _bel, _dbl, _chy, _plm, _bar, _lem,
    _tri, _bel, _plm, _chy, _lem, _dbl, _bar,
  ],
];
// dart format on

/// Stops on each reel.
const int cherryRunStopCount = 28;

/// The symbol at [index] on [reel], wrapping around the strip.
CherryRunSymbol cherryRunSymbolAt(int reel, int index) =>
    cherryRunReels[reel][index % cherryRunStopCount];

/// The window for [stops] (one per reel, the stop on the middle row), as
/// rows top to bottom, each holding one symbol per reel.
List<List<CherryRunSymbol>> cherryRunWindow(List<int> stops) => [
  for (var row = 0; row < cherryRunRowCount; row++)
    [
      for (var reel = 0; reel < cherryRunReelCount; reel++)
        cherryRunSymbolAt(reel, stops[reel] + row - 1 + cherryRunStopCount),
    ],
];

import 'cherry_run_reels.dart';

/// Every paying line, in paytable order. [pays] is per credit bet on the
/// line, and includes that credit.
enum CherryRunWin {
  sevens('Three Sevens', 1000),
  tripleBars('Three Triple Bars', 100),
  doubleBars('Three Double Bars', 50),
  bars('Three Bars', 25),
  bells('Three Bells', 20),
  threeCherries('Three Cherries', 20),
  plums('Three Plums', 15),
  lemons('Three Lemons', 12),
  anyBars('Any Three Bars', 5),
  twoCherries('Two Cherries', 5),
  oneCherry('One Cherry', 2);

  const CherryRunWin(this.label, this.pays);

  final String label;
  final int pays;

  /// The paytable's picture of this win: three symbols, null meaning "any
  /// symbol", and for [anyBars] one of each bar.
  List<CherryRunSymbol?> get pattern => switch (this) {
    sevens => const [_sev, _sev, _sev],
    tripleBars => const [_tri, _tri, _tri],
    doubleBars => const [_dbl, _dbl, _dbl],
    bars => const [_bar, _bar, _bar],
    bells => const [_bel, _bel, _bel],
    threeCherries => const [_chy, _chy, _chy],
    plums => const [_plm, _plm, _plm],
    lemons => const [_lem, _lem, _lem],
    anyBars => const [_tri, _dbl, _bar],
    twoCherries => const [_chy, _chy, null],
    oneCherry => const [_chy, null, null],
  };
}

const _sev = CherryRunSymbol.seven;
const _tri = CherryRunSymbol.tripleBar;
const _dbl = CherryRunSymbol.doubleBar;
const _bar = CherryRunSymbol.bar;
const _bel = CherryRunSymbol.bell;
const _plm = CherryRunSymbol.plum;
const _lem = CherryRunSymbol.lemon;
const _chy = CherryRunSymbol.cherry;

/// What a line of three symbols (left to right) pays; null when nothing.
/// Only the best win on a line is paid: three Cherries are not also two.
/// Cherries count from the left reel: a Cherry on reel 1 pays whatever
/// follows it, one on reel 2 or 3 alone pays nothing.
CherryRunWin? evaluateCherryRunLine(List<CherryRunSymbol> line) {
  final [a, b, c] = line;
  if (a == b && b == c) {
    return switch (a) {
      CherryRunSymbol.seven => CherryRunWin.sevens,
      CherryRunSymbol.tripleBar => CherryRunWin.tripleBars,
      CherryRunSymbol.doubleBar => CherryRunWin.doubleBars,
      CherryRunSymbol.bar => CherryRunWin.bars,
      CherryRunSymbol.bell => CherryRunWin.bells,
      CherryRunSymbol.plum => CherryRunWin.plums,
      CherryRunSymbol.lemon => CherryRunWin.lemons,
      CherryRunSymbol.cherry => CherryRunWin.threeCherries,
    };
  }
  if (a.isBar && b.isBar && c.isBar) return CherryRunWin.anyBars;
  if (a == CherryRunSymbol.cherry) {
    return b == CherryRunSymbol.cherry
        ? CherryRunWin.twoCherries
        : CherryRunWin.oneCherry;
  }
  return null;
}

/// The long-run share of each credit bet that is paid back, worked out
/// exactly over every combination of stops. Each line is an independent
/// draw from the same reels, so it doesn't depend on the lines played or
/// the bet. Verified against [cherryRunReturnPercent] by a test.
double cherryRunTheoreticalReturn() {
  var paid = 0;
  for (final a in cherryRunReels[0]) {
    for (final b in cherryRunReels[1]) {
      for (final c in cherryRunReels[2]) {
        paid += evaluateCherryRunLine([a, b, c])?.pays ?? 0;
      }
    }
  }
  const combinations =
      cherryRunStopCount * cherryRunStopCount * cherryRunStopCount;
  return paid / combinations;
}

/// The theoretical return, as published in How to Play.
const String cherryRunReturnPercent = '96.26';

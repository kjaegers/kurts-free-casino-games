import 'retro_tech_cascade.dart';
import 'retro_tech_paytable.dart';
import 'retro_tech_symbols.dart';

/// Where a spin is.
enum RetroTechPhase {
  /// Waiting for the first spin of a session.
  ready,

  /// The whole cascade is decided and the bet is taken; the grid is still
  /// playing it out and the winnings are not paid yet.
  spinning,

  /// The cascade has played out and the spin has been paid.
  complete,
}

const int retroTechMinBetLevel = 1;
const int retroTechMaxBetLevel = 5;

const RetroTechSymbol _tok = RetroTechSymbol.token;
const RetroTechSymbol _run = RetroTechSymbol.runner;
const RetroTechSymbol _joy = RetroTechSymbol.joystick;
const RetroTechSymbol _mon = RetroTechSymbol.monitor;
const RetroTechSymbol _flp = RetroTechSymbol.floppy;
const RetroTechSymbol _crt = RetroTechSymbol.cartridge;
const RetroTechSymbol _cas = RetroTechSymbol.cassette;
const RetroTechSymbol _chp = RetroTechSymbol.chip;

// dart format off
/// What the grid shows before a session's first spin: every symbol, and no
/// cluster (checked by a test).
const RetroTechGrid retroTechRestingGrid = [
  _chp, _cas, _crt, _flp, _mon,
  _joy, _run, _tok, _chp, _cas,
  _crt, _flp, _mon, _joy, _run,
  _tok, _chp, _cas, _crt, _flp,
  _mon, _joy, _run, _tok, _chp,
];
// dart format on

/// One spin of Retro Tech as an immutable value. Transitions return a new
/// instance and throw [StateError] when illegal; check the matching `can…`
/// getter first.
///
/// Credits live outside the game: the bet ([totalBet]) is taken when [spin]
/// is called and [payout] is paid when the spin is [settle]d.
class RetroTechGame {
  const RetroTechGame._({
    required this.betLevel,
    required this.phase,
    this.result,
  });

  /// A fresh session waiting for the first spin.
  factory RetroTechGame.newSession({int betLevel = retroTechMinBetLevel}) {
    return RetroTechGame._(
      betLevel: betLevel.clamp(retroTechMinBetLevel, retroTechMaxBetLevel),
      phase: RetroTechPhase.ready,
    );
  }

  /// Bet levels 1–5, each [retroTechCreditsPerLevel] credits. Fixed from the
  /// spin until it is paid.
  final int betLevel;
  final RetroTechPhase phase;

  /// The spin played or playing; null before the first spin.
  final RetroTechSpinResult? result;

  int get totalBet => betLevel * retroTechCreditsPerLevel;

  bool get isSpinning => phase == RetroTechPhase.spinning;
  bool get isComplete => phase == RetroTechPhase.complete;

  bool get canChangeBet => !isSpinning;
  bool get canSpin => !isSpinning;
  bool get canSettle => isSpinning;

  /// The grid at rest: the last spin's final grid, or the resting grid.
  RetroTechGrid get grid => result?.finalGrid ?? retroTechRestingGrid;

  /// Credits paid by the spin (0 until paid).
  int get payout => isComplete ? pendingPayout : 0;

  /// What the spin will pay once settled.
  int get pendingPayout => (result?.pays ?? 0) * betLevel;

  /// Credits won by the first [steps] cascades, for the running total
  /// while the cascade plays out.
  int payoutAfter(int steps) {
    final spin = result;
    if (spin == null) return 0;
    var pays = 0;
    for (final step in spin.steps.take(steps)) {
      pays += step.pays;
    }
    return pays * betLevel;
  }

  RetroTechGame withBetLevel(int level) {
    if (!canChangeBet) throw StateError('The bet is fixed while spinning');
    if (level < retroTechMinBetLevel || level > retroTechMaxBetLevel) {
      throw RangeError.range(level, retroTechMinBetLevel, retroTechMaxBetLevel);
    }
    return RetroTechGame._(betLevel: level, phase: phase, result: result);
  }

  /// Starts a spin that plays out as [spin], resolved from fair draws.
  RetroTechGame spin(RetroTechSpinResult spin) {
    if (!canSpin) throw StateError('The grid is already spinning');
    return RetroTechGame._(
      betLevel: betLevel,
      phase: RetroTechPhase.spinning,
      result: spin,
    );
  }

  /// Ends the cascade; [payout] is now due.
  RetroTechGame settle() {
    if (!canSettle) throw StateError('Nothing is spinning');
    return RetroTechGame._(
      betLevel: betLevel,
      phase: RetroTechPhase.complete,
      result: result,
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  static const int schemaVersion = 1;

  /// Only a spin still playing out is worth saving: its bet has been taken
  /// and its winnings are not paid yet. The symbols drawn are enough to
  /// rebuild the whole cascade exactly.
  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'phase': phase.name,
    'betLevel': betLevel,
    'drops': [
      for (final column in result?.drops ?? const <List<RetroTechSymbol>>[])
        [for (final symbol in column) symbol.name],
    ],
  };

  /// Restores a spin saved while spinning. Returns null for anything
  /// malformed or not in progress, never throwing.
  static RetroTechGame? fromJson(Map<String, dynamic> json) {
    final betLevel = json['betLevel'];
    final drops = json['drops'];
    if (json['version'] != schemaVersion ||
        json['phase'] != RetroTechPhase.spinning.name ||
        betLevel is! int ||
        betLevel < retroTechMinBetLevel ||
        betLevel > retroTechMaxBetLevel ||
        drops is! List) {
      return null;
    }
    final columns = <List<RetroTechSymbol>>[];
    for (final column in drops) {
      if (column is! List) return null;
      final symbols = <RetroTechSymbol>[];
      for (final name in column) {
        final symbol = RetroTechSymbol.values.asNameMap()[name];
        if (symbol == null) return null;
        symbols.add(symbol);
      }
      columns.add(symbols);
    }
    final result = RetroTechSpinResult.replay(columns);
    if (result == null) return null;
    return RetroTechGame._(
      betLevel: betLevel,
      phase: RetroTechPhase.spinning,
      result: result,
    );
  }
}

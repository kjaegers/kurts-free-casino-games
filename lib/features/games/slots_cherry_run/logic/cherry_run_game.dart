import 'cherry_run_paytable.dart';
import 'cherry_run_reels.dart';

/// Where a spin is.
enum CherryRunPhase {
  /// Waiting for the first spin of a session.
  ready,

  /// The stops are decided and the bet is taken; the reels are still
  /// turning and the winnings are not paid yet.
  spinning,

  /// The reels have stopped and the spin has been paid.
  complete,
}

const int cherryRunMinLines = 1;
const int cherryRunMaxLines = 3;
const int cherryRunMinBetPerLine = 1;
const int cherryRunMaxBetPerLine = 5;

/// The window row each line runs along, by line number - 1: line 1 is the
/// middle row, line 2 the top and line 3 the bottom.
const List<int> cherryRunLineRows = [1, 0, 2];

/// Where the reels rest before a session's first spin.
const List<int> cherryRunRestingStops = [4, 4, 4];

/// One paying line of a spin.
class CherryRunLineWin {
  const CherryRunLineWin({
    required this.line,
    required this.win,
    required this.payout,
  });

  /// The line number, 1–3.
  final int line;
  final CherryRunWin win;

  /// Credits paid for the line at the spin's bet per line.
  final int payout;

  int get row => cherryRunLineRows[line - 1];
}

/// One spin of Cherry Run as an immutable value. Transitions return a new
/// instance and throw [StateError] when illegal; check the matching `can…`
/// getter first.
///
/// Credits live outside the game: the bet ([totalBet]) is taken when [spin]
/// is called and [payout] is paid when the spin is [settle]d.
class CherryRunGame {
  const CherryRunGame._({
    required this.lines,
    required this.betPerLine,
    required this.stops,
    required this.phase,
  });

  /// A fresh session waiting for the first spin.
  factory CherryRunGame.newSession({
    int lines = cherryRunMaxLines,
    int betPerLine = cherryRunMinBetPerLine,
  }) {
    return CherryRunGame._(
      lines: lines.clamp(cherryRunMinLines, cherryRunMaxLines),
      betPerLine: betPerLine.clamp(
        cherryRunMinBetPerLine,
        cherryRunMaxBetPerLine,
      ),
      stops: cherryRunRestingStops,
      phase: CherryRunPhase.ready,
    );
  }

  /// Lines played, 1–3. Fixed from the spin until it is paid.
  final int lines;

  /// Credits bet on each line played, 1–5.
  final int betPerLine;

  /// The stop on the middle row of each reel.
  final List<int> stops;
  final CherryRunPhase phase;

  int get totalBet => lines * betPerLine;

  bool get isSpinning => phase == CherryRunPhase.spinning;
  bool get isComplete => phase == CherryRunPhase.complete;

  bool get canChangeBet => !isSpinning;
  bool get canSpin => !isSpinning;
  bool get canSettle => isSpinning;

  /// The symbols in view, as rows top to bottom.
  List<List<CherryRunSymbol>> get window => cherryRunWindow(stops);

  /// Whether line [line] (1–3) is being played.
  bool isLineActive(int line) => line >= 1 && line <= lines;

  /// The paying lines of the spin (decided as soon as it starts); empty
  /// before the first spin.
  List<CherryRunLineWin> get lineWins {
    if (phase == CherryRunPhase.ready) return const [];
    final rows = window;
    return [
      for (var line = 1; line <= lines; line++)
        if (evaluateCherryRunLine(rows[cherryRunLineRows[line - 1]])
            case final win?)
          CherryRunLineWin(line: line, win: win, payout: win.pays * betPerLine),
    ];
  }

  /// Credits paid by the spin, the sum of its [lineWins] (0 until paid).
  int get payout => isComplete ? pendingPayout : 0;

  /// What the spin will pay once settled.
  int get pendingPayout => lineWins.fold(0, (sum, w) => sum + w.payout);

  CherryRunGame withLines(int count) {
    if (!canChangeBet) throw StateError('The bet is fixed while spinning');
    if (count < cherryRunMinLines || count > cherryRunMaxLines) {
      throw RangeError.range(count, cherryRunMinLines, cherryRunMaxLines);
    }
    return _copyWith(lines: count);
  }

  CherryRunGame withBetPerLine(int credits) {
    if (!canChangeBet) throw StateError('The bet is fixed while spinning');
    if (credits < cherryRunMinBetPerLine || credits > cherryRunMaxBetPerLine) {
      throw RangeError.range(
        credits,
        cherryRunMinBetPerLine,
        cherryRunMaxBetPerLine,
      );
    }
    return _copyWith(betPerLine: credits);
  }

  /// Starts a spin that will stop at [newStops], one uniformly random stop
  /// per reel.
  CherryRunGame spin(List<int> newStops) {
    if (!canSpin) throw StateError('The reels are already spinning');
    if (!_validStops(newStops)) throw ArgumentError.value(newStops, 'stops');
    return _copyWith(
      stops: List.unmodifiable(newStops),
      phase: CherryRunPhase.spinning,
    );
  }

  /// Stops the reels; [payout] is now due.
  CherryRunGame settle() {
    if (!canSettle) throw StateError('Nothing is spinning');
    return _copyWith(phase: CherryRunPhase.complete);
  }

  CherryRunGame _copyWith({
    int? lines,
    int? betPerLine,
    List<int>? stops,
    CherryRunPhase? phase,
  }) {
    return CherryRunGame._(
      lines: lines ?? this.lines,
      betPerLine: betPerLine ?? this.betPerLine,
      stops: stops ?? this.stops,
      phase: phase ?? this.phase,
    );
  }

  static bool _validStops(List<Object?> stops) =>
      stops.length == cherryRunReelCount &&
      stops.every((s) => s is int && s >= 0 && s < cherryRunStopCount);

  // ── Persistence ────────────────────────────────────────────────────────────

  static const int schemaVersion = 1;

  /// Only a spin still turning is worth saving: its bet has been taken and
  /// its winnings are not paid yet.
  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'phase': phase.name,
    'lines': lines,
    'betPerLine': betPerLine,
    'stops': stops,
  };

  /// Restores a spin saved while spinning. Returns null for anything
  /// malformed or not in progress, never throwing.
  static CherryRunGame? fromJson(Map<String, dynamic> json) {
    final lines = json['lines'];
    final betPerLine = json['betPerLine'];
    final stops = json['stops'];
    if (json['version'] != schemaVersion ||
        json['phase'] != CherryRunPhase.spinning.name ||
        lines is! int ||
        lines < cherryRunMinLines ||
        lines > cherryRunMaxLines ||
        betPerLine is! int ||
        betPerLine < cherryRunMinBetPerLine ||
        betPerLine > cherryRunMaxBetPerLine ||
        stops is! List ||
        !_validStops(stops)) {
      return null;
    }
    return CherryRunGame._(
      lines: lines,
      betPerLine: betPerLine,
      stops: List.unmodifiable(stops.cast<int>()),
      phase: CherryRunPhase.spinning,
    );
  }
}

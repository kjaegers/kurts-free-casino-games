import 'roulette_bets.dart';
import 'roulette_wheel.dart';

/// Where a spin is.
enum RoulettePhase {
  /// Placing chips, before the first spin or after changing the bets.
  betting,

  /// The pocket is decided and the stake is taken; the ball is still
  /// rolling and the winnings are not paid yet.
  spinning,

  /// The ball has landed and the spin has been paid. The chips stay on the
  /// table, so the next SPIN bets them again.
  complete,
}

/// The chip values, smallest first.
const List<int> rouletteChipValues = [1, 5, 25, 100, 500];

/// The most that can be staked on any one bet.
const int rouletteMaxStakePerBet = 1000;

/// One chip (or several of one value) put down on a bet.
class RouletteChipPlacement {
  const RouletteChipPlacement(this.bet, this.amount);

  final RouletteBet bet;
  final int amount;
}

/// One winning bet of a spin.
class RouletteWin {
  const RouletteWin({required this.bet, required this.stake});

  final RouletteBet bet;
  final int stake;

  /// Credits paid back, the stake included.
  int get payout => bet.payoutFor(stake);
}

/// A roulette table as an immutable value: the chips on it and the latest
/// spin. Transitions return a new instance and throw [StateError] when
/// illegal; check the matching `can…` getter first.
///
/// Credits live outside the game: the stake ([totalBet]) is taken when
/// [spin] is called and [payout] is paid when the spin is [settle]d.
class RouletteGame {
  const RouletteGame._({
    required this.placements,
    required this.phase,
    required this.pocket,
  });

  /// An empty table waiting for bets.
  const RouletteGame.newTable()
    : placements = const [],
      phase = RoulettePhase.betting,
      pocket = null;

  /// Every chip on the table, in the order placed (so the last can be
  /// taken back).
  final List<RouletteChipPlacement> placements;
  final RoulettePhase phase;

  /// Where the latest spin's ball landed (or will land, while spinning);
  /// null before the first spin.
  final int? pocket;

  bool get isSpinning => phase == RoulettePhase.spinning;
  bool get isComplete => phase == RoulettePhase.complete;

  /// The stake on each bet, in the order each was first placed.
  Map<RouletteBet, int> get stakes {
    final result = <RouletteBet, int>{};
    for (final p in placements) {
      result[p.bet] = (result[p.bet] ?? 0) + p.amount;
    }
    return result;
  }

  int stakeOn(RouletteBet bet) =>
      placements.where((p) => p.bet == bet).fold(0, (sum, p) => sum + p.amount);

  int get totalBet => placements.fold(0, (sum, p) => sum + p.amount);

  bool get canChangeBets => !isSpinning;
  bool get canSpin => !isSpinning && placements.isNotEmpty;
  bool get canSettle => isSpinning;

  /// Whether a chip of [amount] fits under the table limit on [bet].
  bool canPlace(RouletteBet bet, int amount) =>
      canChangeBets &&
      amount > 0 &&
      stakeOn(bet) + amount <= rouletteMaxStakePerBet;

  /// The winning bets of the spin (decided as soon as it starts); empty
  /// before the first spin and while the bets are being changed.
  List<RouletteWin> get wins {
    final landed = pocket;
    if (landed == null || phase == RoulettePhase.betting) return const [];
    return [
      for (final MapEntry(key: bet, value: stake) in stakes.entries)
        if (bet.wins(landed)) RouletteWin(bet: bet, stake: stake),
    ];
  }

  /// Credits paid by the spin (0 until paid).
  int get payout => isComplete ? pendingPayout : 0;

  /// What the spin will pay once settled.
  int get pendingPayout => wins.fold(0, (sum, w) => sum + w.payout);

  /// Puts a chip of [amount] on [bet].
  RouletteGame place(RouletteBet bet, int amount) {
    if (!canPlace(bet, amount)) {
      throw StateError('Cannot place $amount on ${bet.id}');
    }
    return _betting([...placements, RouletteChipPlacement(bet, amount)]);
  }

  /// Takes back the chip placed last.
  RouletteGame undo() {
    if (!canChangeBets || placements.isEmpty) {
      throw StateError('Nothing to take back');
    }
    return _betting(placements.sublist(0, placements.length - 1));
  }

  /// Takes every chip off the table.
  RouletteGame clear() {
    if (!canChangeBets) throw StateError('The bets are fixed while spinning');
    return _betting(const []);
  }

  RouletteGame _betting(List<RouletteChipPlacement> next) => RouletteGame._(
    placements: List.unmodifiable(next),
    phase: RoulettePhase.betting,
    pocket: pocket,
  );

  /// Spins the chips on the table; the ball will land in [landing], a
  /// uniformly random pocket.
  RouletteGame spin(int landing) {
    if (!canSpin) throw StateError('Nothing to spin');
    if (!isRoulettePocket(landing)) {
      throw ArgumentError.value(landing, 'landing');
    }
    return RouletteGame._(
      placements: placements,
      phase: RoulettePhase.spinning,
      pocket: landing,
    );
  }

  /// The ball has landed; [payout] is now due.
  RouletteGame settle() {
    if (!canSettle) throw StateError('Nothing is spinning');
    return RouletteGame._(
      placements: placements,
      phase: RoulettePhase.complete,
      pocket: pocket,
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  static const int schemaVersion = 1;

  /// Only a spin still rolling is worth saving: its stake has been taken
  /// and its winnings are not paid yet.
  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'phase': phase.name,
    'pocket': pocket,
    'placements': [
      for (final p in placements) [p.bet.id, p.amount],
    ],
  };

  /// Restores a spin saved while rolling. Returns null for anything
  /// malformed or not in progress, never throwing.
  static RouletteGame? fromJson(Map<String, dynamic> json) {
    final pocket = json['pocket'];
    final rawPlacements = json['placements'];
    if (json['version'] != schemaVersion ||
        json['phase'] != RoulettePhase.spinning.name ||
        !isRoulettePocket(pocket) ||
        rawPlacements is! List ||
        rawPlacements.isEmpty) {
      return null;
    }
    var game = const RouletteGame.newTable();
    for (final raw in rawPlacements) {
      if (raw is! List || raw.length != 2) return null;
      final bet = rouletteBetById(raw[0]);
      final amount = raw[1];
      if (bet == null || amount is! int || !game.canPlace(bet, amount)) {
        return null;
      }
      game = game.place(bet, amount);
    }
    return game.spin(pocket as int);
  }
}

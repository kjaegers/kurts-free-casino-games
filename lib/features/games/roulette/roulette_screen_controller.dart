import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/animation/kfg_web_animation_speed.dart'
    show kfgReduceMotion;
import '../../../core/audio/kfg_tone_player.dart';
import '../../../core/haptics/kfg_haptics.dart';
import '../../../core/models/achievement.dart';
import '../../../core/models/roulette_stats.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/services/stats_service.dart';
import 'logic/roulette_achievements.dart';
import 'logic/roulette_bets.dart';
import 'logic/roulette_game.dart';
import 'logic/roulette_wheel.dart';
import 'roulette_save_service.dart';

/// Picks the pocket the ball lands in: 0 to [roulettePocketCount] - 1.
typedef RoulettePocketPicker = int Function();

/// Flutter-facing controller for Roulette. Wraps the pure [RouletteGame]
/// rules and owns everything around them: the shared credit balance, the
/// chip in hand, the autosave, stats, achievements, sounds and the spin
/// timing.
///
/// Where the ball lands is decided the moment SPIN is pressed, every pocket
/// equally likely; the wheel only reveals it. Nothing about the balance,
/// the bets or past spins influences it.
class RouletteScreenController extends ChangeNotifier {
  RouletteScreenController({
    StatsService? stats,
    CreditsService? credits,
    RouletteSaveService? saveService,
    RoulettePocketPicker? pickPocket,
    KfgTonePlayer? tonePlayer,
    DateTime Function()? clock,
    bool Function()? reduceMotion,
  }) : _stats = stats ?? StatsService.instance,
       _credits = credits ?? CreditsService.instance,
       _saveService = saveService ?? RouletteSaveService(),
       _pickPocket = pickPocket ?? fairPocketPicker(Random()),
       _tones =
           tonePlayer ??
           KfgTonePlayer(
             toneDuration: const Duration(milliseconds: 70),
             amplitude: 0.2,
           ),
       _clock = clock ?? DateTime.now,
       _reduceMotion = reduceMotion ?? (() => kfgReduceMotion);

  final StatsService _stats;
  final CreditsService _credits;
  final RouletteSaveService _saveService;
  final RoulettePocketPicker _pickPocket;
  final KfgTonePlayer _tones;
  final DateTime Function() _clock;
  final bool Function() _reduceMotion;

  /// Every pocket equally likely, drawn from [random].
  static RoulettePocketPicker fairPocketPicker(Random random) =>
      () => random.nextInt(roulettePocketCount);

  /// How long the wheel turns before the ball settles. A real-world time,
  /// the same on every platform (not stretched on web like cosmetic
  /// animations); reduce motion skips it.
  static const Duration spinDuration = Duration(seconds: 4);

  /// How many of the latest numbers the table shows.
  static const int historyLength = 12;

  /// A spin counts toward time played for at most this long after the last
  /// one, so a game left open isn't counted as played.
  static const Duration maxSpinInterval = Duration(minutes: 2);

  bool _initialized = false;
  bool _disposed = false;

  RouletteGame _game = const RouletteGame.newTable();
  int _chip = 5;

  /// Bumped on every spin; the wheel starts turning when it changes.
  int _spinToken = 0;
  Duration _spinDuration = Duration.zero;
  Timer? _spinTimer;

  /// The numbers that came up this session, newest first.
  List<int> _history = const [];

  /// A note about the last thing the player did at the table, shown until
  /// the next spin.
  String? _notice;

  List<AchievementDefinition> _newAchievements = const [];

  DateTime? _activeSince;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isInitialized => _initialized;
  RouletteGame get game => _game;
  int get chip => _chip;
  int get totalBet => _game.totalBet;
  int get balance => _credits.balance;
  int get spinToken => _spinToken;
  List<int> get history => _history;
  RouletteStats get stats => _stats.rouletteStats;

  /// How long the wheel turns on the current spin (zero once stopped
  /// early, and under reduce motion).
  Duration get spinDurationNow => _spinDuration;

  bool get isSpinning => _game.isSpinning;
  bool get canChangeBets => _initialized && _game.canChangeBets;
  bool get canUndo => canChangeBets && _game.placements.isNotEmpty;
  bool get canSpin =>
      _initialized && _game.canSpin && _credits.canAfford(totalBet);
  bool get canSkip => _initialized && _game.isSpinning;

  /// Too few credits for even the smallest chip: offer the refill.
  bool get isBroke => _credits.balance < rouletteChipValues.first;

  /// Enough credits for some bet, just not the chips on the table.
  bool get betTooHigh =>
      _initialized && !isSpinning && !isBroke && !_credits.canAfford(totalBet);

  /// Returns the achievements first unlocked by the spin just paid (already
  /// saved) and clears them, so they're announced only once.
  List<AchievementDefinition> takeNewAchievements() {
    final result = _newAchievements;
    _newAchievements = const [];
    return result;
  }

  /// The status line under the table.
  String get message {
    if (_game.isSpinning) return 'No more bets…';
    // A notice is cleared by every spin, so the result always shows first.
    final result = _game.isComplete ? _resultMessage() : null;
    if (isBroke) {
      return result == null
          ? 'Out of credits: tap FREE REFILL to keep playing'
          : '$result. Out of credits: tap FREE REFILL';
    }
    if (_notice case final notice?) return notice;
    if (betTooHigh) {
      return result == null
          ? 'Not enough credits for a ${formatCredits(totalBet)}-credit '
                'bet: undo or clear some chips'
          : '$result. Not enough credits to bet the same again';
    }
    if (result != null) return result;
    if (_game.placements.isEmpty) {
      return 'Tap the table to place ${formatCredits(_chip)}-credit chips';
    }
    return 'Place more chips, or SPIN';
  }

  String _resultMessage() {
    final landed = roulettePocketLabel(_game.pocket!);
    final wins = _game.wins;
    if (wins.isEmpty) return '$landed · no win this spin';
    final pays = formatCredits(_game.payout);
    if (wins.length == 1) {
      return '$landed · ${wins.single.bet.label} wins: pays $pays';
    }
    return '$landed · ${wins.length} bets win: pays $pays';
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Pays a spin that was still rolling when the app closed (never spinning
  /// it again), otherwise opens an empty table with the last-used chip.
  Future<void> initialize() async {
    await _stats.ensureLoaded();
    await _credits.ensureLoaded();
    final saved = await _saveService.load();
    if (_disposed) return;
    _credits.addListener(_notify);

    _chip = _stats.rouletteStats.preferredChip;
    _initialized = true;
    if (saved != null) {
      _game = saved;
      _spinToken++;
      _settle();
    }
    _activeSince = _clock();
    _notify();
  }

  // ── Betting ────────────────────────────────────────────────────────────────

  /// Picks up chips of [value] for the next taps on the table.
  bool selectChip(int value) {
    if (!_initialized || !rouletteChipValues.contains(value)) return false;
    if (value == _chip) return true;
    _chip = value;
    _stats.setRoulettePreferences(chip: value);
    unawaited(
      _tones.playFrequency(440 + rouletteChipValues.indexOf(value) * 40),
    );
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  /// Puts the chip in hand on [bet], within the table limit and what the
  /// balance covers.
  bool placeChip(RouletteBet bet) {
    if (!canChangeBets || isBroke) return false;
    if (!_game.canPlace(bet, _chip)) {
      _notice =
          'The table limit is ${formatCredits(rouletteMaxStakePerBet)} on '
          'each bet';
      _refused();
      return false;
    }
    if (!_credits.canAfford(totalBet + _chip)) {
      _notice = 'Not enough credits for another ${formatCredits(_chip)} chip';
      _refused();
      return false;
    }
    _game = _game.place(bet, _chip);
    final stake = _game.stakeOn(bet);
    _notice =
        '${bet.label} (pays ${bet.pays} to 1): ${formatCredits(stake)} on it';
    unawaited(_tones.playFrequency(520));
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  void _refused() {
    unawaited(_tones.playFrequency(220));
    unawaited(KfgHaptics.light());
    _notify();
  }

  /// Takes back the chip placed last.
  bool undo() {
    if (!canUndo) return false;
    final last = _game.placements.last;
    _game = _game.undo();
    _notice = 'Took back ${formatCredits(last.amount)} from ${last.bet.label}';
    unawaited(_tones.playFrequency(392));
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  /// Takes every chip off the table.
  bool clearBets() {
    if (!canUndo) return false;
    _game = _game.clear();
    _notice = null;
    unawaited(_tones.playFrequency(349));
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  /// Gives a broke player a fresh [CreditsService.startingBalance], free.
  bool refillCredits() {
    if (!_initialized || !isBroke || isSpinning) return false;
    _credits.reset();
    _notice = null;
    unawaited(_tones.playFrequency(660));
    _notify();
    return true;
  }

  // ── Play ───────────────────────────────────────────────────────────────────

  /// SPIN while betting, SKIP while the ball rolls.
  bool spinOrSkip() => isSpinning ? skip() : spin();

  /// Takes the stake and spins; the ball lands in a uniformly random pocket.
  bool spin() {
    if (!canSpin) return false;
    if (!_credits.debit(totalBet)) return false;
    _game = _game.spin(_pickPocket());
    _spinToken++;
    _notice = null;
    unawaited(_saveService.save(_game));
    unawaited(_tones.playFrequency(392));
    unawaited(KfgHaptics.light());
    if (_reduceMotion()) {
      _settle();
      return true;
    }
    _spinDuration = spinDuration;
    _spinTimer = Timer(spinDuration, () => _settle(landed: true));
    _notify();
    return true;
  }

  /// Shows where the ball lands at once (it was always going there) and
  /// pays the spin.
  bool skip() {
    if (!canSkip) return false;
    _settle();
    return true;
  }

  /// Pays the spin and records it, exactly once. [landed] when the wheel
  /// stopped on its own rather than with SKIP.
  void _settle({bool landed = false}) {
    _spinTimer?.cancel();
    _spinTimer = null;
    if (!_game.canSettle) return;
    _spinDuration = Duration.zero;
    final previous = _history.isEmpty ? null : _history.first;
    _game = _game.settle();
    _history = List.unmodifiable(
      [_game.pocket!, ..._history].take(historyLength),
    );
    final payout = _game.payout;
    _credits.credit(payout);
    unawaited(_saveService.clear());
    _record(previous);
    if (!_disposed && payout > 0) {
      unawaited(_tones.playFrequency(payout > totalBet ? 784 : 659));
      unawaited(KfgHaptics.medium());
    } else if (!_disposed && landed) {
      unawaited(_tones.playFrequency(330));
      unawaited(KfgHaptics.selection());
    }
    _notify();
  }

  void _record(int? previousPocket) {
    final now = _clock();
    final since = _activeSince;
    var seconds = 0;
    if (since != null) {
      final played = now.difference(since);
      seconds = (played > maxSpinInterval ? maxSpinInterval : played).inSeconds;
    }
    if (since != null) _activeSince = now;
    final wins = _game.wins;
    _stats.recordRouletteSpin(
      RouletteSpinRecord(
        bet: totalBet,
        payout: _game.payout,
        pocket: _game.pocket!,
        straightWins: wins
            .where((w) => w.bet.kind == RouletteBetKind.straight)
            .length,
      ),
      durationSeconds: seconds,
    );
    final check = checkRouletteAchievements(
      game: _game,
      previousPocket: previousPocket,
      insideKindsWon: _stats
          .achievementState(RouletteAchievementIds.insideStory)
          .progress,
    );
    _newAchievements = [
      ..._newAchievements,
      ..._stats.recordAchievements(
        earned: check.earned,
        progress: {
          if (check.insideKinds.isNotEmpty)
            RouletteAchievementIds.insideStory: check.insideKinds,
        },
        now: now,
      ),
    ];
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Settles a rolling spin and stops the play clock while the app is in
  /// the background.
  void pause() {
    skip();
    _activeSince = null;
  }

  void resume() {
    _activeSince ??= _clock();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A spin still rolling is paid before the controller goes away.
  @override
  void dispose() {
    _disposed = true;
    _settle();
    _credits.removeListener(_notify);
    _tones.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/animation/kfg_web_animation_speed.dart'
    show kfgReduceMotion;
import '../../../core/audio/kfg_tone_player.dart';
import '../../../core/haptics/kfg_haptics.dart';
import '../../../core/models/achievement.dart';
import '../../../core/models/slots_cherry_run_stats.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/services/stats_service.dart';
import 'logic/cherry_run_achievements.dart';
import 'logic/cherry_run_game.dart';
import 'logic/cherry_run_reels.dart';
import 'slots_cherry_run_save_service.dart';

/// Picks where [reel] stops: an index from 0 to [cherryRunStopCount] - 1.
typedef CherryRunStopPicker = int Function(int reel);

/// Picks the pause between one reel stopping and the next.
typedef CherryRunStopGapPicker = Duration Function();

/// Flutter-facing controller for Slots: Cherry Run. Wraps the pure
/// [CherryRunGame] rules and owns everything around them: the shared credit
/// balance, the autosave, stats, achievements, sounds and the reel timing.
///
/// Where the reels stop is decided the moment SPIN is pressed, each reel
/// independently and uniformly; the animation only reveals it. Nothing
/// about the balance, the bet or past spins influences the stops, and the
/// pauses between reels stopping are drawn separately, without looking at
/// the stops, so a slow last reel never hints at a win.
class CherryRunScreenController extends ChangeNotifier {
  CherryRunScreenController({
    StatsService? stats,
    CreditsService? credits,
    CherryRunSaveService? saveService,
    CherryRunStopPicker? pickStop,
    CherryRunStopGapPicker? pickStopGap,
    KfgTonePlayer? tonePlayer,
    DateTime Function()? clock,
    bool Function()? reduceMotion,
  }) : _stats = stats ?? StatsService.instance,
       _credits = credits ?? CreditsService.instance,
       _saveService = saveService ?? CherryRunSaveService(),
       _pickStop = pickStop ?? fairStopPicker(Random()),
       _pickStopGap = pickStopGap ?? randomStopGap(Random()),
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
  final CherryRunSaveService _saveService;
  final CherryRunStopPicker _pickStop;
  final CherryRunStopGapPicker _pickStopGap;
  final KfgTonePlayer _tones;
  final DateTime Function() _clock;
  final bool Function() _reduceMotion;

  /// Every stop on every reel equally likely, drawn from [random].
  static CherryRunStopPicker fairStopPicker(Random random) =>
      (reel) => random.nextInt(cherryRunStopCount);

  /// The pause between reels stopping, uniform between [minStopGap] and
  /// [maxStopGap], drawn from [random].
  static CherryRunStopGapPicker randomStopGap(Random random) =>
      () =>
          minStopGap +
          Duration(
            milliseconds: random.nextInt(
              (maxStopGap - minStopGap).inMilliseconds + 1,
            ),
          );

  /// How long all the reels turn before the first one stops.
  static const Duration firstReelStop = Duration(seconds: 2);

  /// The shortest and longest pause before each later reel stops.
  static const Duration minStopGap = Duration(milliseconds: 500);
  static const Duration maxStopGap = Duration(seconds: 2);

  /// These are real-world times, the same on every platform (not stretched
  /// on web like cosmetic animations); reduce motion skips them.

  /// A spin counts toward time played for at most this long after the last
  /// one, so a game left open isn't counted as played.
  static const Duration maxSpinInterval = Duration(minutes: 2);

  bool _initialized = false;
  bool _disposed = false;

  CherryRunGame _game = CherryRunGame.newSession();

  /// Bumped on every spin; the reels start turning when it changes.
  int _spinToken = 0;
  List<Duration> _reelDurations = const [
    Duration.zero,
    Duration.zero,
    Duration.zero,
  ];
  final List<Timer> _reelTimers = [];
  int _reelsStopped = 0;

  List<AchievementDefinition> _newAchievements = const [];

  DateTime? _activeSince;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isInitialized => _initialized;
  CherryRunGame get game => _game;
  int get lines => _game.lines;
  int get betPerLine => _game.betPerLine;
  int get totalBet => _game.totalBet;
  int get balance => _credits.balance;
  int get spinToken => _spinToken;
  CherryRunStats get stats => _stats.cherryRunStats;

  /// How long each reel turns on the current spin (zero once stopped
  /// early, and under reduce motion).
  List<Duration> get reelDurations => _reelDurations;

  /// How many reels, from the left, have stopped on the current spin.
  int get reelsStopped => _reelsStopped;

  bool get isSpinning => _game.isSpinning;
  bool get canChangeBet => _initialized && _game.canChangeBet;
  bool get canSpin =>
      _initialized && _game.canSpin && _credits.canAfford(totalBet);
  bool get canStop => _initialized && _game.isSpinning;

  /// Too few credits for even a one-line, one-credit bet: offer the refill.
  bool get isBroke => _credits.balance < cherryRunMinBetPerLine;

  /// Enough credits for some bet, just not the one chosen.
  bool get betTooHigh =>
      _initialized && !isSpinning && !isBroke && !_credits.canAfford(totalBet);

  /// Returns the achievements first unlocked by the spin just paid (already
  /// saved) and clears them, so they're announced only once.
  List<AchievementDefinition> takeNewAchievements() {
    final result = _newAchievements;
    _newAchievements = const [];
    return result;
  }

  /// The status line under the reels.
  String get message {
    switch (_game.phase) {
      case CherryRunPhase.ready:
      case CherryRunPhase.complete:
        if (isBroke) return 'Out of credits: tap FREE REFILL to keep playing';
        if (betTooHigh) {
          return 'Not enough credits for a ${formatCredits(totalBet)}-credit '
              'bet: lower your bet';
        }
        if (_game.phase == CherryRunPhase.ready) {
          return 'Choose lines and bet, then SPIN';
        }
        final wins = _game.lineWins;
        if (wins.isEmpty) return 'No win this spin';
        final pays = formatCredits(_game.payout);
        if (wins.length == 1) {
          return 'Line ${wins.single.line} · ${wins.single.win.label}: '
              'pays $pays';
        }
        final numbers = [for (final w in wins) '${w.line}'];
        final last = numbers.removeLast();
        return 'Lines ${numbers.join(', ')} & $last win: pays $pays';
      case CherryRunPhase.spinning:
        return 'Spinning…';
    }
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Pays a spin that was still turning when the app closed (never spinning
  /// it again), otherwise starts a session with the last-used bet.
  Future<void> initialize() async {
    await _stats.ensureLoaded();
    await _credits.ensureLoaded();
    final saved = await _saveService.load();
    if (_disposed) return;
    _credits.addListener(_notify);

    final prefs = _stats.cherryRunStats;
    _game = CherryRunGame.newSession(
      lines: prefs.preferredLines,
      betPerLine: prefs.preferredBetPerLine,
    );
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

  /// Plays one more line, wrapping from 3 back to 1.
  bool changeLines() {
    if (!canChangeBet) return false;
    final next = lines >= cherryRunMaxLines ? cherryRunMinLines : lines + 1;
    _game = _game.withLines(next);
    _stats.setCherryRunPreferences(lines: next);
    _betFeedback(next);
    return true;
  }

  /// Adds a credit to the bet per line, wrapping from 5 back to 1.
  bool betOne() {
    if (!canChangeBet) return false;
    final next = betPerLine >= cherryRunMaxBetPerLine
        ? cherryRunMinBetPerLine
        : betPerLine + 1;
    _game = _game.withBetPerLine(next);
    _stats.setCherryRunPreferences(betPerLine: next);
    _betFeedback(next);
    return true;
  }

  /// Bets the most the balance covers, up to 3 lines at 5 credits each,
  /// and spins.
  bool maxBet() {
    if (!canChangeBet || isBroke) return false;
    final balance = _credits.balance;
    final perLine = min(cherryRunMaxBetPerLine, balance ~/ cherryRunMaxLines);
    final lineCount = perLine == 0 ? balance : cherryRunMaxLines;
    _game = _game
        .withLines(lineCount)
        .withBetPerLine(max(perLine, cherryRunMinBetPerLine));
    _stats.setCherryRunPreferences(lines: lines, betPerLine: betPerLine);
    return spin();
  }

  void _betFeedback(int step) {
    unawaited(_tones.playFrequency(440 + step * 40));
    unawaited(KfgHaptics.selection());
    _notify();
  }

  /// Gives a broke player a fresh [CreditsService.startingBalance], free.
  bool refillCredits() {
    if (!_initialized || !isBroke || isSpinning) return false;
    _credits.reset();
    unawaited(_tones.playFrequency(660));
    _notify();
    return true;
  }

  // ── Play ───────────────────────────────────────────────────────────────────

  /// SPIN when the reels are still, STOP while they turn.
  bool spinOrStop() => isSpinning ? stopReels() : spin();

  /// Takes the bet and spins, each reel stopping at a uniformly random stop.
  bool spin() {
    if (!canSpin) return false;
    if (!_credits.debit(totalBet)) return false;
    final stops = [
      for (var reel = 0; reel < cherryRunReelCount; reel++) _pickStop(reel),
    ];
    _game = _game.spin(stops);
    _spinToken++;
    _reelsStopped = 0;
    unawaited(_saveService.save(_game));
    unawaited(_tones.playFrequency(392));
    unawaited(KfgHaptics.light());
    if (_reduceMotion()) {
      _settle();
      return true;
    }
    var at = firstReelStop;
    _reelDurations = List.unmodifiable([
      for (var reel = 0; reel < cherryRunReelCount; reel++)
        reel == 0 ? at : at += _pickStopGap(),
    ]);
    for (var reel = 0; reel < cherryRunReelCount; reel++) {
      _reelTimers.add(Timer(_reelDurations[reel], () => _reelStopped(reel)));
    }
    _notify();
    return true;
  }

  /// A reel has come to rest: a click for each, and the last one pays.
  void _reelStopped(int reel) {
    _reelsStopped = reel + 1;
    if (_reelsStopped == cherryRunReelCount) {
      _settle(landed: true);
      return;
    }
    unawaited(_tones.playFrequency(330));
    unawaited(KfgHaptics.selection());
    _notify();
  }

  /// Stops the reels at once (they land where they were always going to)
  /// and pays the spin.
  bool stopReels() {
    if (!canStop) return false;
    _settle();
    return true;
  }

  /// Pays the spin and records it, exactly once. [landed] when the last
  /// reel stopped on its own rather than with STOP.
  void _settle({bool landed = false}) {
    for (final timer in _reelTimers) {
      timer.cancel();
    }
    _reelTimers.clear();
    if (!_game.canSettle) return;
    _reelsStopped = cherryRunReelCount;
    _reelDurations = const [Duration.zero, Duration.zero, Duration.zero];
    _game = _game.settle();
    final payout = _game.payout;
    _credits.credit(payout);
    unawaited(_saveService.clear());
    _record();
    if (!_disposed && payout > 0) {
      unawaited(_tones.playFrequency(payout > totalBet ? 784 : 659));
      unawaited(KfgHaptics.medium());
    } else if (!_disposed && landed) {
      unawaited(_tones.playFrequency(330));
      unawaited(KfgHaptics.selection());
    }
    _notify();
  }

  void _record() {
    final now = _clock();
    final since = _activeSince;
    var seconds = 0;
    if (since != null) {
      final played = now.difference(since);
      seconds = (played > maxSpinInterval ? maxSpinInterval : played).inSeconds;
    }
    if (since != null) _activeSince = now;
    _stats.recordCherryRunSpin(
      CherryRunSpinRecord(
        bet: totalBet,
        payout: _game.payout,
        winNames: [for (final w in _game.lineWins) w.win.name],
      ),
      durationSeconds: seconds,
    );
    final check = checkCherryRunAchievements(
      game: _game,
      fruitsWon: _stats
          .achievementState(CherryRunAchievementIds.fruitSalad)
          .progress,
    );
    _newAchievements = [
      ..._newAchievements,
      ..._stats.recordAchievements(
        earned: check.earned,
        progress: {
          if (check.fruits.isNotEmpty)
            CherryRunAchievementIds.fruitSalad: check.fruits,
        },
        now: now,
      ),
    ];
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Settles a turning spin and stops the play clock while the app is in
  /// the background.
  void pause() {
    stopReels();
    _activeSince = null;
  }

  void resume() {
    _activeSince ??= _clock();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A spin still turning is paid before the controller goes away.
  @override
  void dispose() {
    _disposed = true;
    _settle();
    _credits.removeListener(_notify);
    _tones.dispose();
    super.dispose();
  }
}

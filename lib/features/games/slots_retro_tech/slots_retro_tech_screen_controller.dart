import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/audio/kfg_tone_player.dart';
import '../../../core/haptics/kfg_haptics.dart';
import '../../../core/models/achievement.dart';
import '../../../core/models/slots_retro_tech_stats.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/services/stats_service.dart';
import 'logic/retro_tech_achievements.dart';
import 'logic/retro_tech_cascade.dart';
import 'logic/retro_tech_game.dart';
import 'logic/retro_tech_paytable.dart';
import 'logic/retro_tech_symbols.dart';
import 'slots_retro_tech_save_service.dart';

/// What the grid is showing while a spin plays out.
enum RetroTechBeat {
  /// Symbols falling into [RetroTechScreenController.gridIndex]: the first
  /// fill, or the survivors and new symbols after a cascade.
  falling,

  /// The winning clusters of the grid shown, lit before they vanish.
  winning,
}

/// Flutter-facing controller for Slots: Retro Tech. Wraps the pure
/// [RetroTechGame] rules and owns everything around them: the shared credit
/// balance, the autosave, stats, achievements, sounds and the pacing of the
/// cascade.
///
/// Every symbol of the spin, every cascade included, is drawn the moment
/// SPIN is pressed; the grid only plays the result out. Nothing about the
/// balance, the bet or past spins influences the draws.
class RetroTechScreenController extends ChangeNotifier {
  RetroTechScreenController({
    StatsService? stats,
    CreditsService? credits,
    RetroTechSaveService? saveService,
    RetroTechSymbolDraw? draw,
    KfgTonePlayer? tonePlayer,
    DateTime Function()? clock,
    Duration Function(Duration)? animationDuration,
  }) : _stats = stats ?? StatsService.instance,
       _credits = credits ?? CreditsService.instance,
       _saveService = saveService ?? RetroTechSaveService(),
       _draw = draw ?? retroTechFairDraw(Random()),
       _tones =
           tonePlayer ??
           KfgTonePlayer(
             toneDuration: const Duration(milliseconds: 70),
             amplitude: 0.2,
           ),
       _clock = clock ?? DateTime.now,
       _pace = animationDuration ?? ((d) => d);

  final StatsService _stats;
  final CreditsService _credits;
  final RetroTechSaveService _saveService;
  final RetroTechSymbolDraw _draw;
  final KfgTonePlayer _tones;
  final DateTime Function() _clock;

  /// Scales the pacing below; tests pass zero to play a spin out at once.
  final Duration Function(Duration) _pace;

  /// How long the first fill takes to drop in.
  static const Duration firstFall = Duration(milliseconds: 750);

  /// How long winning clusters stay lit before vanishing.
  static const Duration winHold = Duration(milliseconds: 1100);

  /// How long survivors and new symbols take to fall after a cascade.
  static const Duration cascadeFall = Duration(milliseconds: 650);

  /// These are real-world times, the same on every platform (not stretched
  /// on web like cosmetic animations). Under reduce motion the grid cuts
  /// rather than moves, but keeps this pace so every win can be read; STOP
  /// skips to the end.

  /// A spin counts toward time played for at most this long after the last
  /// one, so a game left open isn't counted as played.
  static const Duration maxSpinInterval = Duration(minutes: 2);

  bool _initialized = false;
  bool _disposed = false;

  RetroTechGame _game = RetroTechGame.newSession();

  /// Bumped on every beat; the grid animates when it changes.
  int _beatToken = 0;
  RetroTechBeat _beat = RetroTechBeat.falling;
  int _gridIndex = 0;
  Duration _beatDuration = Duration.zero;
  Timer? _beatTimer;

  List<AchievementDefinition> _newAchievements = const [];

  DateTime? _activeSince;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isInitialized => _initialized;
  RetroTechGame get game => _game;
  int get betLevel => _game.betLevel;
  int get totalBet => _game.totalBet;
  int get balance => _credits.balance;
  RetroTechStats get stats => _stats.retroTechStats;

  int get beatToken => _beatToken;
  RetroTechBeat get beat => _beat;

  /// Which of the spin's grids is on show while it plays out.
  int get gridIndex => _gridIndex;

  /// How long the current beat's fall takes.
  Duration get beatDuration => _beatDuration;

  /// The winning clusters lit right now (empty unless [beat] is winning).
  List<RetroTechCluster> get litClusters {
    final result = _game.result;
    if (!_game.isSpinning ||
        _beat != RetroTechBeat.winning ||
        result == null ||
        _gridIndex >= result.steps.length) {
      return const [];
    }
    return result.steps[_gridIndex].clusters;
  }

  /// Credits won so far: cascades already lit while spinning, the whole
  /// spin once paid.
  int get runningWin {
    if (!_game.isSpinning) return _game.payout;
    final lit = _gridIndex + (_beat == RetroTechBeat.winning ? 1 : 0);
    return _game.payoutAfter(lit);
  }

  bool get isSpinning => _game.isSpinning;
  bool get canChangeBet => _initialized && _game.canChangeBet;
  bool get canSpin =>
      _initialized && _game.canSpin && _credits.canAfford(totalBet);
  bool get canStop => _initialized && _game.isSpinning;

  /// Too few credits for even the smallest bet: offer the refill.
  bool get isBroke =>
      _credits.balance < retroTechMinBetLevel * retroTechCreditsPerLevel;

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

  /// The status line under the grid.
  String get message {
    switch (_game.phase) {
      case RetroTechPhase.ready:
      case RetroTechPhase.complete:
        if (isBroke) return 'Out of credits: tap FREE REFILL to keep playing';
        if (betTooHigh) {
          return 'Not enough credits for a ${formatCredits(totalBet)}-credit '
              'bet: lower your bet';
        }
        final result = _game.result;
        if (_game.phase == RetroTechPhase.ready || result == null) {
          return 'Choose your bet, then SPIN';
        }
        if (result.cascades == 0) return 'No win this spin';
        final pays = formatCredits(_game.payout);
        if (result.cascades == 1) {
          return '${describeRetroTechClusters(result.steps.single.clusters)}: '
              'pays $pays';
        }
        return '${result.cascades} cascades: pays $pays';
      case RetroTechPhase.spinning:
        final lit = litClusters;
        if (lit.isEmpty) return _gridIndex == 0 ? 'Spinning…' : 'Cascading…';
        final pays = formatCredits(
          lit.fold(0, (sum, c) => sum + c.pays) * betLevel,
        );
        final prefix = _gridIndex == 0 ? '' : 'Cascade ${_gridIndex + 1} · ';
        return '$prefix${describeRetroTechClusters(lit)}: $pays';
    }
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Pays a spin that was still playing out when the app closed (never
  /// spinning it again), otherwise starts a session with the last-used bet.
  Future<void> initialize() async {
    await _stats.ensureLoaded();
    await _credits.ensureLoaded();
    final saved = await _saveService.load();
    if (_disposed) return;
    _credits.addListener(_notify);

    _game = RetroTechGame.newSession(
      betLevel: _stats.retroTechStats.preferredBetLevel,
    );
    _initialized = true;
    if (saved != null) {
      _game = saved;
      _settle();
    }
    _activeSince = _clock();
    _notify();
  }

  // ── Betting ────────────────────────────────────────────────────────────────

  /// Raises the bet one level, wrapping from 5 back to 1.
  bool betOne() {
    if (!canChangeBet) return false;
    final next = betLevel >= retroTechMaxBetLevel
        ? retroTechMinBetLevel
        : betLevel + 1;
    _game = _game.withBetLevel(next);
    _stats.setRetroTechPreferences(betLevel: next);
    unawaited(_tones.playFrequency(440 + next * 40));
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  /// Bets the highest level the balance covers, up to 5, and spins.
  bool maxBet() {
    if (!canChangeBet || isBroke) return false;
    final level = min(
      retroTechMaxBetLevel,
      _credits.balance ~/ retroTechCreditsPerLevel,
    );
    _game = _game.withBetLevel(level);
    _stats.setRetroTechPreferences(betLevel: level);
    return spin();
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

  /// SPIN when the grid is still, STOP while it plays out.
  bool spinOrStop() => isSpinning ? stopCascade() : spin();

  /// Takes the bet and draws the whole spin, then plays it out.
  bool spin() {
    if (!canSpin) return false;
    if (!_credits.debit(totalBet)) return false;
    _game = _game.spin(RetroTechSpinResult.resolve(_draw));
    unawaited(_saveService.save(_game));
    unawaited(_tones.playFrequency(392));
    unawaited(KfgHaptics.light());
    _startBeat(RetroTechBeat.falling, 0, firstFall);
    return true;
  }

  /// Shows [gridIndex] in [beat] for [duration], then moves on.
  void _startBeat(RetroTechBeat beat, int gridIndex, Duration duration) {
    _beatTimer?.cancel();
    final paced = _pace(duration);
    if (paced <= Duration.zero) {
      _settle();
      return;
    }
    _beat = beat;
    _gridIndex = gridIndex;
    _beatDuration = paced;
    _beatToken++;
    _beatTimer = Timer(paced, _nextBeat);
    _notify();
  }

  /// After a fall, light the grid's clusters if it has any (or finish);
  /// after a win, cascade into the next grid (or finish at the cap).
  void _nextBeat() {
    final result = _game.result;
    if (_disposed || !_game.isSpinning || result == null) return;
    if (_beat == RetroTechBeat.falling) {
      if (_gridIndex >= result.steps.length) {
        _settle(landed: true);
        return;
      }
      // A rising note for each cascade in the chain.
      unawaited(_tones.playFrequency(523 + 66.0 * min(_gridIndex, 6)));
      unawaited(KfgHaptics.light());
      _startBeat(RetroTechBeat.winning, _gridIndex, winHold);
      return;
    }
    if (_gridIndex + 1 >= result.grids.length) {
      _settle(landed: true);
      return;
    }
    _startBeat(RetroTechBeat.falling, _gridIndex + 1, cascadeFall);
  }

  /// Skips to the end of the cascade (it ends where it was always going
  /// to) and pays the spin.
  bool stopCascade() {
    if (!canStop) return false;
    _settle();
    return true;
  }

  /// Pays the spin and records it, exactly once. [landed] when it played
  /// out on its own rather than with STOP.
  void _settle({bool landed = false}) {
    _beatTimer?.cancel();
    _beatTimer = null;
    if (!_game.canSettle) return;
    _beat = RetroTechBeat.falling;
    _beatDuration = Duration.zero;
    _game = _game.settle();
    _gridIndex = _game.result!.grids.length - 1;
    final payout = _game.payout;
    _credits.credit(payout);
    unawaited(_saveService.clear());
    _record();
    if (!_disposed && payout > totalBet) {
      unawaited(_tones.playFrequency(784));
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
      _activeSince = now;
    }
    final result = _game.result!;
    _stats.recordRetroTechSpin(
      RetroTechSpinRecord(
        bet: totalBet,
        payout: _game.payout,
        cascades: result.cascades,
        clusterSymbols: [
          for (final step in result.steps)
            for (final c in step.clusters) c.symbol.name,
        ],
      ),
      durationSeconds: seconds,
    );
    final check = checkRetroTechAchievements(
      game: _game,
      symbolsWon: _stats
          .achievementState(RetroTechAchievementIds.fullCollection)
          .progress,
    );
    _newAchievements = [
      ..._newAchievements,
      ..._stats.recordAchievements(
        earned: check.earned,
        progress: {
          if (check.symbols.isNotEmpty)
            RetroTechAchievementIds.fullCollection: check.symbols,
        },
        now: now,
      ),
    ];
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Settles a spin still playing out and stops the play clock while the
  /// app is in the background.
  void pause() {
    stopCascade();
    _activeSince = null;
  }

  void resume() {
    _activeSince ??= _clock();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A spin still playing out is paid before the controller goes away.
  @override
  void dispose() {
    _disposed = true;
    _settle();
    _credits.removeListener(_notify);
    _tones.dispose();
    super.dispose();
  }
}

/// "5 Microchips", or "3 clusters" when there's more than one.
String describeRetroTechClusters(List<RetroTechCluster> clusters) {
  if (clusters.length == 1) {
    final c = clusters.single;
    return '${c.size} ${c.symbol.label}s';
  }
  return '${clusters.length} clusters';
}

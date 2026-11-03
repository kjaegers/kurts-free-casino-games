import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/audio/kfg_tone_player.dart';
import '../../../core/cards/card_deck_factory.dart';
import '../../../core/cards/playing_card.dart';
import '../../../core/haptics/kfg_haptics.dart';
import '../../../core/models/achievement.dart';
import '../../../core/models/video_poker_stats.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/services/stats_service.dart';
import 'logic/video_poker_achievements.dart';
import 'logic/video_poker_game.dart';
import 'logic/video_poker_variant.dart';
import 'video_poker_save_service.dart';

/// Returns a full, shuffled deck for [variant] (with its jokers, if any).
typedef VideoPokerDeckShuffler =
    List<PlayingCard> Function(VideoPokerVariant variant);

/// Flutter-facing controller for Video Poker. Wraps the pure
/// [VideoPokerGame] rules and owns everything around them: the shared credit
/// balance, the autosave, stats, achievements, sounds and the deal/draw
/// animation cue.
///
/// The cards are decided the moment DEAL or DRAW is pressed; the animation
/// only reveals them. Every deck is a fresh, unbiased shuffle: nothing about
/// the balance, the bet or past hands influences what is dealt.
class VideoPokerScreenController extends ChangeNotifier {
  VideoPokerScreenController({
    StatsService? stats,
    CreditsService? credits,
    VideoPokerSaveService? saveService,
    VideoPokerDeckShuffler? shuffleDeck,
    KfgTonePlayer? tonePlayer,
    DateTime Function()? clock,
  }) : _stats = stats ?? StatsService.instance,
       _credits = credits ?? CreditsService.instance,
       _saveService = saveService ?? VideoPokerSaveService(),
       _shuffleDeck = shuffleDeck ?? _fairShuffle,
       _tones =
           tonePlayer ??
           KfgTonePlayer(
             toneDuration: const Duration(milliseconds: 70),
             amplitude: 0.2,
           ),
       _clock = clock ?? DateTime.now;

  final StatsService _stats;
  final CreditsService _credits;
  final VideoPokerSaveService _saveService;
  final VideoPokerDeckShuffler _shuffleDeck;
  final KfgTonePlayer _tones;
  final DateTime Function() _clock;

  static final Random _random = Random();

  static List<PlayingCard> _fairShuffle(VideoPokerVariant variant) =>
      const CardDeckFactory().createShuffledDeck(
        random: _random,
        jokers: variant.jokers,
      );

  bool _initialized = false;
  bool _disposed = false;

  VideoPokerGame _game = VideoPokerGame.newSession(
    variant: VideoPokerVariant.jacksOrBetter,
  );

  /// Bumped on every deal and draw; the cards animate in when it changes.
  int _dealToken = 0;

  List<AchievementDefinition> _newAchievements = const [];

  int _handMs = 0;
  DateTime? _handRunningSince;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isInitialized => _initialized;
  VideoPokerGame get game => _game;
  VideoPokerVariant get variant => _game.variant;
  int get bet => _game.bet;
  int get dealToken => _dealToken;
  int get balance => _credits.balance;
  VideoPokerStats get stats => _stats.videoPokerStats;

  bool get canChangeBet => _initialized && _game.canChangeBet;
  bool get canDeal => _initialized && _game.canDeal && _credits.canAfford(bet);
  bool get canToggleHold => _initialized && _game.canToggleHold;
  bool get canDraw => _initialized && _game.canDraw;

  /// A new session (and a different variant) can start between hands.
  bool get canChangeVariant => _initialized && !_game.isHolding;

  /// Too few credits for even a one-coin bet: offer the free refill.
  bool get isBroke => _credits.balance < videoPokerMinBet;

  /// Enough credits for some bet, just not the one chosen.
  bool get betTooHigh =>
      _initialized && !_game.isHolding && !isBroke && !_credits.canAfford(bet);

  /// Returns the achievements first unlocked by the hand just completed
  /// (already saved) and clears them, so they're announced only once.
  List<AchievementDefinition> takeNewAchievements() {
    final result = _newAchievements;
    _newAchievements = const [];
    return result;
  }

  /// The status line under the cards.
  String get message {
    final g = _game;
    switch (g.phase) {
      case VideoPokerPhase.betting:
        if (isBroke) return 'Out of credits: tap FREE REFILL to keep playing';
        if (betTooHigh) {
          return 'Not enough credits for $bet coins: lower your bet';
        }
        return 'Choose your bet, then DEAL';
      case VideoPokerPhase.holding:
        final current = g.currentHand;
        final dealt = current == null ? '' : '${variant.labelFor(current)}! ';
        return '${dealt}Tap cards to HOLD, then DRAW';
      case VideoPokerPhase.complete:
        final result = g.result;
        if (result == null) return 'No win. Play again?';
        return '${variant.labelFor(result)}: pays ${formatCredits(g.payout)}';
    }
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Resumes a dealt hand exactly as it was (never redealing), otherwise
  /// starts a session with the last-used variant and bet.
  Future<void> initialize() async {
    await _stats.ensureLoaded();
    await _credits.ensureLoaded();
    final saved = await _saveService.load();
    if (_disposed) return;
    _credits.addListener(_notify);

    if (saved != null) {
      _game = saved;
      _dealToken++;
      _handRunningSince = _clock();
    } else {
      final prefs = _stats.videoPokerStats;
      _game = VideoPokerGame.newSession(
        variant: VideoPokerVariant.fromName(prefs.preferredVariantName),
        bet: prefs.preferredBet,
      );
    }
    _initialized = true;
    _notify();
  }

  /// Starts a new session of [variant] between hands, remembering it for
  /// next time. The bet carries over.
  bool startSession(VideoPokerVariant variant) {
    if (!canChangeVariant) return false;
    _stats.setVideoPokerPreferences(variantName: variant.name);
    _game = VideoPokerGame.newSession(variant: variant, bet: bet);
    _notify();
    return true;
  }

  // ── Betting ────────────────────────────────────────────────────────────────

  /// Adds a coin to the bet, wrapping from 5 back to 1.
  bool betOne() {
    if (!canChangeBet) return false;
    return _setBet(bet >= videoPokerMaxBet ? videoPokerMinBet : bet + 1);
  }

  /// Sets the bet to 5 coins (or as many as the balance covers) and deals.
  bool betMax() {
    if (!canChangeBet || isBroke) return false;
    _setBet(min(videoPokerMaxBet, _credits.balance));
    return deal();
  }

  bool _setBet(int coins) {
    _game = _game.withBet(coins);
    _stats.setVideoPokerPreferences(bet: coins);
    unawaited(_tones.playFrequency(440 + coins * 40));
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  /// Gives a broke player a fresh [CreditsService.startingBalance], free.
  bool refillCredits() {
    if (!_initialized || !isBroke) return false;
    _credits.reset();
    unawaited(_tones.playFrequency(660));
    _notify();
    return true;
  }

  // ── Play ───────────────────────────────────────────────────────────────────

  /// DEAL between hands, DRAW while holding.
  bool dealOrDraw() => _game.isHolding ? draw() : deal();

  /// Takes the bet and deals five new cards from a fresh shuffle.
  bool deal() {
    if (!canDeal) return false;
    if (!_credits.debit(bet)) return false;
    _game = _game.deal(_shuffleDeck(variant));
    _dealToken++;
    _handMs = 0;
    _handRunningSince = _clock();
    unawaited(_saveService.save(_game));
    unawaited(_tones.playFrequency(392));
    unawaited(KfgHaptics.light());
    _notify();
    return true;
  }

  bool toggleHold(int index) {
    if (!canToggleHold || index < 0 || index >= videoPokerHandSize) {
      return false;
    }
    _game = _game.toggleHold(index);
    unawaited(_tones.playFrequency(_game.held[index] ? 587 : 494));
    unawaited(KfgHaptics.selection());
    unawaited(_saveService.save(_game));
    _notify();
    return true;
  }

  /// Replaces the cards not held, pays the final hand and records it.
  bool draw() {
    if (!canDraw) return false;
    _game = _game.draw();
    _dealToken++;
    final payout = _game.payout;
    _credits.credit(payout);
    unawaited(_saveService.clear());
    _record();
    if (payout > 0) {
      unawaited(_tones.playFrequency(payout > bet ? 784 : 659));
      unawaited(KfgHaptics.medium());
    } else {
      unawaited(_tones.playFrequency(262));
    }
    _notify();
    return true;
  }

  void _record() {
    final since = _handRunningSince;
    if (since != null) _handMs += _clock().difference(since).inMilliseconds;
    _handRunningSince = null;
    final result = _game.result;
    _stats.recordVideoPokerHand(
      VideoPokerHandRecord(
        variantName: variant.name,
        handName: result?.name,
        bet: bet,
        payout: _game.payout,
      ),
      durationSeconds: _handMs ~/ 1000,
    );
    final progress = _stats.achievementState(
      VideoPokerAchievementIds.everyVariant,
    );
    final check = checkVideoPokerAchievements(
      game: _game,
      variantsPaid: progress.progress,
    );
    final paidVariant = check.paidVariant;
    _newAchievements = _stats.recordAchievements(
      earned: check.earned,
      progress: {
        if (paidVariant != null)
          VideoPokerAchievementIds.everyVariant: {paidVariant},
      },
      now: _clock(),
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Stops the hand clock while the app is in the background.
  void pause() {
    final since = _handRunningSince;
    if (since == null) return;
    _handMs += _clock().difference(since).inMilliseconds;
    _handRunningSince = null;
  }

  void resume() {
    if (_game.isHolding && _handRunningSince == null) {
      _handRunningSince = _clock();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _credits.removeListener(_notify);
    _tones.dispose();
    super.dispose();
  }
}

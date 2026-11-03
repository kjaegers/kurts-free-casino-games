import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/audio/kfg_tone_player.dart';
import '../../../core/cards/playing_card.dart';
import '../../../core/haptics/kfg_haptics.dart';
import '../../../core/models/achievement.dart';
import '../../../core/models/texas_holdem_stats.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/services/stats_service.dart';
import 'logic/holdem_achievements.dart';
import 'logic/holdem_ai.dart';
import 'logic/holdem_evaluator.dart';
import 'logic/holdem_hand.dart';
import 'logic/holdem_table.dart';
import 'texas_holdem_save_service.dart';

/// Returns a full, shuffled 52-card deck.
typedef HoldemDeckShuffler = List<PlayingCard> Function();

/// Chooses a computer opponent's action from what it may see.
typedef HoldemOpponentDecider =
    HoldemDecision Function(
      HoldemAiView view,
      HoldemOpponent opponent,
      HoldemDifficulty difficulty,
      Random random,
    );

/// Quick raise sizes offered on the player's turn.
enum HoldemRaisePreset { halfPot, pot, allIn }

/// Flutter-facing controller for Texas Hold'em. Wraps the pure
/// [HoldemTable] / [HoldemHand] rules and owns everything around them: the
/// shared credit balance, the computer opponents' turns (paced by a timer),
/// the autosave, stats, achievements and sounds.
///
/// The deck is shuffled once per hand, before the deal. The opponents decide
/// with their own random numbers, from their own cards and the betting
/// only; nothing about the balance, the player's cards or past hands
/// changes the deal.
class TexasHoldemScreenController extends ChangeNotifier {
  TexasHoldemScreenController({
    StatsService? stats,
    CreditsService? credits,
    TexasHoldemSaveService? saveService,
    HoldemDeckShuffler? shuffleDeck,
    HoldemOpponentDecider? decideOpponent,
    Random? random,
    KfgTonePlayer? tonePlayer,
    DateTime Function()? clock,
    this.opponentDelay = defaultOpponentDelay,
  }) : _stats = stats ?? StatsService.instance,
       _credits = credits ?? CreditsService.instance,
       _saveService = saveService ?? TexasHoldemSaveService(),
       _shuffleDeck = shuffleDeck ?? _fairShuffle,
       _decideOpponent = decideOpponent ?? _aiDecision,
       _random = random ?? Random(),
       _tones =
           tonePlayer ??
           KfgTonePlayer(
             toneDuration: const Duration(milliseconds: 70),
             amplitude: 0.2,
           ),
       _clock = clock ?? DateTime.now;

  /// How long an opponent "thinks" before acting, so each move can be
  /// followed. Shorter once the player is out of the hand.
  static const Duration defaultOpponentDelay = Duration(milliseconds: 750);

  final StatsService _stats;
  final CreditsService _credits;
  final TexasHoldemSaveService _saveService;
  final HoldemDeckShuffler _shuffleDeck;
  final HoldemOpponentDecider _decideOpponent;
  final Random _random;
  final KfgTonePlayer _tones;
  final DateTime Function() _clock;

  /// See [defaultOpponentDelay].
  final Duration opponentDelay;

  static final Random _shuffleRandom = Random();

  static List<PlayingCard> _fairShuffle() =>
      HoldemTable.shuffledDeck((cards) => cards..shuffle(_shuffleRandom));

  static HoldemDecision _aiDecision(
    HoldemAiView view,
    HoldemOpponent opponent,
    HoldemDifficulty difficulty,
    Random random,
  ) => decideHoldemAction(
    view,
    style: opponent.style,
    difficulty: difficulty,
    random: random,
  );

  bool _initialized = false;
  bool _disposed = false;
  bool _paused = false;
  Timer? _opponentTimer;

  late HoldemTable _table;

  /// Bumped on every deal; cards dealt in a hand animate in once.
  int _handToken = 0;

  /// The total the player's next bet or raise brings their bet to.
  int _raiseTo = 0;

  List<AchievementDefinition> _newAchievements = const [];

  int _handMs = 0;
  DateTime? _handRunningSince;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isInitialized => _initialized;
  HoldemTable get table => _table;
  HoldemHand? get hand => _table.hand;
  int get handToken => _handToken;
  int get balance => _credits.balance;
  TexasHoldemStats get stats => _stats.texasHoldemStats;

  bool get isInPlay => _initialized && _table.isInPlay;
  bool get isPlayerTurn => _initialized && _table.isPlayerTurn;

  /// The chips the player brings to the next hand.
  int get nextStake => min(_credits.balance, _table.playerCap);

  /// Too few credits for the big blind: offer the free refill.
  bool get isBroke => _credits.balance < holdemBigBlind;

  bool get canDeal => _initialized && !_table.isInPlay && !isBroke;
  bool get canChangeTable => _initialized && !_table.isInPlay;
  bool get canFold => isPlayerTurn && hand!.canFold;
  bool get canCheckOrCall => isPlayerTurn;
  bool get canRaise => isPlayerTurn && hand!.canRaise;

  /// What a call costs the player now (0 when they can check).
  int get toCall => isPlayerTurn ? hand!.toCall : 0;

  /// The raise total currently chosen, kept within the legal range.
  int get raiseTo =>
      canRaise ? _raiseTo.clamp(hand!.minRaiseTo, hand!.maxRaiseTo) : 0;

  bool get raiseIsAllIn => canRaise && raiseTo == hand!.maxRaiseTo;

  /// Nobody has bet this round: the player's raise is an opening bet.
  bool get raiseIsOpening => isPlayerTurn && hand!.currentBet == 0;

  bool get canLowerRaise => canRaise && raiseTo > hand!.minRaiseTo;
  bool get canIncreaseRaise => canRaise && raiseTo < hand!.maxRaiseTo;

  /// The name shown for [seat]: "You" for the player.
  String seatName(int seat) =>
      seat == 0 ? 'You' : _table.opponents[seat - 1].name;

  /// Returns the achievements first unlocked by the hand just completed
  /// (already saved) and clears them, so they're announced only once.
  List<AchievementDefinition> takeNewAchievements() {
    final result = _newAchievements;
    _newAchievements = const [];
    return result;
  }

  /// The status line under the table.
  String get message {
    final h = hand;
    if (!_initialized) return '';
    if (h == null) {
      if (isBroke) return 'Out of credits: tap FREE REFILL to keep playing';
      return 'Tap DEAL to play a hand. Blinds '
          '$holdemSmallBlind/$holdemBigBlind.';
    }
    if (h.isComplete) {
      final result = _resultMessage(h);
      return isBroke ? '$result · Tap FREE REFILL to play on' : result;
    }
    final last = _lastActionText(h);
    if (h.toAct == 0) {
      final prompt = h.canCheck
          ? 'Your turn: check or bet'
          : 'Your turn: ${formatCredits(h.toCall)} to call';
      return last == null ? prompt : '$last · $prompt';
    }
    final thinking = '${seatName(h.toAct)} to act';
    return last == null ? thinking : '$last · $thinking';
  }

  String? _lastActionText(HoldemHand h) {
    final seat = h.lastActor;
    if (seat < 0) return null;
    final s = h.seats[seat];
    final move = s.lastMove;
    if (move == null) return null;
    final who = seatName(seat);
    final amount = formatCredits(s.streetBet);
    final verb = switch (move) {
      HoldemMove.smallBlind => seat == 0 ? 'post' : 'posts',
      HoldemMove.bigBlind => seat == 0 ? 'post' : 'posts',
      HoldemMove.fold => seat == 0 ? 'fold' : 'folds',
      HoldemMove.check => seat == 0 ? 'check' : 'checks',
      HoldemMove.call => seat == 0 ? 'call' : 'calls',
      HoldemMove.bet => seat == 0 ? 'bet' : 'bets',
      HoldemMove.raise => seat == 0 ? 'raise to' : 'raises to',
      HoldemMove.allIn => seat == 0 ? 'go all-in for' : 'goes all-in for',
    };
    return switch (move) {
      HoldemMove.fold || HoldemMove.check => '$who $verb',
      HoldemMove.smallBlind => '$who $verb the small blind',
      HoldemMove.bigBlind => '$who $verb the big blind',
      _ => '$who $verb $amount',
    };
  }

  String _resultMessage(HoldemHand h) {
    final main = h.pots.first;
    final names = [for (final w in main.winners) seatName(w)];
    final who = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and '
              '${names.last}';
    final wins = main.winners.length == 1
        ? (main.winners.single == 0 ? 'win' : 'wins')
        : 'split';
    final String text;
    if (!h.showdown) {
      final rest = main.winners.single == 0 ? 'everyone folded' : 'no call';
      text = '$who $wins ${formatCredits(h.pot - _returned(h))}: $rest';
    } else {
      text =
          '$who $wins ${formatCredits(main.amount)} with '
          '${holdemHandName(h.scoreOf(main.winners.first))}';
    }
    final collected = h.winnings[0];
    if (h.pots.length > 1 && collected > 0) {
      return '$text · You collect ${formatCredits(collected)}';
    }
    return text;
  }

  /// Chips handed back unmatched at the end of [h].
  int _returned(HoldemHand h) =>
      h.pot - h.pots.fold(0, (sum, p) => sum + p.amount);

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Resumes a saved table (and a hand in play exactly as it was, never
  /// redealing), otherwise seats a new table from the last-used settings.
  Future<void> initialize() async {
    await _stats.ensureLoaded();
    await _credits.ensureLoaded();
    final saved = await _saveService.load();
    if (_disposed) return;
    _credits.addListener(_notify);

    if (saved != null) {
      _table = saved;
      if (saved.isInPlay) {
        _handToken++;
        _handRunningSince = _clock();
        _resetRaise();
      }
    } else {
      final prefs = _stats.texasHoldemStats;
      _table = HoldemTable.create(
        opponentCount: prefs.preferredOpponents,
        difficulty:
            HoldemDifficulty.byName(prefs.preferredDifficulty) ??
            HoldemDifficulty.normal,
        random: _random,
      );
    }
    _initialized = true;
    _scheduleOpponent();
    _notify();
  }

  // ── Between hands ──────────────────────────────────────────────────────────

  /// Seats a new table of [opponents] at [difficulty]. Only between hands;
  /// the old opponents leave with their chips (the player's are in credits).
  bool newTable({int? opponents, HoldemDifficulty? difficulty}) {
    if (!canChangeTable) return false;
    final count = opponents ?? _table.opponents.length;
    final level = difficulty ?? _table.difficulty;
    _table = HoldemTable.create(
      opponentCount: count,
      difficulty: level,
      random: _random,
    );
    _stats.setTexasHoldemPreferences(opponents: count, difficulty: level.name);
    unawaited(_saveService.clear());
    unawaited(_tones.playFrequency(523));
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  /// Gives a broke player a fresh [CreditsService.startingBalance], free.
  bool refillCredits() {
    if (!_initialized || !isBroke || _table.isInPlay) return false;
    _credits.reset();
    unawaited(_tones.playFrequency(660));
    _notify();
    return true;
  }

  /// Takes the player's stake from credits and deals the next hand.
  bool deal() {
    if (!canDeal) return false;
    final stake = nextStake;
    if (!_credits.debit(stake)) return false;
    _table = _table.deal(
      playerStack: stake,
      deck: _shuffleDeck(),
      random: _random,
    );
    _handToken++;
    _handMs = 0;
    _handRunningSince = _clock();
    _resetRaise();
    unawaited(_tones.playFrequency(392));
    unawaited(KfgHaptics.light());
    _afterAction();
    return true;
  }

  // ── The player's turn ──────────────────────────────────────────────────────

  bool fold() {
    if (!canFold) return false;
    _playerActs(const HoldemDecision.fold(), 330);
    return true;
  }

  bool checkOrCall() {
    if (!canCheckOrCall) return false;
    _playerActs(const HoldemDecision.checkOrCall(), hand!.canCheck ? 440 : 494);
    return true;
  }

  /// Bets or raises to [raiseTo].
  bool raise() {
    if (!canRaise) return false;
    _playerActs(HoldemDecision.raiseTo(raiseTo), raiseIsAllIn ? 659 : 587);
    return true;
  }

  /// Moves the chosen raise one big blind down ([steps] < 0) or up.
  bool stepRaise(int steps) {
    if (!canRaise || steps == 0) return false;
    final h = hand!;
    var target = raiseTo + steps * holdemBigBlind;
    // Stepping down from all-in lands on a round amount.
    if (steps < 0 && raiseTo == h.maxRaiseTo) {
      target = (raiseTo - 1) ~/ holdemBigBlind * holdemBigBlind;
    }
    return _setRaise(target);
  }

  bool presetRaise(HoldemRaisePreset preset) {
    if (!canRaise) return false;
    final h = hand!;
    final afterCall = h.pot + h.toCall;
    final target = switch (preset) {
      HoldemRaisePreset.halfPot => h.currentBet + afterCall ~/ 2,
      HoldemRaisePreset.pot => h.currentBet + afterCall,
      HoldemRaisePreset.allIn => h.maxRaiseTo,
    };
    if (preset == HoldemRaisePreset.allIn) return _setRaise(target);
    const unit = holdemSmallBlind;
    return _setRaise((target + unit - 1) ~/ unit * unit);
  }

  bool _setRaise(int target) {
    final h = hand!;
    final clamped = target.clamp(h.minRaiseTo, h.maxRaiseTo);
    if (clamped == raiseTo) return false;
    _raiseTo = clamped;
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  void _resetRaise() {
    final h = hand;
    _raiseTo = h == null || h.toAct < 0 ? 0 : h.minRaiseTo;
  }

  void _playerActs(HoldemDecision decision, double hz) {
    _table = _table.act(decision);
    unawaited(_tones.playFrequency(hz));
    unawaited(KfgHaptics.selection());
    _afterAction();
  }

  // ── The opponents' turns ───────────────────────────────────────────────────

  void _scheduleOpponent() {
    _opponentTimer?.cancel();
    _opponentTimer = null;
    if (_disposed || _paused || _table.opponentToAct == null) return;
    final playerOut = hand!.seats[0].folded || hand!.seats[0].isAllIn;
    final delay = playerOut ? opponentDelay * 0.5 : opponentDelay;
    _opponentTimer = Timer(delay, _opponentActs);
  }

  void _opponentActs() {
    _opponentTimer = null;
    final opponent = _table.opponentToAct;
    if (_disposed || opponent == null) return;
    final decision = _decideOpponent(
      HoldemAiView.of(hand!),
      opponent,
      _table.difficulty,
      _random,
    );
    _table = _table.act(decision);
    unawaited(_tones.playFrequency(349));
    _afterAction();
  }

  /// Advances the opponents for tests, as if each one's delay had passed.
  @visibleForTesting
  void runOpponentsForTest({int maxActions = 200}) {
    for (var i = 0; i < maxActions && _table.opponentToAct != null; i++) {
      _opponentActs();
    }
  }

  // ── After every action ─────────────────────────────────────────────────────

  /// Saves the table; pays and records a hand that just ended; lines up the
  /// next opponent's turn.
  void _afterAction() {
    final h = hand!;
    if (h.isComplete) {
      _credits.credit(_table.playerFinalStack);
      _record(h);
      if (h.winnings[0] > h.seats[0].committed) {
        unawaited(_tones.playFrequency(784));
        unawaited(KfgHaptics.medium());
      }
    } else if (h.toAct == 0) {
      _resetRaise();
    }
    unawaited(_saveService.save(_table));
    _scheduleOpponent();
    _notify();
  }

  void _record(HoldemHand h) {
    final since = _handRunningSince;
    if (since != null) _handMs += _clock().difference(since).inMilliseconds;
    _handRunningSince = null;
    final player = h.seats[0];
    final wonPot = holdemPlayerWonPot(h);
    final showdown = h.showdown && player.isLive;
    final knockouts = {
      for (final pot in h.pots)
        if (pot.winners.contains(0))
          for (final seat in pot.eligible)
            if (seat != 0 && h.seats[seat].stack == 0) seat,
    }.length;
    _stats.recordTexasHoldemHand(
      TexasHoldemHandRecord(
        wagered: player.committed,
        collected: h.winnings[0],
        wonPot: wonPot,
        folded: player.folded,
        showdown: showdown,
        knockouts: knockouts,
        showdownCategory: showdown
            ? holdemCategoryOf(h.scoreOf(0)).index
            : null,
      ),
      durationSeconds: _handMs ~/ 1000,
    );
    final difficulty = _table.difficulty.name;
    final beaten = {
      ..._stats.achievementState(HoldemAchievementIds.everyDifficulty).progress,
      if (wonPot) difficulty,
    };
    _newAchievements = _stats.recordAchievements(
      earned: {
        ...checkHoldemAchievements(h),
        if (HoldemDifficulty.values.every((d) => beaten.contains(d.name)))
          HoldemAchievementIds.everyDifficulty,
      },
      progress: {
        if (wonPot) HoldemAchievementIds.everyDifficulty: {difficulty},
      },
      now: _clock(),
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Stops the opponents and the hand clock while the app is in the
  /// background.
  void pause() {
    _paused = true;
    _opponentTimer?.cancel();
    _opponentTimer = null;
    final since = _handRunningSince;
    if (since == null) return;
    _handMs += _clock().difference(since).inMilliseconds;
    _handRunningSince = null;
  }

  void resume() {
    _paused = false;
    if (_initialized && _table.isInPlay && _handRunningSince == null) {
      _handRunningSince = _clock();
    }
    if (_initialized) _scheduleOpponent();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _opponentTimer?.cancel();
    _credits.removeListener(_notify);
    _tones.dispose();
    super.dispose();
  }
}

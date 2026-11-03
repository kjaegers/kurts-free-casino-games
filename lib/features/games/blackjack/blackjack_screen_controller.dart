import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/audio/kfg_tone_player.dart';
import '../../../core/cards/playing_card.dart';
import '../../../core/haptics/kfg_haptics.dart';
import '../../../core/models/achievement.dart';
import '../../../core/models/blackjack_stats.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/services/stats_service.dart';
import 'blackjack_save_service.dart';
import 'logic/blackjack_achievements.dart';
import 'logic/blackjack_game.dart';
import 'logic/blackjack_hand.dart';

/// Returns a full, shuffled six-deck shoe.
typedef BlackjackShoeShuffler = List<PlayingCard> Function();

/// Flutter-facing controller for Blackjack. Wraps the pure [BlackjackGame]
/// rules and owns everything around them: the shared credit balance, the
/// autosave, stats, achievements, sounds and the card animation cue.
///
/// Every card comes from the shoe in the order it was shuffled; the dealer
/// plays by the fixed house rule (stand on all 17s). Nothing about the
/// balance, the bet or past rounds influences the cards.
class BlackjackScreenController extends ChangeNotifier {
  BlackjackScreenController({
    StatsService? stats,
    CreditsService? credits,
    BlackjackSaveService? saveService,
    BlackjackShoeShuffler? shuffleShoe,
    KfgTonePlayer? tonePlayer,
    DateTime Function()? clock,
  }) : _stats = stats ?? StatsService.instance,
       _credits = credits ?? CreditsService.instance,
       _saveService = saveService ?? BlackjackSaveService(),
       _shuffleShoe = shuffleShoe ?? _fairShuffle,
       _tones =
           tonePlayer ??
           KfgTonePlayer(
             toneDuration: const Duration(milliseconds: 70),
             amplitude: 0.2,
           ),
       _clock = clock ?? DateTime.now;

  final StatsService _stats;
  final CreditsService _credits;
  final BlackjackSaveService _saveService;
  final BlackjackShoeShuffler _shuffleShoe;
  final KfgTonePlayer _tones;
  final DateTime Function() _clock;

  static final Random _random = Random();

  static List<PlayingCard> _fairShuffle() =>
      BlackjackGame.shuffledShoe((cards) => cards..shuffle(_random));

  /// The chips the bet is built from.
  static const List<int> chips = [10, 50, 100, 500];

  bool _initialized = false;
  bool _disposed = false;

  BlackjackGame _game = BlackjackGame.newSession();

  /// Bumped on every deal; cards dealt in a round animate in once.
  int _roundToken = 0;

  List<AchievementDefinition> _newAchievements = const [];

  int _roundMs = 0;
  DateTime? _roundRunningSince;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isInitialized => _initialized;
  BlackjackGame get game => _game;
  int get bet => _game.bet;
  int get roundToken => _roundToken;
  int get balance => _credits.balance;
  BlackjackStats get stats => _stats.blackjackStats;

  bool get canChangeBet => _initialized && _game.canChangeBet;
  bool get canDeal => _initialized && _game.canDeal && _credits.canAfford(bet);
  bool get canDecideInsurance => _initialized && _game.canDecideInsurance;
  bool get canTakeInsurance =>
      canDecideInsurance && _credits.canAfford(_game.insuranceCost);
  bool get canHit => _initialized && _game.canHit;
  bool get canStand => _initialized && _game.canStand;
  bool get canDouble =>
      _initialized && _game.canDouble && _credits.canAfford(_game.doubleCost);
  bool get canSplit =>
      _initialized && _game.canSplit && _credits.canAfford(_game.splitCost);
  bool get canSurrender => _initialized && _game.canSurrender;

  /// Too few credits for even the minimum bet: offer the free refill.
  bool get isBroke => _credits.balance < blackjackMinBet;

  /// Enough credits for some bet, just not the one chosen.
  bool get betTooHigh =>
      _initialized && !_game.isInPlay && !isBroke && !_credits.canAfford(bet);

  /// The largest bet the balance covers, within the table limits.
  int get _maxAffordableBet {
    final affordable = _credits.balance - _credits.balance % blackjackBetStep;
    return max(blackjackMinBet, min(blackjackMaxBet, affordable));
  }

  /// A chip would raise the bet: it is below the table limit and what the
  /// balance covers.
  bool get canRaiseBet => canChangeBet && bet < _maxAffordableBet;

  /// Returns the achievements first unlocked by the round just completed
  /// (already saved) and clears them, so they're announced only once.
  List<AchievementDefinition> takeNewAchievements() {
    final result = _newAchievements;
    _newAchievements = const [];
    return result;
  }

  /// The status line between the dealer and the player.
  String get message {
    final g = _game;
    switch (g.phase) {
      case BlackjackPhase.betting:
        return _bettingMessage ?? 'Place your bet, then DEAL';
      case BlackjackPhase.insurance:
        return 'Dealer shows an Ace. Insurance for '
            '${formatCredits(g.insuranceCost)}?';
      case BlackjackPhase.playerTurn:
        final hand = g.activeHand!;
        final total = '${hand.isSoft ? 'soft ' : ''}${hand.total}';
        final which = g.hands.length > 1 ? 'Hand ${g.activeIndex + 1}: ' : '';
        final shuffled =
            g.freshShoe && g.hands.length == 1 && hand.cards.length == 2
            ? 'New shoe. '
            : '';
        return '$shuffled${which}You have $total. Hit or stand?';
      case BlackjackPhase.complete:
        final note = _bettingMessage;
        return note == null ? _resultMessage : '$_resultMessage · $note';
    }
  }

  String? get _bettingMessage {
    if (isBroke) return 'Out of credits: tap FREE REFILL to keep playing';
    if (betTooHigh) return 'Not enough credits for this bet: lower it';
    return null;
  }

  String get _resultMessage {
    final g = _game;
    final insurance = g.insurance > 0 && g.dealerHasBlackjack
        ? ' Insurance pays ${formatCredits(g.insurancePayout)}.'
        : '';
    if (g.hands.length > 1) {
      final pays = g.payout;
      return pays == 0
          ? 'No win this round'
          : 'Round pays ${formatCredits(pays)}';
    }
    final hand = g.hands.single;
    final pays = formatCredits(g.payoutOf(hand));
    final result = switch (g.outcomeOf(hand)) {
      BlackjackOutcome.blackjack => 'Blackjack! Pays $pays.',
      BlackjackOutcome.win =>
        g.dealerBust ? 'Dealer busts! Pays $pays.' : 'You win! Pays $pays.',
      BlackjackOutcome.push => 'Push: your $pays back.',
      BlackjackOutcome.lose =>
        g.dealerHasBlackjack
            ? 'Dealer has blackjack.'
            : 'Dealer wins with ${g.dealerTotal}.',
      BlackjackOutcome.bust => 'Bust with ${hand.total}.',
      BlackjackOutcome.surrender => 'Surrendered: $pays back.',
    };
    return '$result$insurance';
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  /// Resumes a round in play exactly as it was (never redealing),
  /// otherwise opens the table with the last-used bet.
  Future<void> initialize() async {
    await _stats.ensureLoaded();
    await _credits.ensureLoaded();
    final saved = await _saveService.load();
    if (_disposed) return;
    _credits.addListener(_notify);

    if (saved != null) {
      _game = saved;
      _roundToken++;
      _roundRunningSince = _clock();
    } else {
      _game = BlackjackGame.newSession(bet: _stats.blackjackStats.preferredBet);
    }
    _initialized = true;
    _notify();
  }

  // ── Betting ────────────────────────────────────────────────────────────────

  /// Adds [chip] to the bet, up to the table limit or what the balance
  /// covers.
  bool addChip(int chip) {
    if (!canRaiseBet) return false;
    return _setBet(min(bet + chip, _maxAffordableBet));
  }

  /// Sets the bet back to the table minimum.
  bool clearBet() {
    if (!canChangeBet || bet == blackjackMinBet) return false;
    return _setBet(blackjackMinBet);
  }

  bool _setBet(int amount) {
    _game = _game.withBet(amount);
    _stats.setBlackjackPreferences(bet: amount);
    unawaited(_tones.playFrequency(440 + (amount ~/ 100).clamp(0, 10) * 20));
    unawaited(KfgHaptics.selection());
    _notify();
    return true;
  }

  /// Gives a broke player a fresh [CreditsService.startingBalance], free.
  bool refillCredits() {
    if (!_initialized || !isBroke || _game.isInPlay) return false;
    _credits.reset();
    unawaited(_tones.playFrequency(660));
    _notify();
    return true;
  }

  // ── Play ───────────────────────────────────────────────────────────────────

  /// Takes the bet and deals a round, shuffling a fresh shoe first when the
  /// cut card has come out.
  bool deal() {
    if (!canDeal) return false;
    if (!_credits.debit(bet)) return false;
    _game = _game.deal(
      shuffledShoe: _game.needsShuffle ? _shuffleShoe() : null,
    );
    _roundToken++;
    _roundMs = 0;
    _roundRunningSince = _clock();
    unawaited(_tones.playFrequency(392));
    unawaited(KfgHaptics.light());
    _afterAction();
    return true;
  }

  bool takeInsurance() {
    if (!canTakeInsurance) return false;
    if (!_credits.debit(_game.insuranceCost)) return false;
    _game = _game.decideInsurance(take: true);
    _actionFeedback(523);
    return true;
  }

  bool declineInsurance() {
    if (!canDecideInsurance) return false;
    _game = _game.decideInsurance(take: false);
    _actionFeedback(440);
    return true;
  }

  bool hit() {
    if (!canHit) return false;
    _game = _game.hit();
    _actionFeedback(494);
    return true;
  }

  bool stand() {
    if (!canStand) return false;
    _game = _game.stand();
    _actionFeedback(392);
    return true;
  }

  bool doubleDown() {
    if (!canDouble) return false;
    if (!_credits.debit(_game.doubleCost)) return false;
    _game = _game.doubleDown();
    _actionFeedback(587);
    return true;
  }

  bool split() {
    if (!canSplit) return false;
    if (!_credits.debit(_game.splitCost)) return false;
    _game = _game.split();
    _actionFeedback(554);
    return true;
  }

  bool surrender() {
    if (!canSurrender) return false;
    _game = _game.surrender();
    _actionFeedback(330);
    return true;
  }

  void _actionFeedback(double hz) {
    unawaited(_tones.playFrequency(hz));
    unawaited(KfgHaptics.selection());
    _afterAction();
  }

  /// Saves a round still in play; pays and records one that just ended.
  void _afterAction() {
    if (_game.isComplete) {
      final payout = _game.payout;
      _credits.credit(payout);
      unawaited(_saveService.clear());
      _record();
      if (payout > _game.totalWagered) {
        unawaited(_tones.playFrequency(784));
        unawaited(KfgHaptics.medium());
      } else if (payout == 0) {
        unawaited(_tones.playFrequency(262));
      }
    } else {
      unawaited(_saveService.save(_game));
    }
    _notify();
  }

  void _record() {
    final since = _roundRunningSince;
    if (since != null) _roundMs += _clock().difference(since).inMilliseconds;
    _roundRunningSince = null;
    final g = _game;
    final outcomes = [for (final h in g.hands) g.outcomeOf(h)];
    _stats.recordBlackjackRound(
      BlackjackRoundRecord(
        wagered: g.totalWagered,
        payout: g.payout,
        hands: g.hands.length,
        handsWon: outcomes
            .where(
              (o) =>
                  o == BlackjackOutcome.win || o == BlackjackOutcome.blackjack,
            )
            .length,
        blackjack: outcomes.contains(BlackjackOutcome.blackjack),
        doubles: g.hands.where((h) => h.doubled).length,
        splits: g.hands.length - 1,
        surrendered: outcomes.contains(BlackjackOutcome.surrender),
      ),
      durationSeconds: _roundMs ~/ 1000,
    );
    _newAchievements = _stats.recordAchievements(
      earned: checkBlackjackAchievements(g),
      now: _clock(),
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Stops the round clock while the app is in the background.
  void pause() {
    final since = _roundRunningSince;
    if (since == null) return;
    _roundMs += _clock().difference(since).inMilliseconds;
    _roundRunningSince = null;
  }

  void resume() {
    if (_game.isInPlay && _roundRunningSince == null) {
      _roundRunningSince = _clock();
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

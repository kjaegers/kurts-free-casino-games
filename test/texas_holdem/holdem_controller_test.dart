import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_ai.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_hand.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_table.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/texas_holdem_save_service.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/texas_holdem_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'holdem_test_support.dart';

/// Opponents who always check or call.
HoldemDecision _calls(
  HoldemAiView view,
  HoldemOpponent opponent,
  HoldemDifficulty difficulty,
  Random random,
) => const HoldemDecision.checkOrCall();

/// Opponents who fold to any bet and otherwise check.
HoldemDecision _folds(
  HoldemAiView view,
  HoldemOpponent opponent,
  HoldemDifficulty difficulty,
  Random random,
) => view.toCall > 0
    ? const HoldemDecision.fold()
    : const HoldemDecision.checkOrCall();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late StatsService stats;
  late int deckSeed;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    stats.setTexasHoldemPreferences(opponents: 3, difficulty: 'normal');
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    await credits.ensureLoaded();
    deckSeed = 0;
  });

  Future<TexasHoldemScreenController> create({
    HoldemOpponentDecider decide = _calls,
    int seed = 1,
    bool disposeAtEnd = true,
  }) async {
    final controller = TexasHoldemScreenController(
      stats: stats,
      credits: credits,
      saveService: TexasHoldemSaveService(storage: storage),
      shuffleDeck: () =>
          const CardDeckFactory().createShuffledDeck(seed: deckSeed++),
      decideOpponent: decide,
      random: Random(seed),
      tonePlayer: SilentTonePlayer(),
      // The tests move the opponents themselves.
      opponentDelay: const Duration(hours: 1),
    );
    await controller.initialize();
    if (disposeAtEnd) addTearDown(controller.dispose);
    return controller;
  }

  /// Plays the hand out, the player checking or calling every time.
  void playOut(TexasHoldemScreenController c) {
    for (var i = 0; i < 100 && c.isInPlay; i++) {
      c.runOpponentsForTest();
      if (c.isPlayerTurn) c.checkOrCall();
    }
  }

  int tableChips(TexasHoldemScreenController c) =>
      credits.balance + c.table.opponents.fold(0, (sum, o) => sum + o.stack);

  test('seats the remembered table', () async {
    final c = await create();
    expect(c.table.opponents, hasLength(3));
    expect(c.table.difficulty, HoldemDifficulty.normal);
    expect(c.hand, isNull);
    expect(c.canDeal, isTrue);
    expect(c.nextStake, 1000);
    expect(
      storage.values.containsKey(TexasHoldemSaveService.storageKey),
      isFalse,
    );
  });

  test('a hand takes the stake, then pays back what is left', () async {
    final c = await create();
    final before = tableChips(c);
    expect(c.deal(), isTrue);
    expect(credits.balance, 0);
    expect(c.isInPlay, isTrue);
    expect(c.table.playerStake, 1000);
    expect(
      storage.values.containsKey(TexasHoldemSaveService.storageKey),
      isTrue,
    );
    playOut(c);
    final h = c.hand!;
    expect(h.isComplete, isTrue);
    expect(h.showdown, isTrue);
    expect(credits.balance, h.seats[0].stack);
    expect(tableChips(c), before);
    expect(stats.texasHoldemStats.hands, 1);
    expect(stats.texasHoldemStats.showdowns, 1);
    expect(stats.texasHoldemStats.wagered, h.seats[0].committed);
    expect(stats.texasHoldemStats.collected, h.winnings[0]);
    expect(stats.stats.playsByGame['texas_holdem'], 1);
    // Nothing more to do until the next deal: stats stay recorded once.
    c.runOpponentsForTest();
    expect(stats.texasHoldemStats.hands, 1);
  });

  test('the stake is capped at the deepest opponent stack', () async {
    credits.credit(4000);
    final c = await create();
    expect(c.nextStake, 1000);
    c.deal();
    expect(credits.balance, 4000);
  });

  test('a bet everyone folds to wins the blinds', () async {
    final c = await create(decide: _folds);
    c.deal();
    for (var i = 0; i < 20 && c.isInPlay; i++) {
      c.runOpponentsForTest();
      if (c.isPlayerTurn) {
        expect(c.canRaise, isTrue);
        expect(c.raise(), isTrue);
      }
    }
    final h = c.hand!;
    expect(h.isComplete, isTrue);
    expect(h.showdown, isFalse);
    expect(h.pots.single.winners, [0]);
    expect(credits.balance, greaterThan(1000));
    expect(stats.texasHoldemStats.handsWon, 1);
    expect(c.message, contains('You win'));
  });

  test('raise sizing stays legal', () async {
    final c = await create();
    c.deal();
    c.runOpponentsForTest();
    expect(c.isPlayerTurn, isTrue);
    final h = c.hand!;
    expect(c.raiseTo, h.minRaiseTo);
    expect(c.canLowerRaise, isFalse);
    expect(c.stepRaise(1), isTrue);
    expect(c.raiseTo, h.minRaiseTo + holdemBigBlind);
    expect(c.presetRaise(HoldemRaisePreset.pot), isTrue);
    expect(c.raiseTo, h.currentBet + h.pot + h.toCall);
    expect(c.presetRaise(HoldemRaisePreset.allIn), isTrue);
    expect(c.raiseIsAllIn, isTrue);
    expect(c.canIncreaseRaise, isFalse);
    expect(c.stepRaise(-1), isTrue);
    expect(c.raiseTo % holdemBigBlind, 0);
    expect(c.raiseTo, lessThan(h.maxRaiseTo));
  });

  test('a hand in play resumes exactly, without a new deal', () async {
    final first = await create(disposeAtEnd: false);
    first.deal();
    first.runOpponentsForTest();
    first.checkOrCall();
    first.runOpponentsForTest();
    final saved = jsonEncode(first.table.toJson());
    final balance = credits.balance;
    first.dispose();

    final second = await create();
    expect(second.isInPlay, isTrue);
    expect(jsonEncode(second.table.toJson()), saved);
    expect(credits.balance, balance);
    expect(deckSeed, 1);
  });

  test('between hands the opponents keep their stacks', () async {
    final first = await create(disposeAtEnd: false);
    first.deal();
    playOut(first);
    final stacks = [for (final o in first.table.opponents) o.stack];
    first.dispose();

    final second = await create();
    expect(second.hand, isNull);
    expect([for (final o in second.table.opponents) o.stack], stacks);
    expect(second.table.handsDealt, 1);
  });

  test('a corrupt save seats a fresh table', () async {
    storage.values[TexasHoldemSaveService.storageKey] = '{"version":1,"x":';
    final c = await create();
    expect(c.hand, isNull);
    expect(c.table.opponents, hasLength(3));
  });

  test('a busted opponent is replaced before the next hand', () async {
    final c = await create(disposeAtEnd: false);
    c.deal();
    playOut(c);
    final json = c.table.toJson();
    (json['opponents'] as List)[0]['stack'] = 0;
    storage.values[TexasHoldemSaveService.storageKey] = jsonEncode(json);
    c.dispose();

    final next = await create();
    expect(next.table.opponents[0].stack, 0);
    next.deal();
    expect(
      next.hand!.seats[1].stack + next.hand!.seats[1].committed,
      holdemOpponentBuyIn,
    );
  });

  test('a new table only between hands, remembered for next time', () async {
    final c = await create();
    expect(c.newTable(opponents: 5, difficulty: HoldemDifficulty.hard), isTrue);
    expect(c.table.opponents, hasLength(5));
    expect(stats.texasHoldemStats.preferredOpponents, 5);
    expect(stats.texasHoldemStats.preferredDifficulty, 'hard');
    c.deal();
    expect(c.newTable(opponents: 1), isFalse);
  });

  test('a free refill when the balance cannot cover the big blind', () async {
    credits.debit(995);
    final c = await create();
    expect(c.isBroke, isTrue);
    expect(c.canDeal, isFalse);
    expect(c.message, contains('FREE REFILL'));
    expect(c.refillCredits(), isTrue);
    expect(credits.balance, CreditsService.startingBalance);
    expect(c.canDeal, isTrue);
  });

  test('the player cannot act out of turn', () async {
    final c = await create();
    expect(c.checkOrCall(), isFalse);
    c.deal();
    if (!c.isPlayerTurn) {
      expect(c.checkOrCall(), isFalse);
      expect(c.fold(), isFalse);
      expect(c.raise(), isFalse);
    }
  });

  test('pausing stops the opponents; resuming lines them up again', () async {
    final c = TexasHoldemScreenController(
      stats: stats,
      credits: credits,
      saveService: TexasHoldemSaveService(storage: storage),
      decideOpponent: _calls,
      random: Random(3),
      tonePlayer: SilentTonePlayer(),
      opponentDelay: const Duration(milliseconds: 1),
    );
    addTearDown(c.dispose);
    await c.initialize();
    c.deal();
    c.pause();
    final before = jsonEncode(c.table.toJson());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(jsonEncode(c.table.toJson()), before);
    c.resume();
    for (var i = 0; i < 200 && c.isInPlay && !c.isPlayerTurn; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(c.isPlayerTurn || !c.isInPlay, isTrue);
  });
}

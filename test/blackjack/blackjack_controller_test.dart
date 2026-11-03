import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/blackjack_save_service.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/blackjack_screen_controller.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_achievements.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'blackjack_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsService stats;
  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedShoe shoe;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    shoe = ScriptedShoe();
  });

  Future<BlackjackScreenController> open({int bet = 10}) async {
    stats.setBlackjackPreferences(bet: bet);
    final controller = BlackjackScreenController(
      stats: stats,
      credits: credits,
      saveService: BlackjackSaveService(storage: storage),
      shuffleShoe: shoe.call,
      tonePlayer: SilentTonePlayer(),
    );
    await controller.initialize();
    return controller;
  }

  test(
    'opens with the remembered bet and shuffles on the first deal',
    () async {
      final c = await open(bet: 50);
      expect(c.bet, 50);
      expect(c.game.phase, BlackjackPhase.betting);
      expect(shoe.shuffles, 0);
      expect(c.deal(), isTrue);
      expect(shoe.shuffles, 1);
      c.dispose();
    },
  );

  test('chips raise the bet within the limits and the balance', () async {
    final c = await open();
    expect(c.addChip(500), isTrue);
    expect(c.bet, 510);
    expect(c.addChip(500), isTrue);
    expect(c.bet, blackjackMaxBet);
    expect(c.addChip(10), isFalse);
    expect(stats.blackjackStats.preferredBet, blackjackMaxBet);
    expect(c.clearBet(), isTrue);
    expect(c.bet, blackjackMinBet);
    credits.debit(credits.balance - 75);
    expect(c.addChip(100), isTrue);
    expect(c.bet, 70, reason: 'no more than the balance covers');
    c.dispose();
  });

  test('deal takes the bet and a win pays it back doubled', () async {
    shoe.queue('10S 6H 9D 10C KH');
    final c = await open(bet: 20);
    expect(c.deal(), isTrue);
    expect(c.balance, 980);
    expect(c.deal(), isFalse, reason: 'one round at a time');
    expect(c.canChangeBet, isFalse);
    expect(c.stand(), isTrue);
    expect(c.game.isComplete, isTrue);
    expect(c.balance, 1020);
    expect(c.message, 'Dealer busts! Pays 40.');
    c.dispose();
  });

  test('double, split and insurance take their extra stakes', () async {
    shoe.queue('8S AH 8D 6C 3H 10S 9C 10D');
    final c = await open(bet: 100);
    c.deal();
    expect(c.canDecideInsurance, isTrue);
    expect(c.takeInsurance(), isTrue);
    expect(c.balance, 850);
    expect(c.split(), isTrue);
    expect(c.balance, 750);
    // Hand 1 is 8 + 3: double it.
    expect(c.doubleDown(), isTrue);
    expect(c.balance, 650);
    expect(c.game.activeIndex, 1);
    expect(c.stand(), isTrue);
    final g = c.game;
    expect(g.isComplete, isTrue);
    expect(g.totalWagered, 350);
    expect(c.balance, 650 + g.payout);
    c.dispose();
  });

  test('extra stakes need the credits to cover them', () async {
    shoe.queue('6S AH 5D 6C');
    final c = await open(bet: 100);
    credits.debit(credits.balance - 120);
    c.deal();
    expect(c.balance, 20);
    expect(c.canTakeInsurance, isFalse);
    expect(c.takeInsurance(), isFalse);
    expect(c.declineInsurance(), isTrue);
    expect(c.canDouble, isFalse);
    expect(c.doubleDown(), isFalse);
    expect(c.canHit, isTrue);
    c.dispose();
  });

  test('records each round once, with honest outcomes', () async {
    shoe.queue('10S 6H 9D 10C KH 10H 10D 7S 9C 8S 10S 10C 8H');
    final c = await open();
    c.deal();
    c.stand(); // win: dealer busts
    c.deal();
    c.stand(); // lose: 17 against 19
    c.deal();
    c.stand(); // push: 18 against 18
    final s = stats.blackjackStats;
    expect(s.rounds, 3);
    expect(s.roundsWon, 1);
    expect(s.roundsPushed, 1);
    expect(s.wagered, 30);
    expect(s.paid, 30);
    expect(s.biggestWin, 20);
    expect(stats.stats.playsByGame['blackjack'], 3);
    expect(stats.stats.totalGamesWon, 1);
    expect(stats.stats.totalGamesDecided, 2);
    c.dispose();
  });

  test('achievements are recorded and announced once', () async {
    shoe.queue('AS 9H KD 7C AH 9H KD 7C');
    final c = await open();
    c.deal();
    expect(c.takeNewAchievements().map((a) => a.id), [
      BlackjackAchievementIds.natural,
    ]);
    expect(c.takeNewAchievements(), isEmpty);
    c.deal();
    expect(c.takeNewAchievements(), isEmpty, reason: 'already unlocked');
    expect(stats.blackjackStats.blackjacks, 2);
    c.dispose();
  });

  test('a round in play resumes exactly and is never redealt', () async {
    shoe.queue('8S 6H 8D 10C 3H 9C 5S');
    final first = await open(bet: 20);
    first.deal();
    first.split();
    await Future<void>.delayed(Duration.zero);
    expect(storage.values.containsKey(BlackjackSaveService.storageKey), isTrue);
    first.dispose();

    final second = await open();
    expect(second.game.phase, BlackjackPhase.playerTurn);
    expect(second.game.hands.length, 2);
    expect(second.bet, 20);
    expect(shoe.shuffles, 1, reason: 'no new shoe on resume');
    second.stand();
    second.stand();
    expect(second.game.isComplete, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(
      storage.values.containsKey(BlackjackSaveService.storageKey),
      isFalse,
    );
    second.dispose();
  });

  test('a corrupt save opens a fresh table', () async {
    storage.values[BlackjackSaveService.storageKey] = '{"version":1,"x":';
    final c = await open();
    expect(c.game.phase, BlackjackPhase.betting);
    c.dispose();
  });

  test('a broke player gets a free refill', () async {
    final c = await open();
    credits.debit(credits.balance - 5);
    expect(c.isBroke, isTrue);
    expect(c.canDeal, isFalse);
    expect(c.message, contains('FREE REFILL'));
    expect(c.refillCredits(), isTrue);
    expect(c.balance, CreditsService.startingBalance);
    expect(c.refillCredits(), isFalse);
    c.dispose();
  });
}

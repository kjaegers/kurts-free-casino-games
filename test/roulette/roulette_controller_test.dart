import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_achievements.dart';
import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_bets.dart';
import 'package:kurts_free_casino_games/features/games/roulette/logic/roulette_game.dart';
import 'package:kurts_free_casino_games/features/games/roulette/roulette_save_service.dart';
import 'package:kurts_free_casino_games/features/games/roulette/roulette_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roulette_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsService stats;
  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedPockets pockets;

  final red = rouletteOutside(RouletteBetKind.red);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    pockets = ScriptedPockets();
  });

  Future<RouletteScreenController> open({
    int chip = 5,
    bool animate = false,
    DateTime Function()? clock,
  }) async {
    stats.setRoulettePreferences(chip: chip);
    final controller = RouletteScreenController(
      stats: stats,
      credits: credits,
      saveService: RouletteSaveService(storage: storage),
      pickPocket: pockets.call,
      tonePlayer: SilentTonePlayer(),
      clock: clock,
      reduceMotion: () => !animate,
    );
    await controller.initialize();
    return controller;
  }

  test('opens an empty table with the remembered chip', () async {
    final c = await open(chip: 25);
    expect(c.chip, 25);
    expect(c.totalBet, 0);
    expect(c.canSpin, isFalse);
    expect(c.message, 'Tap the table to place 25-credit chips');
    c.dispose();
  });

  test('placing chips names the bet; the stake is taken at spin', () async {
    pockets.queue(17);
    final c = await open();
    expect(c.placeChip(rouletteStraight(17)), isTrue);
    expect(c.message, '17 (pays 35 to 1): 5 on it');
    c.selectChip(25);
    expect(stats.rouletteStats.preferredChip, 25);
    c.placeChip(red);
    expect(c.message, 'Red (pays 1 to 1): 25 on it');
    expect(c.totalBet, 30);
    expect(c.balance, 1000, reason: 'nothing taken before the spin');
    expect(c.spin(), isTrue);
    expect(c.game.isComplete, isTrue, reason: 'no animation in this test');
    expect(c.game.payout, 180);
    expect(c.balance, 1000 - 30 + 180);
    expect(c.message, '17 Black · 17 wins: pays 180');
    expect(c.history, [17]);
    c.dispose();
  });

  test('undo and clear take chips back', () async {
    final c = await open();
    c.placeChip(red);
    c.placeChip(rouletteStraight(3));
    expect(c.undo(), isTrue);
    expect(c.message, 'Took back 5 from 3');
    expect(c.totalBet, 5);
    expect(c.clearBets(), isTrue);
    expect(c.totalBet, 0);
    expect(c.undo(), isFalse);
    expect(c.clearBets(), isFalse);
    c.dispose();
  });

  test('chips stay for the next spin', () async {
    pockets
      ..queue(1)
      ..queue(2);
    final c = await open();
    c.placeChip(red);
    c.spin();
    expect(c.message, '1 Red · Red wins: pays 10');
    c.spin();
    expect(c.message, '2 Black · no win this spin');
    expect(c.balance, 1000 - 5 + 10 - 5);
    expect(c.history, [2, 1]);
    c.dispose();
  });

  test('records each spin once, with honest outcomes', () async {
    pockets
      ..queue(17)
      ..queue(0)
      ..queue(5);
    final c = await open();
    c.placeChip(rouletteStraight(17));
    c.placeChip(rouletteStraight(5));
    c.spin(); // Bet 10, paid 180: a win.
    c.spin(); // 0: a loss.
    c.clearBets();
    // Red and Black on a red number returns exactly the stake.
    c.placeChip(red);
    c.placeChip(rouletteOutside(RouletteBetKind.black));
    c.spin();
    final s = stats.rouletteStats;
    expect(s.spins, 3);
    expect(s.spinsWon, 1);
    expect(s.spinsPushed, 1);
    expect(s.wagered, 30);
    expect(s.paid, 190);
    expect(s.net, 160);
    expect(s.biggestWin, 180);
    expect(s.straightWins, 1);
    expect(s.zeros, 1);
    expect(stats.stats.totalGamesPlayed, 3);
    expect(stats.stats.totalGamesWon, 1);
    expect(stats.stats.totalGamesDecided, 2, reason: 'a push has no outcome');
    c.dispose();
  });

  test('the table limit and the balance cap the chips', () async {
    final c = await open(chip: 500);
    expect(c.placeChip(rouletteStraight(9)), isTrue);
    expect(c.placeChip(rouletteStraight(9)), isTrue);
    expect(c.placeChip(rouletteStraight(9)), isFalse);
    expect(c.message, 'The table limit is 1,000 on each bet');
    expect(c.placeChip(red), isFalse, reason: 'only 1,000 credits');
    expect(c.message, 'Not enough credits for another 500 chip');
    expect(c.totalBet, 1000);
    c.dispose();
  });

  test('a losing spin leaves chips the balance can no longer cover', () async {
    credits.debit(900);
    pockets.queue(0);
    final c = await open(chip: 25);
    for (var i = 0; i < 3; i++) {
      c.placeChip(red);
    }
    c.spin();
    expect(c.balance, 25);
    expect(c.betTooHigh, isTrue);
    expect(c.canSpin, isFalse);
    expect(
      c.message,
      '0 Green · no win this spin. Not enough credits to bet the same again',
    );
    c.undo();
    c.undo();
    expect(c.canSpin, isTrue);
    c.dispose();
  });

  test('a broke player refills free', () async {
    credits.debit(995);
    pockets.queue(0);
    final c = await open();
    c.placeChip(red);
    expect(c.refillCredits(), isFalse, reason: 'not broke yet');
    c.spin();
    expect(c.isBroke, isTrue);
    expect(
      c.message,
      '0 Green · no win this spin. Out of credits: tap FREE REFILL',
    );
    expect(c.placeChip(red), isFalse);
    expect(c.refillCredits(), isTrue);
    expect(c.balance, CreditsService.startingBalance);
    expect(c.canSpin, isTrue);
    c.dispose();
  });

  test('pays when the wheel stops, and SKIP shows it at once', () async {
    pockets.queue(32);
    final c = await open(animate: true);
    c.placeChip(red);
    expect(c.spin(), isTrue);
    expect(c.isSpinning, isTrue);
    expect(c.spinDurationNow, RouletteScreenController.spinDuration);
    expect(c.balance, 995, reason: 'not paid while spinning');
    expect(c.canChangeBets, isFalse);
    expect(c.placeChip(red), isFalse);
    expect(c.undo(), isFalse);
    expect(c.message, 'No more bets…');
    await pumpEventQueue();
    expect(storage.values[RouletteSaveService.storageKey], isNotNull);

    expect(c.spinOrSkip(), isTrue);
    expect(c.isSpinning, isFalse);
    expect(c.balance, 1005);
    expect(stats.rouletteStats.spins, 1);
    await pumpEventQueue();
    expect(storage.values[RouletteSaveService.storageKey], isNull);
    c.dispose();
    expect(stats.rouletteStats.spins, 1, reason: 'recorded once');
  });

  testWidgets('the ball lands after four seconds', (tester) async {
    pockets.queue(32);
    final c = (await tester.runAsync(() => open(animate: true)))!;
    c.placeChip(red);
    c.spin();
    await tester.pump(const Duration(milliseconds: 3999));
    expect(c.isSpinning, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(c.isSpinning, isFalse);
    expect(c.balance, 1005);
    c.dispose();
  });

  test('leaving mid-spin pays it; a saved spin is paid on return', () async {
    pockets.queue(32);
    final first = await open(animate: true);
    first.placeChip(red);
    first.spin();
    first.dispose();
    expect(credits.balance, 1005, reason: 'dispose pays the spin');
    expect(stats.rouletteStats.spins, 1);

    // A spin saved by an app that was killed before it could pay.
    final killed = const RouletteGame.newTable()
        .place(rouletteStraight(8), 10)
        .spin(8);
    await RouletteSaveService(storage: storage).save(killed);
    final second = await open();
    expect(second.game.isComplete, isTrue);
    expect(second.game.payout, 360);
    expect(second.balance, 1005 + 360);
    expect(stats.rouletteStats.spins, 2);
    expect(pockets.spins, 1, reason: 'a saved spin is never spun again');
    await pumpEventQueue();
    expect(storage.values[RouletteSaveService.storageKey], isNull);
    second.dispose();
  });

  test('a corrupt save opens an empty table', () async {
    storage.values[RouletteSaveService.storageKey] = '{"version":1,"pocket":';
    final c = await open();
    expect(c.game.phase, RoulettePhase.betting);
    expect(c.totalBet, 0);
    expect(c.balance, 1000);
    c.dispose();
  });

  test('achievements unlock once and are announced once', () async {
    pockets
      ..queue(7)
      ..queue(7);
    final c = await open();
    c.placeChip(rouletteStraight(7));
    c.spin();
    expect(c.takeNewAchievements().map((a) => a.id), [
      RouletteAchievementIds.straightUp,
    ]);
    expect(c.takeNewAchievements(), isEmpty);
    c.spin();
    expect(c.takeNewAchievements().map((a) => a.id), [
      RouletteAchievementIds.dejaVu,
    ]);
    expect(
      stats.achievementState(RouletteAchievementIds.insideStory).progress,
      {'straight'},
    );
    c.dispose();
  });

  test('time played counts the gap between spins, capped', () async {
    var now = DateTime(2026, 10, 30, 12);
    final c = await open(clock: () => now);
    c.placeChip(red);
    now = now.add(const Duration(seconds: 20));
    c.spin();
    expect(stats.stats.totalSecondsPlayed, 20);
    now = now.add(const Duration(hours: 1));
    c.spin();
    expect(stats.stats.totalSecondsPlayed, 20 + 120);
    c.pause();
    now = now.add(const Duration(minutes: 5));
    c.resume();
    now = now.add(const Duration(seconds: 3));
    c.spin();
    expect(stats.stats.totalSecondsPlayed, 20 + 120 + 3);
    c.dispose();
  });
}

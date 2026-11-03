import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_achievements.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_cascade.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_game.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_symbols.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/slots_retro_tech_save_service.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/slots_retro_tech_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'retro_tech_test_support.dart';

/// Four Microchips (1× the bet), then a quiet grid.
final _oneChipWin = dropsFor(chipCornerRows, ['TRJ', 'M', '', '', '']);

/// The same four Microchips twice over: two cascades, 2× the bet.
final _twoCascades = dropsFor(chipCornerRows, ['XXXTRJ', 'XM', '', '', '']);

/// Tokens and Runners in the corner, six Microchips down the right.
final _tokensAndRunners = dropsFor(
  ['TTRRX', 'TTRRX', 'FGCJX', 'JMFGX', 'FGCXX'],
  ['JM', 'MJ', 'JM', 'TRJ', 'TCXCF'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsService stats;
  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedDraws draws;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    draws = ScriptedDraws();
  });

  Future<RetroTechScreenController> open({
    int betLevel = 1,
    bool animate = false,
    DateTime Function()? clock,
  }) async {
    stats.setRetroTechPreferences(betLevel: betLevel);
    final controller = RetroTechScreenController(
      stats: stats,
      credits: credits,
      saveService: RetroTechSaveService(storage: storage),
      draw: draws.call,
      tonePlayer: SilentTonePlayer(),
      clock: clock,
      animationDuration: animate ? null : (_) => Duration.zero,
    );
    await controller.initialize();
    return controller;
  }

  test('starts with the remembered bet', () async {
    final c = await open(betLevel: 3);
    expect(c.betLevel, 3);
    expect(c.totalBet, 30);
    expect(c.game.phase, RetroTechPhase.ready);
    expect(c.game.grid, retroTechRestingGrid);
    expect(c.message, 'Choose your bet, then SPIN');
    c.dispose();
  });

  test('a spin takes the bet and pays every cascade', () async {
    draws
      ..queue(_twoCascades)
      ..queue(_oneChipWin);
    final c = await open(betLevel: 2);
    expect(c.spin(), isTrue);
    expect(c.isSpinning, isFalse, reason: 'no pacing in this test');
    expect(c.game.result!.cascades, 2);
    expect(c.game.payout, 40);
    expect(c.runningWin, 40);
    expect(c.balance, 1000 - 20 + 40);
    expect(c.message, '2 cascades: pays 40');
    c.spin();
    expect(c.message, '4 Microchips: pays 20');
    expect(c.balance, 1000 - 20 + 40 - 20 + 20);
    c.dispose();
  });

  test('records each spin once, with honest outcomes', () async {
    draws
      ..queue(_tokensAndRunners)
      ..queue(_oneChipWin);
    final c = await open();
    c.spin(); // 4 Tokens 50 + 4 Runners 40 + 6 Microchips 20 = 110.
    c.spin(); // 4 Microchips pay back the bet exactly.
    c.spin(); // Nothing.
    final s = stats.retroTechStats;
    expect(s.spins, 3);
    expect(s.spinsWon, 1);
    expect(s.spinsPushed, 1);
    expect(s.wagered, 30);
    expect(s.paid, 120);
    expect(s.biggestWin, 110);
    expect(s.longestChain, 1);
    expect(s.countOf('chip'), 2);
    expect(s.countOf('token'), 1);
    expect(stats.stats.totalGamesPlayed, 3);
    expect(stats.stats.totalGamesWon, 1);
    expect(stats.stats.totalGamesDecided, 2, reason: 'a push has no outcome');
    expect(c.message, 'No win this spin');
    c.dispose();
  });

  test('bet one wraps; max bet bets 50 and spins', () async {
    final c = await open(betLevel: 5);
    c.betOne();
    expect(c.totalBet, 10);
    expect(stats.retroTechStats.preferredBetLevel, 1);
    c.betOne();
    expect(c.totalBet, 20);
    expect(c.maxBet(), isTrue);
    expect(c.totalBet, 50);
    expect(c.balance, 950);
    expect(draws.spins, 1);
    expect(stats.retroTechStats.preferredBetLevel, 5);
    c.dispose();
  });

  test('max bet bets what a small balance covers', () async {
    credits.debit(965);
    final c = await open();
    c.maxBet();
    expect(c.totalBet, 30);
    expect(c.balance, 5);
    expect(c.isBroke, isTrue);
    expect(c.maxBet(), isFalse);
    c.dispose();
  });

  test(
    'cannot bet more than the balance; a broke player refills free',
    () async {
      credits.debit(975);
      final c = await open(betLevel: 3);
      expect(c.canSpin, isFalse);
      expect(c.betTooHigh, isTrue);
      expect(c.message, contains('lower your bet'));
      expect(c.spin(), isFalse);
      expect(c.refillCredits(), isFalse, reason: 'not broke yet');
      c.betOne();
      c.betOne();
      c.betOne(); // Wraps to 10 credits.
      expect(c.spin(), isTrue);
      expect(c.balance, 15);
      c.spin();
      expect(c.isBroke, isTrue);
      expect(c.message, startsWith('Out of credits'));
      expect(c.refillCredits(), isTrue);
      expect(c.balance, CreditsService.startingBalance);
      expect(c.canSpin, isTrue);
      c.dispose();
    },
  );

  testWidgets('the cascade plays out beat by beat, then pays', (tester) async {
    draws.queue(_twoCascades);
    final c = (await tester.runAsync(() => open(animate: true)))!;
    c.spin();
    expect(c.isSpinning, isTrue);
    expect(c.balance, 990, reason: 'not paid while playing out');
    expect(c.canChangeBet, isFalse);
    expect(c.betOne(), isFalse);
    expect((c.beat, c.gridIndex), (RetroTechBeat.falling, 0));
    expect(c.message, 'Spinning…');
    expect(c.runningWin, 0);

    await tester.pump(RetroTechScreenController.firstFall);
    expect((c.beat, c.gridIndex), (RetroTechBeat.winning, 0));
    expect(c.litClusters.single.size, 4);
    expect(c.runningWin, 10);
    expect(c.message, '4 Microchips: 10');

    await tester.pump(RetroTechScreenController.winHold);
    expect((c.beat, c.gridIndex), (RetroTechBeat.falling, 1));
    expect(c.litClusters, isEmpty);
    expect(c.message, 'Cascading…');

    await tester.pump(RetroTechScreenController.cascadeFall);
    expect((c.beat, c.gridIndex), (RetroTechBeat.winning, 1));
    expect(c.runningWin, 20);
    expect(c.message, 'Cascade 2 · 4 Microchips: 10');

    await tester.pump(RetroTechScreenController.winHold);
    await tester.pump(RetroTechScreenController.cascadeFall);
    expect(c.isSpinning, isFalse);
    expect(c.gridIndex, 2);
    expect(c.balance, 1010);
    expect(stats.retroTechStats.spins, 1);
    c.dispose();
  });

  test('STOP skips to the end and pays the same', () async {
    draws.queue(_twoCascades);
    final c = await open(animate: true);
    c.spin();
    await pumpEventQueue();
    expect(storage.values[RetroTechSaveService.storageKey], isNotNull);
    expect(c.spinOrStop(), isTrue);
    expect(c.isSpinning, isFalse);
    expect(c.balance, 1010);
    expect(c.game.grid, c.game.result!.finalGrid);
    await pumpEventQueue();
    expect(storage.values[RetroTechSaveService.storageKey], isNull);
    c.dispose();
    expect(stats.retroTechStats.spins, 1, reason: 'recorded once');
  });

  test('leaving mid-spin pays it; a saved spin is paid on return', () async {
    draws.queue(_twoCascades);
    final first = await open(animate: true);
    first.spin();
    first.dispose();
    expect(credits.balance, 1010, reason: 'dispose pays the spin');
    expect(stats.retroTechStats.spins, 1);

    // A spin saved by an app that was killed before it could pay.
    final killed = RetroTechGame.newSession(
      betLevel: 2,
    ).spin(RetroTechSpinResult.replay(_oneChipWin)!);
    await RetroTechSaveService(storage: storage).save(killed);
    final second = await open();
    expect(second.game.isComplete, isTrue);
    expect(second.game.payout, 20);
    expect(second.balance, 1010 + 20);
    expect(stats.retroTechStats.spins, 2);
    expect(draws.spins, 1, reason: 'a saved spin is never spun again');
    await pumpEventQueue();
    expect(storage.values[RetroTechSaveService.storageKey], isNull);
    second.dispose();
  });

  test('pausing the app pays a spin still playing out', () async {
    draws.queue(_oneChipWin);
    final c = await open(animate: true);
    c.spin();
    c.pause();
    expect(c.isSpinning, isFalse);
    expect(c.balance, 1000);
    c.dispose();
  });

  test('a corrupt save starts a fresh session', () async {
    storage.values[RetroTechSaveService.storageKey] = '{"version":1,"drops":';
    final c = await open();
    expect(c.game.phase, RetroTechPhase.ready);
    expect(c.balance, 1000);
    c.dispose();
  });

  test('achievements unlock once and are announced once', () async {
    draws
      ..queue(_tokensAndRunners)
      ..queue(_tokensAndRunners);
    final c = await open();
    c.spin();
    expect(c.takeNewAchievements().map((a) => a.id).toSet(), {
      RetroTechAchievementIds.tokenRush,
      RetroTechAchievementIds.playerOne,
    });
    expect(c.takeNewAchievements(), isEmpty);
    expect(
      stats.achievementState(RetroTechAchievementIds.fullCollection).progress,
      {'token', 'runner', 'chip'},
    );
    c.spin();
    expect(c.takeNewAchievements(), isEmpty);
    c.dispose();
  });

  test('time played counts the gap between spins, capped', () async {
    var now = DateTime(2026, 11, 2, 12);
    final c = await open(clock: () => now);
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

  test('the fair draw is the default', () async {
    final c = RetroTechScreenController(
      stats: stats,
      credits: credits,
      saveService: RetroTechSaveService(storage: storage),
      tonePlayer: SilentTonePlayer(),
      animationDuration: (_) => Duration.zero,
    );
    await c.initialize();
    for (var i = 0; i < 20; i++) {
      c.spin();
    }
    expect(stats.retroTechStats.spins, 20);
    expect(
      c.game.result!.drops.every((d) => d.length >= retroTechRows),
      isTrue,
    );
    c.dispose();
  });
}

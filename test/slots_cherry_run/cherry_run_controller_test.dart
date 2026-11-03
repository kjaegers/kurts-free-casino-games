import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_achievements.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_game.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_paytable.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_reels.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/slots_cherry_run_save_service.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/slots_cherry_run_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cherry_run_test_support.dart';

const _bel = CherryRunSymbol.bell;
const _sev = CherryRunSymbol.seven;
const _chy = CherryRunSymbol.cherry;
const _lem = CherryRunSymbol.lemon;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsService stats;
  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedStops stops;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    stops = ScriptedStops();
  });

  Future<CherryRunScreenController> open({
    int lines = 1,
    int betPerLine = 1,
    bool animate = false,
    DateTime Function()? clock,
    Duration stopGap = const Duration(milliseconds: 700),
  }) async {
    stats.setCherryRunPreferences(lines: lines, betPerLine: betPerLine);
    final controller = CherryRunScreenController(
      stats: stats,
      credits: credits,
      saveService: CherryRunSaveService(storage: storage),
      pickStop: stops.call,
      tonePlayer: SilentTonePlayer(),
      pickStopGap: () => stopGap,
      clock: clock,
      reduceMotion: () => !animate,
    );
    await controller.initialize();
    return controller;
  }

  test('starts with the remembered lines and bet', () async {
    final c = await open(lines: 2, betPerLine: 4);
    expect(c.lines, 2);
    expect(c.betPerLine, 4);
    expect(c.totalBet, 8);
    expect(c.game.phase, CherryRunPhase.ready);
    expect(c.message, 'Choose lines and bet, then SPIN');
    c.dispose();
  });

  test('a spin takes the bet and pays the winning lines', () async {
    stops.queue(stopsFor([_bel, _bel, _bel]));
    final c = await open(lines: 1, betPerLine: 2);
    expect(c.spin(), isTrue);
    expect(c.isSpinning, isFalse, reason: 'no animation in this test');
    expect(c.game.lineWins.single.win, CherryRunWin.bells);
    expect(c.game.payout, 40);
    expect(c.balance, 1000 - 2 + 40);
    expect(c.message, 'Line 1 · Three Bells: pays 40');
    c.dispose();
  });

  test('records each spin once, with honest outcomes', () async {
    // One Cherry at 1 line × 2 pays 4 for a bet of 2 (a win), then a loss.
    final cherry = stopsFor([_chy, _lem, _lem]);
    stops
      ..queue(cherry)
      ..queue(losingStops);
    final c = await open(lines: 1, betPerLine: 2);
    c.spin();
    c.spin();
    final s = stats.cherryRunStats;
    expect(s.spins, 2);
    expect(s.spinsWon, 1);
    expect(s.wagered, 4);
    expect(s.paid, 4);
    expect(s.net, 0);
    expect(s.biggestWin, 4);
    expect(s.countOf('oneCherry'), 1);
    expect(stats.stats.totalGamesPlayed, 2);
    expect(stats.stats.totalGamesWon, 1);
    expect(stats.stats.totalGamesDecided, 2);
    expect(c.message, 'No win this spin');
    c.dispose();
  });

  test('a spin that returns exactly the bet has no outcome', () async {
    // A lone Cherry pays 2 per credit; at 2 lines × 1 it returns the bet,
    // as long as the other line doesn't pay.
    for (var stop = 0; stop < cherryRunStopCount; stop++) {
      final game = CherryRunGame.newSession(
        lines: 2,
      ).spin([stop, losingStops[1], losingStops[2]]).settle();
      if (game.payout != 2) continue;
      stops.queue(game.stops);
      final c = await open(lines: 2);
      c.spin();
      expect(stats.cherryRunStats.spinsPushed, 1);
      expect(stats.stats.totalGamesDecided, 0);
      c.dispose();
      return;
    }
    fail('No push found');
  });

  test('lines and bet per line wrap; max bet bets 15 and spins', () async {
    final c = await open(lines: 3, betPerLine: 5);
    c.changeLines();
    expect(c.lines, 1);
    c.betOne();
    expect(c.betPerLine, 1);
    expect(stats.cherryRunStats.preferredLines, 1);
    expect(stats.cherryRunStats.preferredBetPerLine, 1);
    expect(c.maxBet(), isTrue);
    expect(c.totalBet, 15);
    expect(c.balance, 985);
    expect(stops.spins, 1);
    c.dispose();
  });

  test('max bet bets what a small balance covers', () async {
    credits.debit(990);
    final c = await open(lines: 1, betPerLine: 1);
    c.maxBet();
    expect((c.lines, c.betPerLine), (3, 3));
    credits.reset();
    credits.debit(998);
    c.maxBet();
    expect((c.lines, c.betPerLine), (2, 1));
    expect(c.balance, 0);
    c.dispose();
  });

  test(
    'cannot bet more than the balance; a broke player refills free',
    () async {
      credits.debit(995);
      final c = await open(lines: 3, betPerLine: 2);
      expect(c.canSpin, isFalse);
      expect(c.betTooHigh, isTrue);
      expect(c.message, contains('lower your bet'));
      expect(c.spin(), isFalse);
      expect(c.refillCredits(), isFalse, reason: 'not broke yet');
      c.changeLines();
      c.changeLines(); // 2 lines × 2 = 4 credits.
      c.spin();
      c.betOne(); // 2 lines × 3 = 6: more than the 1 left.
      expect(c.balance, 1);
      expect(c.isBroke, isFalse);
      c.changeLines(); // 3 lines.
      c.changeLines(); // 1 line × 3.
      expect(c.canSpin, isFalse);
      credits.debit(1);
      expect(c.isBroke, isTrue);
      expect(c.message, startsWith('Out of credits'));
      expect(c.refillCredits(), isTrue);
      expect(c.balance, CreditsService.startingBalance);
      expect(c.canSpin, isTrue);
      c.dispose();
    },
  );

  test('pays when the reels stop, and STOP stops them at once', () async {
    stops.queue(stopsFor([_bel, _bel, _bel]));
    final c = await open(animate: true);
    expect(c.spin(), isTrue);
    expect(c.isSpinning, isTrue);
    expect(c.reelDurations, const [
      Duration(milliseconds: 2000),
      Duration(milliseconds: 2700),
      Duration(milliseconds: 3400),
    ]);
    expect(c.balance, 999, reason: 'not paid while spinning');
    expect(c.canChangeBet, isFalse);
    expect(c.changeLines(), isFalse);
    expect(c.message, 'Spinning…');
    await pumpEventQueue();
    expect(storage.values[CherryRunSaveService.storageKey], isNotNull);

    expect(c.spinOrStop(), isTrue);
    expect(c.isSpinning, isFalse);
    expect(c.balance, 999 + 20);
    expect(stats.cherryRunStats.spins, 1);
    await pumpEventQueue();
    expect(storage.values[CherryRunSaveService.storageKey], isNull);
    c.dispose();
    expect(stats.cherryRunStats.spins, 1, reason: 'recorded once');
  });

  testWidgets('the reels stop one at a time, then the spin is paid', (
    tester,
  ) async {
    stops.queue(stopsFor([_bel, _bel, _bel]));
    final c = (await tester.runAsync(
      () => open(animate: true, stopGap: const Duration(milliseconds: 1500)),
    ))!;
    c.spin();
    Future<void> after(int ms, int stopped) async {
      await tester.pump(Duration(milliseconds: ms));
      expect(c.reelsStopped, stopped, reason: 'after $ms ms more');
    }

    await after(1999, 0);
    await after(1, 1);
    await after(1499, 1);
    await after(1, 2);
    expect(c.isSpinning, isTrue);
    expect(c.balance, 999);
    await after(1500, 3);
    expect(c.isSpinning, isFalse);
    expect(c.balance, 1019);
    c.dispose();
  });

  test('reduce motion pays at once', () async {
    stops.queue(stopsFor([_bel, _bel, _bel]));
    final c = await open();
    c.spin();
    expect(c.isSpinning, isFalse);
    expect(c.reelsStopped, 3);
    expect(c.balance, 1019);
    c.dispose();
  });

  test('the pause between reels is uniform from 0.5 to 2 seconds', () {
    final pick = CherryRunScreenController.randomStopGap(Random(7));
    final gaps = [for (var i = 0; i < 20000; i++) pick().inMilliseconds];
    expect(gaps.reduce(min), 500);
    expect(gaps.reduce(max), 2000);
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    expect(mean, closeTo(1250, 15));
  });

  test('leaving mid-spin pays it; a saved spin is paid on return', () async {
    stops.queue(stopsFor([_bel, _bel, _bel]));
    final first = await open(animate: true);
    first.spin();
    first.dispose();
    expect(credits.balance, 1019, reason: 'dispose pays the spin');
    expect(stats.cherryRunStats.spins, 1);

    // A spin saved by an app that was killed before it could pay.
    final killed = CherryRunGame.newSession(
      lines: 1,
      betPerLine: 2,
    ).spin(stopsFor([_bel, _bel, _bel]));
    await CherryRunSaveService(storage: storage).save(killed);
    final second = await open();
    expect(second.game.isComplete, isTrue);
    expect(second.game.payout, 40);
    expect(second.balance, 1019 + 40);
    expect(stats.cherryRunStats.spins, 2);
    expect(stops.spins, 1, reason: 'a saved spin is never spun again');
    await pumpEventQueue();
    expect(storage.values[CherryRunSaveService.storageKey], isNull);
    second.dispose();
  });

  test('a corrupt save starts a fresh session', () async {
    storage.values[CherryRunSaveService.storageKey] = '{"version":1,"stops":';
    final c = await open();
    expect(c.game.phase, CherryRunPhase.ready);
    expect(c.balance, 1000);
    c.dispose();
  });

  test('achievements unlock once and are announced once', () async {
    stops
      ..queue(stopsFor([_sev, _sev, _sev]))
      ..queue(stopsFor([_sev, _sev, _sev]));
    final c = await open();
    c.spin();
    expect(c.balance, 999 + 1000);
    expect(c.takeNewAchievements().map((a) => a.id), [
      CherryRunAchievementIds.luckySevens,
    ]);
    expect(c.takeNewAchievements(), isEmpty);
    c.spin();
    expect(c.takeNewAchievements(), isEmpty);
    c.dispose();
  });

  test('time played counts the gap between spins, capped', () async {
    var now = DateTime(2026, 10, 29, 12);
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
}

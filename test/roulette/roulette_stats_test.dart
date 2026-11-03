import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/models/roulette_stats.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    await stats.saveNowForTest();
  });

  test('spins and preferences survive a reload', () async {
    final stats = StatsService.instance;
    stats.setRoulettePreferences(chip: 100);
    stats.recordRouletteSpin(
      const RouletteSpinRecord(
        bet: 10,
        payout: 360,
        pocket: 17,
        straightWins: 1,
      ),
    );
    stats.recordRouletteSpin(
      const RouletteSpinRecord(bet: 10, payout: 10, pocket: 3, straightWins: 0),
    );
    stats.recordRouletteSpin(
      const RouletteSpinRecord(bet: 10, payout: 0, pocket: 0, straightWins: 0),
    );
    await stats.saveNowForTest();
    await stats.ensureLoaded(forceReload: true);

    final s = stats.rouletteStats;
    expect(s.preferredChip, 100);
    expect(s.spins, 3);
    expect(s.spinsWon, 1);
    expect(s.spinsPushed, 1);
    expect(s.wagered, 30);
    expect(s.paid, 370);
    expect(s.net, 340);
    expect(s.biggestWin, 360);
    expect(s.straightWins, 1);
    expect(s.zeros, 1);
    expect(stats.stats.playsByGame['roulette'], 3);
    expect(stats.stats.totalGamesDecided, 2, reason: 'a push has no outcome');
  });

  test('reset clears results but keeps preferences', () async {
    final stats = StatsService.instance;
    stats.setRoulettePreferences(chip: 500);
    stats.recordRouletteSpin(
      const RouletteSpinRecord(bet: 5, payout: 0, pocket: 2, straightWins: 0),
    );
    stats.reset();
    expect(stats.rouletteStats.spins, 0);
    expect(stats.rouletteStats.preferredChip, 500);
  });

  test('malformed stats are repaired on load', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({
        'version': 1,
        'rouletteStats': {
          'spins': 4,
          'spinsWon': 9,
          'spinsPushed': 3,
          'wagered': -5,
          'paid': 'lots',
          'biggestWin': 12,
          'straightWins': 7,
          'zeros': -1,
          'preferredChip': 3,
        },
      }),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    final s = stats.rouletteStats;
    expect(s.spins, 4);
    expect(s.spinsWon, 4);
    expect(s.spinsPushed, 0);
    expect(s.wagered, 0);
    expect(s.paid, 0);
    expect(s.biggestWin, 12);
    expect(s.straightWins, 4);
    expect(s.zeros, 0);
    expect(s.preferredChip, 5);
  });

  test('missing stats give the defaults', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({'version': 1}),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    expect(stats.rouletteStats.spins, 0);
    expect(stats.rouletteStats.preferredChip, 5);
  });
}

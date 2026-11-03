import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/models/slots_retro_tech_stats.dart';
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
    stats.setRetroTechPreferences(betLevel: 4);
    stats.recordRetroTechSpin(
      const RetroTechSpinRecord(
        bet: 40,
        payout: 200,
        cascades: 3,
        clusterSymbols: ['chip', 'chip', 'token'],
      ),
    );
    stats.recordRetroTechSpin(
      const RetroTechSpinRecord(
        bet: 40,
        payout: 40,
        cascades: 1,
        clusterSymbols: ['cassette'],
      ),
    );
    stats.recordRetroTechSpin(
      const RetroTechSpinRecord(
        bet: 40,
        payout: 0,
        cascades: 0,
        clusterSymbols: [],
      ),
    );
    await stats.saveNowForTest();
    await stats.ensureLoaded(forceReload: true);

    final s = stats.retroTechStats;
    expect(s.preferredBetLevel, 4);
    expect(s.spins, 3);
    expect(s.spinsWon, 1);
    expect(s.spinsPushed, 1);
    expect(s.wagered, 120);
    expect(s.paid, 240);
    expect(s.net, 120);
    expect(s.biggestWin, 200);
    expect(s.longestChain, 3);
    expect(s.countOf('chip'), 2);
    expect(s.countOf('token'), 1);
    expect(stats.stats.playsByGame['slots_retro_tech'], 3);
    expect(stats.stats.totalGamesDecided, 2, reason: 'a push has no outcome');
  });

  test('reset clears results but keeps the bet', () async {
    final stats = StatsService.instance;
    stats.setRetroTechPreferences(betLevel: 5);
    stats.recordRetroTechSpin(
      const RetroTechSpinRecord(
        bet: 50,
        payout: 0,
        cascades: 0,
        clusterSymbols: [],
      ),
    );
    stats.reset();
    expect(stats.retroTechStats.spins, 0);
    expect(stats.retroTechStats.preferredBetLevel, 5);
  });

  test('malformed stats are repaired on load', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({
        'version': 1,
        'retroTechStats': {
          'spins': 4,
          'spinsWon': 9,
          'spinsPushed': 3,
          'wagered': -5,
          'paid': 'lots',
          'biggestWin': 12,
          'longestChain': -2,
          'clusterCounts': {'chip': 2, 'bad': -1, 'worse': 'x'},
          'preferredBetLevel': 7,
        },
      }),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    final s = stats.retroTechStats;
    expect(s.spins, 4);
    expect(s.spinsWon, 4);
    expect(s.spinsPushed, 0);
    expect(s.wagered, 0);
    expect(s.paid, 0);
    expect(s.biggestWin, 12);
    expect(s.longestChain, 0);
    expect(s.clusterCounts, {'chip': 2});
    expect(s.preferredBetLevel, 1);
  });

  test('missing stats give the defaults', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({'version': 1}),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    expect(stats.retroTechStats.spins, 0);
    expect(stats.retroTechStats.preferredBetLevel, 1);
  });
}

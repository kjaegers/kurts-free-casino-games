import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/models/slots_cherry_run_stats.dart';
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
    stats.setCherryRunPreferences(lines: 2, betPerLine: 4);
    stats.recordCherryRunSpin(
      const CherryRunSpinRecord(
        bet: 8,
        payout: 120,
        winNames: ['bells', 'oneCherry'],
      ),
    );
    stats.recordCherryRunSpin(
      const CherryRunSpinRecord(bet: 8, payout: 8, winNames: ['oneCherry']),
    );
    stats.recordCherryRunSpin(
      const CherryRunSpinRecord(bet: 8, payout: 0, winNames: []),
    );
    await stats.saveNowForTest();
    await stats.ensureLoaded(forceReload: true);

    final s = stats.cherryRunStats;
    expect(s.preferredLines, 2);
    expect(s.preferredBetPerLine, 4);
    expect(s.spins, 3);
    expect(s.spinsWon, 1);
    expect(s.spinsPushed, 1);
    expect(s.wagered, 24);
    expect(s.paid, 128);
    expect(s.net, 104);
    expect(s.biggestWin, 120);
    expect(s.countOf('oneCherry'), 2);
    expect(s.countOf('bells'), 1);
    expect(stats.stats.playsByGame['slots_cherry_run'], 3);
    expect(stats.stats.totalGamesDecided, 2, reason: 'a push has no outcome');
  });

  test('reset clears results but keeps preferences', () async {
    final stats = StatsService.instance;
    stats.setCherryRunPreferences(lines: 1, betPerLine: 5);
    stats.recordCherryRunSpin(
      const CherryRunSpinRecord(bet: 5, payout: 0, winNames: []),
    );
    stats.reset();
    expect(stats.cherryRunStats.spins, 0);
    expect(stats.cherryRunStats.preferredLines, 1);
    expect(stats.cherryRunStats.preferredBetPerLine, 5);
  });

  test('malformed stats are repaired on load', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({
        'version': 1,
        'cherryRunStats': {
          'spins': 4,
          'spinsWon': 9,
          'spinsPushed': 3,
          'wagered': -5,
          'paid': 'lots',
          'biggestWin': 12,
          'winCounts': {'bells': 2, 'bad': -1, 'worse': 'x'},
          'preferredLines': 7,
          'preferredBetPerLine': 0,
        },
      }),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    final s = stats.cherryRunStats;
    expect(s.spins, 4);
    expect(s.spinsWon, 4);
    expect(s.spinsPushed, 0);
    expect(s.wagered, 0);
    expect(s.paid, 0);
    expect(s.biggestWin, 12);
    expect(s.winCounts, {'bells': 2});
    expect(s.preferredLines, 3);
    expect(s.preferredBetPerLine, 1);
  });

  test('missing stats give the defaults', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({'version': 1}),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    expect(stats.cherryRunStats.spins, 0);
    expect(stats.cherryRunStats.preferredLines, 3);
  });
}

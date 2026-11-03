import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/models/texas_holdem_stats.dart';
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

  test('hands and preferences survive a reload', () async {
    final stats = StatsService.instance;
    stats.setTexasHoldemPreferences(opponents: 2, difficulty: 'hard');
    stats.recordTexasHoldemHand(
      const TexasHoldemHandRecord(
        wagered: 100,
        collected: 350,
        wonPot: true,
        folded: false,
        showdown: true,
        knockouts: 1,
        showdownCategory: 6,
      ),
    );
    stats.recordTexasHoldemHand(
      const TexasHoldemHandRecord(
        wagered: 40,
        collected: 0,
        wonPot: false,
        folded: true,
        showdown: false,
        knockouts: 0,
      ),
    );
    // Folding without having bet: no outcome.
    stats.recordTexasHoldemHand(
      const TexasHoldemHandRecord(
        wagered: 0,
        collected: 0,
        wonPot: false,
        folded: true,
        showdown: false,
        knockouts: 0,
      ),
    );
    await stats.saveNowForTest();
    await stats.ensureLoaded(forceReload: true);

    final t = stats.texasHoldemStats;
    expect(t.hands, 3);
    expect(t.handsWon, 1);
    expect(t.handsFolded, 2);
    expect(t.showdowns, 1);
    expect(t.showdownsWon, 1);
    expect(t.knockouts, 1);
    expect(t.wagered, 140);
    expect(t.collected, 350);
    expect(t.net, 210);
    expect(t.biggestPot, 350);
    expect(t.bestShowdownLabel, 'Full House');
    expect(t.preferredOpponents, 2);
    expect(t.preferredDifficulty, 'hard');

    final overview = stats.stats;
    expect(overview.playsByGame['texas_holdem'], 3);
    expect(overview.totalGamesWon, 1);
    expect(overview.totalGamesDecided, 2);
  });

  test('a reset clears results but keeps the table preferences', () async {
    final stats = StatsService.instance;
    stats.setTexasHoldemPreferences(opponents: 1, difficulty: 'easy');
    stats.recordTexasHoldemHand(
      const TexasHoldemHandRecord(
        wagered: 10,
        collected: 30,
        wonPot: true,
        folded: false,
        showdown: false,
        knockouts: 0,
      ),
    );
    stats.reset();
    expect(stats.texasHoldemStats.hands, 0);
    expect(stats.texasHoldemStats.preferredOpponents, 1);
    expect(stats.texasHoldemStats.preferredDifficulty, 'easy');
  });

  test('tolerates corrupt stats', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({
        'version': 1,
        'texasHoldemStats': {
          'hands': 5,
          'handsWon': 9,
          'handsFolded': -3,
          'showdowns': 7,
          'showdownsWon': 8,
          'knockouts': 'many',
          'bestShowdownCategory': 42,
          'preferredOpponents': 9,
          'preferredDifficulty': 'impossible',
        },
      }),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    final t = stats.texasHoldemStats;
    expect(t.hands, 5);
    expect(t.handsWon, 5);
    expect(t.handsFolded, 0);
    expect(t.showdowns, 5);
    expect(t.showdownsWon, 5);
    expect(t.knockouts, 0);
    expect(t.bestShowdownLabel, isNull);
    expect(t.preferredOpponents, 4);
    expect(t.preferredDifficulty, 'normal');
  });
}

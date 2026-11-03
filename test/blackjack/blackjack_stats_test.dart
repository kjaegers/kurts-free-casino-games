import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/models/blackjack_stats.dart';
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

  test('rounds and preferences survive a reload', () async {
    final stats = StatsService.instance;
    stats.setBlackjackPreferences(bet: 50);
    stats.recordBlackjackRound(
      const BlackjackRoundRecord(
        wagered: 100,
        payout: 200,
        hands: 2,
        handsWon: 2,
        blackjack: false,
        doubles: 0,
        splits: 1,
        surrendered: false,
      ),
    );
    stats.recordBlackjackRound(
      const BlackjackRoundRecord(
        wagered: 50,
        payout: 125,
        hands: 1,
        handsWon: 1,
        blackjack: true,
        doubles: 0,
        splits: 0,
        surrendered: false,
      ),
    );
    stats.recordBlackjackRound(
      const BlackjackRoundRecord(
        wagered: 50,
        payout: 25,
        hands: 1,
        handsWon: 0,
        blackjack: false,
        doubles: 0,
        splits: 0,
        surrendered: true,
      ),
    );
    await stats.saveNowForTest();
    await stats.ensureLoaded(forceReload: true);

    final bj = stats.blackjackStats;
    expect(bj.preferredBet, 50);
    expect(bj.rounds, 3);
    expect(bj.roundsWon, 2);
    expect(bj.roundsPushed, 0);
    expect(bj.hands, 4);
    expect(bj.handsWon, 3);
    expect(bj.blackjacks, 1);
    expect(bj.splits, 1);
    expect(bj.surrenders, 1);
    expect(bj.wagered, 200);
    expect(bj.paid, 350);
    expect(bj.net, 150);
    expect(bj.biggestWin, 200);
    expect(stats.stats.playsByGame['blackjack'], 3);
    expect(stats.stats.totalGamesWon, 2);
  });

  test('reset clears results but keeps the bet', () async {
    final stats = StatsService.instance;
    stats.setBlackjackPreferences(bet: 200);
    stats.recordBlackjackRound(
      const BlackjackRoundRecord(
        wagered: 200,
        payout: 0,
        hands: 1,
        handsWon: 0,
        blackjack: false,
        doubles: 0,
        splits: 0,
        surrendered: false,
      ),
    );
    stats.reset();
    expect(stats.blackjackStats.rounds, 0);
    expect(stats.blackjackStats.preferredBet, 200);
  });

  test('malformed stored stats load safely', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({
        'version': 1,
        'blackjackStats': {
          'rounds': 3,
          'roundsWon': 9,
          'roundsPushed': -2,
          'hands': 'many',
          'handsWon': 4,
          'wagered': -10,
          'preferredBet': 15,
        },
      }),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    final bj = stats.blackjackStats;
    expect(bj.rounds, 3);
    expect(bj.roundsWon, 3);
    expect(bj.roundsPushed, 0);
    expect(bj.hands, 0);
    expect(bj.handsWon, 0);
    expect(bj.wagered, 0);
    expect(bj.preferredBet, 10);
  });
}

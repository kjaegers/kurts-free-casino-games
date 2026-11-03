import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/models/video_poker_stats.dart';
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
    stats.setVideoPokerPreferences(variantName: 'deucesWild', bet: 3);
    stats.recordVideoPokerHand(
      const VideoPokerHandRecord(
        variantName: 'deucesWild',
        handName: 'fourDeuces',
        bet: 3,
        payout: 600,
      ),
    );
    stats.recordVideoPokerHand(
      const VideoPokerHandRecord(
        variantName: 'jacksOrBetter',
        handName: null,
        bet: 5,
        payout: 0,
      ),
    );
    await stats.saveNowForTest();
    await stats.ensureLoaded(forceReload: true);

    final vp = stats.videoPokerStats;
    expect(vp.preferredVariantName, 'deucesWild');
    expect(vp.preferredBet, 3);
    expect(vp.hands, 2);
    expect(vp.handsWon, 1);
    expect(vp.wagered, 8);
    expect(vp.paid, 600);
    expect(vp.net, 592);
    expect(vp.biggestWin, 600);
    expect(vp.countOf('fourDeuces'), 1);
    expect(stats.stats.playsByGame['video_poker'], 2);
  });

  test('reset clears results but keeps preferences', () async {
    final stats = StatsService.instance;
    stats.setVideoPokerPreferences(variantName: 'jokerPoker', bet: 2);
    stats.recordVideoPokerHand(
      const VideoPokerHandRecord(
        variantName: 'jokerPoker',
        handName: 'twoPair',
        bet: 2,
        payout: 2,
      ),
    );
    stats.reset();
    expect(stats.videoPokerStats.hands, 0);
    expect(stats.videoPokerStats.preferredVariantName, 'jokerPoker');
  });

  test('malformed stored stats are tolerated', () async {
    SharedPreferences.setMockInitialValues({
      StatsService.storageKey: jsonEncode({
        'version': 1,
        'videoPokerStats': {
          'byVariant': {
            'jacksOrBetter': {
              'hands': 3,
              'handsWon': 9,
              'handsPushed': -1,
              'wagered': 'x',
              'paid': 4,
              'handCounts': {'flush': 1, 'bad': -2, 'worse': 'x'},
            },
            '': {'hands': 1},
            'deucesWild': 'nope',
          },
          'preferredBet': 9,
          'preferredVariantName': 7,
        },
      }),
    });
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    final vp = stats.videoPokerStats;
    expect(vp.byVariant.keys, ['jacksOrBetter']);
    final record = vp.recordFor('jacksOrBetter');
    expect(record.hands, 3);
    expect(record.handsWon, 3);
    expect(record.handsPushed, 0);
    expect(record.wagered, 0);
    expect(record.handCounts, {'flush': 1});
    expect(vp.preferredBet, 5);
    expect(vp.preferredVariantName, isNull);
  });
}

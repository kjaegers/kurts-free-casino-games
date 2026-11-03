import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/models/game_result.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StatsService overview rule', () {
    final service = StatsService.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await service.ensureLoaded(forceReload: true);
      service.reset();
      await service.saveNowForTest();
    });

    test('wins and losses count toward played, won, streak and time', () {
      service.recordGameFinished('baccarat', won: true, durationSeconds: 60);
      service.recordGameFinished('baccarat', won: true, durationSeconds: 30);
      service.recordGameFinished('roulette', won: false, durationSeconds: 10);

      final stats = service.stats;
      expect(stats.totalGamesPlayed, 3);
      expect(stats.totalGamesWon, 2);
      expect(stats.totalGamesDecided, 3);
      expect(stats.currentStreak, 0);
      expect(stats.bestStreak, 2);
      expect(stats.totalSecondsPlayed, 100);
      expect(stats.winRate, closeTo(2 / 3, 1e-9));
    });

    test('endless runs count as played but never as a win or loss', () {
      service.recordGameFinished('blackjack', won: true);
      service.recordGameFinished('slots', won: null, score: 12);
      service.recordGameFinished('slots', won: null, score: 3);
      service.recordGameFinished('blackjack', won: true);

      final stats = service.stats;
      expect(stats.totalGamesPlayed, 4);
      expect(stats.totalGamesDecided, 2);
      expect(stats.totalGamesWon, 2);
      // The endless runs in between neither broke nor extended the streak.
      expect(stats.currentStreak, 2);
      expect(stats.bestStreak, 2);
      expect(stats.winRate, 1.0);
      expect(stats.recentGames[1].hasOutcome, isFalse);
      expect(stats.recentGames[1].score, 3);
    });

    test('recordResult feeds the same overview rule', () {
      service.recordResult(
        GameResult(
          gameId: 'roulette',
          playedAt: DateTime(2026, 10, 13),
          won: true,
          durationSeconds: 42,
        ),
      );

      expect(service.stats.totalGamesPlayed, 1);
      expect(service.stats.totalGamesWon, 1);
      expect(service.stats.playsByGame, {'roulette': 1});
    });

    test('favourite is the most-played game, not the first one played', () {
      service.recordGameFinished('blackjack', won: true);
      service.recordGameFinished('video_poker', won: false);
      service.recordGameFinished('video_poker', won: true);

      expect(service.stats.favoriteGameId, 'video_poker');
    });

    test('favourite ties go to the most recently played game', () {
      service.recordGameFinished('blackjack', won: true);
      service.recordGameFinished('video_poker', won: true);

      expect(service.stats.favoriteGameId, 'video_poker');
    });

    test('overview stats survive a save and reload', () async {
      service.recordGameFinished('blackjack', won: true, durationSeconds: 5);
      service.recordGameFinished('slots', won: null);
      await service.saveNowForTest();

      await service.ensureLoaded(forceReload: true);

      final stats = service.stats;
      expect(stats.totalGamesPlayed, 2);
      expect(stats.totalGamesDecided, 1);
      expect(stats.playsByGame, {'blackjack': 1, 'slots': 1});
      expect(stats.recentGames.first.gameId, 'slots');
      expect(stats.recentGames.first.hasOutcome, isFalse);
      expect(stats.recentGames.last.hasOutcome, isTrue);
    });

    test('older saves without the new keys load sensibly', () async {
      SharedPreferences.setMockInitialValues({
        StatsService.storageKey: jsonEncode({
          'version': 1,
          'gameStats': {
            'totalGamesPlayed': 7,
            'totalGamesWon': 5,
            'currentStreak': 2,
            'bestStreak': 4,
            'totalSecondsPlayed': 888,
            'favoriteGameId': 'craps',
            'recentGames': [
              {
                'gameId': 'blackjack',
                'playedAt': '2026-10-01T10:00:00.000',
                'won': true,
              },
              {
                'gameId': 'blackjack',
                'playedAt': '2026-09-30T10:00:00.000',
                'won': false,
              },
              {
                'gameId': 'craps',
                'playedAt': '2026-09-29T10:00:00.000',
                'won': true,
              },
            ],
          },
        }),
      });
      await service.ensureLoaded(forceReload: true);

      final stats = service.stats;
      // Every game recorded before endless runs counted had an outcome.
      expect(stats.totalGamesDecided, 7);
      expect(stats.winRate, closeTo(5 / 7, 1e-9));
      expect(stats.recentGames.every((r) => r.hasOutcome), isTrue);
      // Play counts are seeded from the recent list.
      expect(stats.playsByGame, {'blackjack': 2, 'craps': 1});
      expect(stats.favoriteGameId, 'blackjack');
    });

    test('reset really clears stats in memory and in storage', () async {
      service.recordGameFinished('blackjack', won: true, durationSeconds: 5);
      await service.saveNowForTest();

      service.reset();
      await service.saveNow();
      await service.ensureLoaded(forceReload: true);

      expect(service.stats.totalGamesPlayed, 0);
      expect(service.stats.playsByGame, isEmpty);
      expect(service.stats.recentGames, isEmpty);
      expect(service.stats.favoriteGameId, isNull);
    });
  });
}

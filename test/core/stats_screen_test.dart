import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_theme.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/stats/stats_screen.dart';
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

  Future<void> pumpStats(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: KfgTheme.dark,
        home: const Scaffold(body: StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty stats show placeholders', (tester) async {
    await pumpStats(tester, const Size(393, 852));

    expect(find.text('Games Played'), findsOneWidget);
    expect(find.text('Play some games first!'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No games played yet.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 568), Size(852, 393)]) {
    testWidgets('overview reflects finished games at $size', (tester) async {
      final stats = StatsService.instance;
      stats.recordGameFinished('not_a_game', won: true, durationSeconds: 90);
      stats.recordGameFinished('not_a_game', won: false, durationSeconds: 30);

      await pumpStats(tester, size);

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('2m'), findsOneWidget);
      // Unregistered ids fall back to the raw id rather than failing.
      expect(find.text('not_a_game'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

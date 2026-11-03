import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_router.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_reels.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/slots_cherry_run_save_service.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/slots_cherry_run_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cherry_run_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedStops stops;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    stats.setCherryRunPreferences(lines: 3, betPerLine: 1);
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    await credits.ensureLoaded();
    stops = ScriptedStops();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    bool disableAnimations = true,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: SlotsCherryRunScreen(
              saveService: CherryRunSaveService(storage: storage),
              credits: credits,
              pickStop: stops.call,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (name, size) in const [
    ('small phone', Size(320, 568)),
    ('phone', Size(393, 852)),
    ('phone landscape', Size(852, 393)),
    ('tablet', Size(1024, 1366)),
  ]) {
    testWidgets('lays out without overflow on a $name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, size: size);
      expect(find.text('SLOTS: CHERRY RUN'), findsOneWidget);
      expect(find.bySemanticsLabel('Credits: 1,000'), findsOneWidget);
      stops.queue(
        stopsFor(const [
          CherryRunSymbol.bell,
          CherryRunSymbol.bell,
          CherryRunSymbol.bell,
        ]),
      );
      await tester.tap(find.text('SPIN · BET 3'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final reels = find.bySemanticsLabel(RegExp('^Reels'));
      expect(tester.getSize(reels).height, greaterThanOrEqualTo(120));
      expect(find.text('Line 1 · Three Bells: pays 20'), findsOneWidget);
      handle.dispose();
    });
  }

  testWidgets('spin, stop and the reels through the UI', (tester) async {
    final handle = tester.ensureSemantics();
    stops.queue(
      stopsFor(const [
        CherryRunSymbol.seven,
        CherryRunSymbol.seven,
        CherryRunSymbol.seven,
      ]),
    );
    await pumpScreen(tester, disableAnimations: false);

    await tester.tap(find.text('SPIN · BET 3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('STOP'), findsOneWidget);
    expect(find.bySemanticsLabel('Reels spinning'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 997'), findsOneWidget);

    await tester.tap(find.text('STOP'));
    await tester.pumpAndSettle();
    expect(find.text('Line 1 · Three Sevens: pays 1,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 1,997'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Middle row: Seven, Seven, Seven')),
      findsOneWidget,
    );
    expect(find.textContaining('Achievement unlocked'), findsOneWidget);
    expect(find.text('SPIN · BET 3'), findsOneWidget);

    // The reels stop on their own, too.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    expect(
      find.bySemanticsLabel('Reels spinning, 1 of 3 stopped'),
      findsOneWidget,
    );
    expect(find.text('STOP'), findsOneWidget);
    // The last reel stops within 2 + 2 + 2 seconds.
    await tester.pump(const Duration(milliseconds: 4000));
    await tester.pumpAndSettle();
    expect(find.text('No win this spin'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 1,994'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('keyboard changes lines and bet', (tester) async {
    await pumpScreen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    expect(find.text('SPIN · BET 2'), findsOneWidget);
    await tester.tap(find.text('Max Bet'));
    await tester.pumpAndSettle();
    expect(credits.balance, 985);
    expect(find.text('SPIN · BET 15'), findsOneWidget);
  });

  testWidgets('a broke player gets a free refill', (tester) async {
    credits.debit(credits.balance);
    await pumpScreen(tester);
    expect(find.textContaining('Out of credits'), findsOneWidget);
    await tester.tap(find.text('FREE REFILL: 1,000 CREDITS'));
    await tester.pumpAndSettle();
    expect(credits.balance, CreditsService.startingBalance);
    expect(find.text('SPIN · BET 3'), findsOneWidget);
  });

  testWidgets('How to Play opens', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('How to Play'));
    await tester.pumpAndSettle();
    expect(find.text('THE REELS AND THE ODDS'), findsOneWidget);
  });

  testWidgets('the route opens the game', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: KfgRouter.onGenerateRoute,
        initialRoute: KfgRoutes.slotsCherryRun,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SLOTS: CHERRY RUN'), findsOneWidget);
  });
}

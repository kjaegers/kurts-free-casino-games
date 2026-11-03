import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_router.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/roulette/roulette_save_service.dart';
import 'package:kurts_free_casino_games/features/games/roulette/roulette_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roulette_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedPockets pockets;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    stats.setRoulettePreferences(chip: 5);
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    await credits.ensureLoaded();
    pockets = ScriptedPockets();
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
            child: RouletteScreen(
              saveService: RouletteSaveService(storage: storage),
              credits: credits,
              pickPocket: pockets.call,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the middle of a number or box on the table.
  Future<void> tapBet(WidgetTester tester, Pattern label) async {
    await tester.tapAt(tester.getCenter(find.bySemanticsLabel(label)));
    await tester.pump();
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
      expect(find.text('ROULETTE'), findsOneWidget);
      expect(find.bySemanticsLabel('Credits: 1,000'), findsOneWidget);
      pockets.queue(17);
      await tapBet(tester, RegExp(r'^17 Black, pays 35 to 1'));
      await tapBet(tester, RegExp(r'^Red, pays 1 to 1'));
      await tester.tap(find.text('SPIN · BET 10'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('17 Black · 17 wins: pays 180'), findsOneWidget);
      // Every number stays a usable size.
      final cell = tester.getSize(
        find.bySemanticsLabel(RegExp(r'^17 Black, pays')),
      );
      expect(cell.width, greaterThanOrEqualTo(30));
      expect(cell.height, greaterThanOrEqualTo(20));
      final wheel = find.bySemanticsLabel(RegExp('^Roulette wheel'));
      expect(tester.getSize(wheel).height, greaterThanOrEqualTo(80));
      handle.dispose();
    });
  }

  testWidgets('bet, spin and skip through the UI', (tester) async {
    final handle = tester.ensureSemantics();
    pockets.queue(0);
    await pumpScreen(tester, disableAnimations: false);
    expect(find.text('Tap the table to place 5-credit chips'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'nothing to spin yet',
    );

    await tester.tap(find.bySemanticsLabel('25-credit chip'));
    await tapBet(tester, RegExp(r'^0 Green'));
    expect(find.text('0 (pays 35 to 1): 25 on it'), findsOneWidget);
    await tapBet(tester, RegExp(r'^1st 12'));
    await tapBet(tester, RegExp(r'^1st 12'));
    expect(find.text('1st 12 (pays 2 to 1): 50 on it'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(find.text('SPIN · BET 50'), findsOneWidget);

    await tester.tap(find.text('SPIN · BET 50'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('SKIP'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Roulette wheel, ball rolling'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Credits: 950'), findsOneWidget);

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();
    expect(find.text('0 Green · 0 wins: pays 900'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 1,850'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Roulette wheel, landed on 0 Green'),
      findsOneWidget,
    );
    expect(find.textContaining('Achievement unlocked'), findsOneWidget);

    // The same chips again, and the wheel stops on its own.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4100));
    await tester.pumpAndSettle();
    expect(find.text('36 Red · no win this spin'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 1,800'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Latest numbers, newest first: 36 Red, 0')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a tap on the line between two numbers splits them', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(tester);
    final eight = tester.getRect(find.bySemanticsLabel(RegExp(r'^8 Black')));
    // On the phone the numbers run down the screen: 5 is just above 8.
    await tester.tapAt(eight.topCenter);
    await tester.pump();
    expect(find.text('Split 5/8 (pays 17 to 1): 5 on it'), findsOneWidget);
    await tester.tapAt(eight.topLeft);
    await tester.pump();
    expect(find.text('Corner 4/5/7/8 (pays 8 to 1): 5 on it'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('keyboard picks chips, undoes and clears', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tapBet(tester, RegExp(r'^Black, pays'));
    await tapBet(tester, RegExp(r'^Odd, pays'));
    expect(find.text('SPIN · BET 200'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.pump();
    expect(find.text('SPIN · BET 100'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(find.text('SPIN'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a broke player gets a free refill', (tester) async {
    credits.debit(credits.balance);
    await pumpScreen(tester);
    expect(find.textContaining('Out of credits'), findsOneWidget);
    await tester.tap(find.text('FREE REFILL: 1,000 CREDITS'));
    await tester.pumpAndSettle();
    expect(credits.balance, CreditsService.startingBalance);
    expect(find.text('SPIN'), findsOneWidget);
  });

  testWidgets('How to Play opens', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('How to Play'));
    await tester.pumpAndSettle();
    expect(find.text('PLACING CHIPS'), findsOneWidget);
  });

  testWidgets('the route opens the game', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: KfgRouter.onGenerateRoute,
        initialRoute: KfgRoutes.roulette,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ROULETTE'), findsOneWidget);
  });
}

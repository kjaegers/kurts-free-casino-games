import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_router.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/slots_retro_tech_save_service.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/slots_retro_tech_screen.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/slots_retro_tech_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'retro_tech_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedDraws draws;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    stats.setRetroTechPreferences(betLevel: 1);
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    await credits.ensureLoaded();
    draws = ScriptedDraws();
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
            child: SlotsRetroTechScreen(
              saveService: RetroTechSaveService(storage: storage),
              credits: credits,
              draw: draws.call,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lets a spin play out to the end.
  Future<void> playOut(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
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
      expect(find.text('SLOTS: RETRO TECH'), findsOneWidget);
      expect(find.bySemanticsLabel('Credits: 1,000'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Paytable')), findsOneWidget);
      draws.queue(dropsFor(chipCornerRows, ['XXXTRJ', 'XM', '', '', '']));
      await tester.tap(find.text('SPIN · BET 10'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await playOut(tester);
      expect(tester.takeException(), isNull);
      final grid = find.bySemanticsLabel(RegExp('^Grid'));
      expect(tester.getSize(grid).height, greaterThanOrEqualTo(150));
      expect(find.text('2 cascades: pays 20'), findsOneWidget);
      handle.dispose();
    });
  }

  testWidgets('spin, cascade and stop through the UI', (tester) async {
    final handle = tester.ensureSemantics();
    draws.queue(dropsFor(chipCornerRows, ['XXXTRJ', 'XM', '', '', '']));
    await pumpScreen(tester, disableAnimations: false);

    await tester.tap(find.text('SPIN · BET 10'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('STOP'), findsOneWidget);
    expect(find.bySemanticsLabel('Grid filling'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 990'), findsOneWidget);

    await tester.pump(RetroTechScreenController.firstFall);
    expect(find.text('4 Microchips: 10'), findsOneWidget);
    expect(find.bySemanticsLabel('Winning: 4 Microchips'), findsOneWidget);

    // Mid-cascade: the winners fade out as the rest start to fall.
    await tester.pump(RetroTechScreenController.winHold);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('Cascading…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('STOP'));
    await tester.pumpAndSettle();
    expect(find.text('2 cascades: pays 20'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 1,010'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Row 1: Joystick, CRT Monitor')),
      findsOneWidget,
    );
    expect(find.text('SPIN · BET 10'), findsOneWidget);

    // A spin plays out on its own, too.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('STOP'), findsOneWidget);
    await playOut(tester);
    expect(find.text('No win this spin'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 1,000'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('an achievement is announced', (tester) async {
    draws.queue(
      dropsFor(
        ['TTRRX', 'TTRRX', 'FGCJX', 'JMFGX', 'FGCXX'],
        ['JM', 'MJ', 'JM', 'TRJ', 'TCXCF'],
      ),
    );
    await pumpScreen(tester);
    await tester.tap(find.text('SPIN · BET 10'));
    // One cascade: the fall, the win, then the next fall; the note then
    // shows for a few seconds.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Achievement unlocked'), findsOneWidget);
    expect(find.text('3 clusters: pays 110'), findsOneWidget);
    await playOut(tester);
  });

  testWidgets('keyboard changes the bet', (tester) async {
    await pumpScreen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    expect(find.text('SPIN · BET 20'), findsOneWidget);
    await tester.tap(find.text('Max Bet'));
    await playOut(tester);
    expect(credits.balance, 950);
    expect(find.text('SPIN · BET 50'), findsOneWidget);
  });

  testWidgets('a broke player gets a free refill', (tester) async {
    credits.debit(credits.balance);
    await pumpScreen(tester);
    expect(find.textContaining('Out of credits'), findsOneWidget);
    await tester.tap(find.text('FREE REFILL: 1,000 CREDITS'));
    await tester.pumpAndSettle();
    expect(credits.balance, CreditsService.startingBalance);
    expect(find.text('SPIN · BET 10'), findsOneWidget);
  });

  testWidgets('How to Play opens', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('How to Play'));
    await tester.pumpAndSettle();
    expect(find.text('CLUSTERS AND CASCADES'), findsOneWidget);
  });

  testWidgets('the route opens the game', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: KfgRouter.onGenerateRoute,
        initialRoute: KfgRoutes.slotsRetroTech,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SLOTS: RETRO TECH'), findsOneWidget);
  });
}

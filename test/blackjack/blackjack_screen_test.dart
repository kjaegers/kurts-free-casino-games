import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_router.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/blackjack_save_service.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/blackjack_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'blackjack_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedShoe shoe;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    stats.setBlackjackPreferences(bet: 10);
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    await credits.ensureLoaded();
    shoe = ScriptedShoe();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(393, 852),
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
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: BlackjackScreen(
              saveService: BlackjackSaveService(storage: storage),
              credits: credits,
              shuffleShoe: shoe.call,
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
    testWidgets('lays out four split hands without overflow on a $name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      shoe.queue('8S 6H 8D 10C 8H 8C 8S 2D 3D 4D 5D 2C 3C');
      await pumpScreen(tester, size: size);
      expect(find.text('BLACKJACK'), findsOneWidget);
      expect(find.bySemanticsLabel('Credits: 1,000'), findsOneWidget);
      await tester.tap(find.text('DEAL · BET 10'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Split'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp(r'^Hand 4 of 4')), findsOneWidget);
      // Hit the first hand until it has five cards: the fan must still fit.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('HIT'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }

  testWidgets('bet, deal, hit and stand through the UI', (tester) async {
    final handle = tester.ensureSemantics();
    shoe.queue('5S 6H 4D 10C 10H KS');
    await pumpScreen(tester);

    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    expect(find.text('DEAL · BET 60'), findsOneWidget);
    await tester.tap(find.text('DEAL · BET 60'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Credits: 940'), findsOneWidget);
    expect(find.text('New shoe. You have 9. Hit or stand?'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Dealer: Six of Hearts, a face-down')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();
    expect(find.text('You have 19. Hit or stand?'), findsOneWidget);

    await tester.tap(find.text('STAND'));
    await tester.pumpAndSettle();
    // Dealer 6 + 10 = 16 draws the King and busts.
    expect(find.text('Dealer busts! Pays 120.'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 1,060'), findsOneWidget);
    expect(find.text('DEAL · BET 60'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('insurance is offered against an ace', (tester) async {
    shoe.queue('9S AH 7D KC');
    await pumpScreen(tester);
    await tester.tap(find.text('DEAL · BET 10'));
    await tester.pumpAndSettle();
    expect(find.text('INSURANCE · 5'), findsOneWidget);
    await tester.tap(find.text('INSURANCE · 5'));
    await tester.pumpAndSettle();
    expect(
      find.text('Dealer has blackjack. Insurance pays 15.'),
      findsOneWidget,
    );
    expect(credits.balance, 1000);
  });

  testWidgets('a broke player gets a free refill', (tester) async {
    credits.debit(credits.balance);
    await pumpScreen(tester);
    expect(find.textContaining('Out of credits'), findsOneWidget);
    await tester.tap(find.text('FREE REFILL: 1,000 CREDITS'));
    await tester.pumpAndSettle();
    expect(credits.balance, CreditsService.startingBalance);
    expect(find.text('DEAL · BET 10'), findsOneWidget);
  });

  testWidgets('How to Play opens', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('How to Play'));
    await tester.pumpAndSettle();
    expect(find.text('HOUSE RULES'), findsOneWidget);
  });

  testWidgets('the route opens the game', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: KfgRouter.onGenerateRoute,
        initialRoute: KfgRoutes.blackjack,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BLACKJACK'), findsOneWidget);
  });
}

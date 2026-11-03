import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_router.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/video_poker_save_service.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/video_poker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'video_poker_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedShuffler shuffler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    stats.setVideoPokerPreferences(variantName: 'jacksOrBetter', bet: 5);
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    await credits.ensureLoaded();
    shuffler = ScriptedShuffler();
  });

  /// Pumps the screen and closes the opening variant picker.
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
            child: VideoPokerScreen(
              saveService: VideoPokerSaveService(storage: storage),
              credits: credits,
              shuffleDeck: shuffler.call,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHOOSE A GAME'), findsOneWidget);
    await tester.ensureVisible(find.text('CLOSE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();
  }

  Finder card(int n) => find.bySemanticsLabel(RegExp('^Card $n:'));

  for (final (name, size) in const [
    ('small phone', Size(320, 568)),
    ('phone', Size(393, 852)),
    ('phone landscape', Size(852, 393)),
    ('tablet', Size(1024, 1366)),
  ]) {
    testWidgets('lays out without overflow on a $name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, size: size);
      expect(find.text('VIDEO POKER'), findsOneWidget);
      expect(find.bySemanticsLabel('Credits: 1,000'), findsOneWidget);
      await tester.tap(find.text('DEAL · BET 5'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(card(1)).width, greaterThanOrEqualTo(44));
      expect(find.text('DRAW'), findsOneWidget);
      handle.dispose();
    });
  }

  testWidgets('deal, hold and draw through the UI', (tester) async {
    final handle = tester.ensureSemantics();
    shuffler.queue('JC JD 2H 5S 9C JH 4D 6C');
    await pumpScreen(tester);

    await tester.tap(find.text('DEAL · BET 5'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Credits: 995'), findsOneWidget);
    expect(
      find.text('Jacks or Better! Tap cards to HOLD, then DRAW'),
      findsOneWidget,
    );

    await tester.tap(card(1));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(card(1), findsOneWidget);
    expect(
      find.bySemanticsLabel('Card 1: Jack of Clubs, held'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Card 2: Jack of Diamonds, held'),
      findsOneWidget,
    );

    await tester.tap(find.text('DRAW'));
    await tester.pumpAndSettle();
    expect(find.text('Three of a Kind: pays 15'), findsOneWidget);
    expect(find.bySemanticsLabel('Credits: 1,010'), findsOneWidget);
    expect(find.text('DEAL · BET 5'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a broke player gets a free refill', (tester) async {
    credits.debit(credits.balance);
    await pumpScreen(tester);
    expect(find.textContaining('Out of credits'), findsOneWidget);
    await tester.tap(find.text('FREE REFILL: 1,000 CREDITS'));
    await tester.pumpAndSettle();
    expect(credits.balance, CreditsService.startingBalance);
    expect(find.text('DEAL · BET 5'), findsOneWidget);
  });

  testWidgets('the variant picker switches games', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Variant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEUCES WILD'));
    await tester.pumpAndSettle();
    expect(find.text('FOUR DEUCES'), findsOneWidget);
    expect(
      StatsService.instance.videoPokerStats.preferredVariantName,
      'deucesWild',
    );
  });

  testWidgets('the route opens the game', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: KfgRouter.onGenerateRoute,
        initialRoute: KfgRoutes.videoPoker,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('VIDEO POKER'), findsOneWidget);
  });
}

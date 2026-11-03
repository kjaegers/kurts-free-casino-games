import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/app/kfg_router.dart';
import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_ai.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_hand.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_table.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/texas_holdem_save_service.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/texas_holdem_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'holdem_test_support.dart';

HoldemDecision _calls(
  HoldemAiView view,
  HoldemOpponent opponent,
  HoldemDifficulty difficulty,
  Random random,
) => const HoldemDecision.checkOrCall();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPersistentStorage storage;
  late CreditsService credits;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    stats.setTexasHoldemPreferences(opponents: 5, difficulty: 'normal');
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    await credits.ensureLoaded();
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
    var seed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: TexasHoldemScreen(
              saveService: TexasHoldemSaveService(storage: storage),
              credits: credits,
              shuffleDeck: () =>
                  const CardDeckFactory().createShuffledDeck(seed: seed++),
              decideOpponent: _calls,
              random: Random(4),
              opponentDelay: const Duration(milliseconds: 10),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// [text] on one of the main buttons (seat tags can say the same).
  Finder onButton(Finder text) =>
      find.descendant(of: find.byType(FilledButton), matching: text);

  bool enabled(WidgetTester tester, Finder label) {
    final button = find.ancestor(
      of: label,
      matching: find.byType(FilledButton),
    );
    return button.evaluate().isNotEmpty &&
        tester.widget<FilledButton>(button.first).onPressed != null;
  }

  /// Checks or calls whenever it's the player's turn until the hand ends.
  Future<void> playHand(WidgetTester tester) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.textContaining('DEAL ·').evaluate().isNotEmpty) return;
      final check = onButton(find.text('CHECK'));
      final call = onButton(find.textContaining(RegExp(r'^CALL ')));
      if (enabled(tester, check)) {
        await tester.tap(check);
      } else if (enabled(tester, call)) {
        await tester.tap(call);
      }
    }
    fail('The hand never finished');
  }

  for (final (name, size) in const [
    ('small phone', Size(320, 568)),
    ('phone', Size(393, 852)),
    ('phone landscape', Size(852, 393)),
    ('tablet', Size(1024, 1366)),
  ]) {
    testWidgets('a full six-seat hand lays out without overflow on a $name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, size: size);
      expect(find.text("TEXAS HOLD'EM"), findsOneWidget);
      expect(find.bySemanticsLabel('Credits: 1,000'), findsOneWidget);
      expect(find.text('DEAL · STACK 1,000'), findsOneWidget);
      await tester.tap(find.text('DEAL · STACK 1,000'));
      await tester.pump();
      expect(find.text('FOLD'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await playHand(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Everyone checked it down: a showdown with the winner named.
      expect(find.textContaining(' with '), findsWidgets);
      handle.dispose();
    });
  }

  testWidgets('the player\'s raise row sets the bet', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('DEAL · STACK 1,000'));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (enabled(
        tester,
        onButton(find.textContaining(RegExp('^(RAISE|BET)'))),
      )) {
        break;
      }
    }
    await tester.tap(find.text('All-in'));
    await tester.pump();
    expect(onButton(find.textContaining('ALL-IN ')), findsOneWidget);
    await tester.tap(find.text('Less'));
    await tester.pump();
    expect(
      onButton(find.textContaining(RegExp(r'^(RAISE TO|BET) '))),
      findsOneWidget,
    );
  });

  testWidgets('opponents and difficulty dialogs seat a new table', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Opponents · 5'));
    await tester.pumpAndSettle();
    expect(find.text('OPPONENTS'), findsOneWidget);
    await tester.tap(find.text('2 OPPONENTS'));
    await tester.pumpAndSettle();
    expect(find.text('Opponents · 2'), findsOneWidget);
    expect(StatsService.instance.texasHoldemStats.preferredOpponents, 2);

    await tester.tap(find.text('Difficulty · Normal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HARD'));
    await tester.pumpAndSettle();
    expect(find.text('Difficulty · Hard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('How to Play opens', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('How to Play'));
    await tester.pumpAndSettle();
    expect(find.text('HAND RANKINGS'), findsOneWidget);
  });

  testWidgets('the route opens the game', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: KfgRouter.onGenerateRoute,
        initialRoute: '/game/texas-holdem',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("TEXAS HOLD'EM"), findsOneWidget);
  });

  test('the save key is the documented one', () {
    expect(TexasHoldemSaveService.storageKey, 'kfcg_texas_holdem_save_v1');
    expect(holdemOpponentNames.toSet(), hasLength(holdemOpponentNames.length));
  });
}

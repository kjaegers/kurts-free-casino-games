import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/cards/playing_card.dart';
import 'package:kurts_free_casino_games/core/cards/animated_playing_card.dart';
import 'package:kurts_free_casino_games/core/cards/playing_card_widget.dart';

void main() {
  const testCard = PlayingCard(
    id: 'test_card',
    suit: CardSuit.hearts,
    rank: CardRank.ten,
    faceUp: true,
  );

  testWidgets('selected and highlighted card fits in compact bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayingCardWidget(
              width: 44,
              height: 63,
              card: testCard,
              selected: true,
              highlighted: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('face-down to face-up reveal remains stable in fixed size', (
    tester,
  ) async {
    final faceUpNotifier = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: faceUpNotifier,
              builder: (context, faceUp, _) {
                return AnimatedPlayingCard(
                  width: 44,
                  height: 63,
                  card: testCard.copyWith(faceUp: faceUp),
                  selected: false,
                  highlighted: false,
                  emptyHint: null,
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    faceUpNotifier.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(tester.takeException(), isNull);
  });

  test('rank and suit text has at least 4.5:1 contrast on the card face', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final (hi, lo) = la > lb ? (la, lb) : (lb, la);
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final ink in [
      PlayingCardWidget.defaultRed,
      PlayingCardWidget.defaultBlack,
      PlayingCardWidget.jokerColor,
    ]) {
      expect(
        contrast(ink, PlayingCardWidget.faceBackground),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('a face-down card is announced without its identity', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PlayingCardWidget(
                width: 44,
                height: 63,
                card: testCard.copyWith(faceUp: false),
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Face-down card'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Ten|Hearts')), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a joker renders and is announced as a joker', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final size in const [Size(36, 52), Size(90, 128)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: PlayingCardWidget(
                  width: size.width,
                  height: size.height,
                  selected: true,
                  card: const PlayingCard.joker(id: 'J01', faceUp: true),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel(RegExp('^Joker')), findsOneWidget);
      }
    } finally {
      semantics.dispose();
    }
  });
}

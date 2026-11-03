import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/widgets/kfg_text_scale.dart';

void main() {
  group('KfgTextScale', () {
    testWidgets('clamps global text scale to 1.1 max', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Builder(
            builder: (context) {
              final wrapped = KfgTextScale.clampGlobal(
                context: context,
                child: const SizedBox.shrink(),
              );
              return Directionality(
                textDirection: TextDirection.ltr,
                child: wrapped,
              );
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final media = MediaQuery.of(context);
      expect(media.textScaler.scale(1.0), 1.1);
    });

    testWidgets('clamps game route text scale tighter than info route', (
      tester,
    ) async {
      Future<double> pumpAndRead(String routeName) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Builder(
              builder: (context) {
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: KfgTextScale.clampForRoute(
                    context: context,
                    routeName: routeName,
                    child: const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        );

        final context = tester.element(find.byType(SizedBox));
        return MediaQuery.of(context).textScaler.scale(1.0);
      }

      final gameScale = await pumpAndRead('/game/match3');
      final infoScale = await pumpAndRead('/settings');

      expect(gameScale, 1.0);
      expect(infoScale, 1.1);
    });

    testWidgets('game route clamps moderate scale to 1.0', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.05)),
          child: Builder(
            builder: (context) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: KfgTextScale.clampForRoute(
                  context: context,
                  routeName: '/game/blackjack',
                  child: const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final media = MediaQuery.of(context);
      expect(media.textScaler.scale(1.0), 1.0);
    });

    testWidgets('Large Text enlarges info routes but not game routes', (
      tester,
    ) async {
      Future<double> pumpAndRead(String routeName) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Builder(
              builder: (context) {
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: KfgTextScale.clampForRoute(
                    context: context,
                    routeName: routeName,
                    largeText: true,
                    child: const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        );

        final context = tester.element(find.byType(SizedBox));
        return MediaQuery.of(context).textScaler.scale(1.0);
      }

      expect(await pumpAndRead('/'), KfgTextScale.largeTextFactor);
      expect(await pumpAndRead('/game/blackjack'), 1.0);
    });
  });
}

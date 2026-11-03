import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_achievements.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_game.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_variant.dart';

import 'video_poker_test_support.dart';

typedef V = VideoPokerVariant;

void main() {
  VideoPokerGame dealt(V variant, String top, {int bet = 5}) =>
      VideoPokerGame.newSession(
        variant: variant,
        bet: bet,
      ).deal(stackedDeck(variant, top));

  group('VideoPokerGame', () {
    test('a new session waits for a bet and a deal', () {
      final game = VideoPokerGame.newSession(variant: V.jacksOrBetter, bet: 3);
      expect(game.phase, VideoPokerPhase.betting);
      expect(game.bet, 3);
      expect(game.hand, isEmpty);
      expect(game.canDeal, isTrue);
      expect(game.canDraw, isFalse);
      expect(() => game.draw(), throwsStateError);
      expect(() => game.toggleHold(0), throwsStateError);
    });

    test('bets are limited to 1–5 coins and fixed during a hand', () {
      final game = VideoPokerGame.newSession(variant: V.jacksOrBetter);
      expect(game.withBet(1).bet, 1);
      expect(() => game.withBet(0), throwsRangeError);
      expect(() => game.withBet(6), throwsRangeError);
      final holding = game.deal(stackedDeck(V.jacksOrBetter, ''));
      expect(holding.canChangeBet, isFalse);
      expect(() => holding.withBet(2), throwsStateError);
      expect(
        () => holding.deal(stackedDeck(V.jacksOrBetter, '')),
        throwsStateError,
      );
    });

    test('deals the top five face up and shows the dealt hand', () {
      final game = dealt(V.jacksOrBetter, 'JC JD 2H 5S 9C');
      expect(game.isHolding, isTrue);
      expect(game.hand.map((c) => c.id), ['C11', 'D11', 'H02', 'S05', 'C09']);
      expect(game.hand.every((c) => c.faceUp), isTrue);
      expect(game.stub, hasLength(47));
      expect(game.currentHand, VideoPokerHand.highPair);
      expect(game.payout, 0);
    });

    test('rejects a deck that is not this variant\'s full deck', () {
      final session = VideoPokerGame.newSession(variant: V.jokerPoker);
      expect(
        () => session.deal(const CardDeckFactory().createOrderedDeck()),
        throwsArgumentError,
      );
      final doubled = stackedDeck(V.jacksOrBetter, '')
        ..[1] = stackedDeck(V.jacksOrBetter, '')[0];
      expect(
        () => VideoPokerGame.newSession(variant: V.jacksOrBetter).deal(doubled),
        throwsArgumentError,
      );
    });

    test('draw replaces unheld cards in deck order and pays', () {
      var game = dealt(V.jacksOrBetter, 'JC JD 2H 5S 9C JH JS 3D');
      game = game.toggleHold(0).toggleHold(1);
      expect(game.held, [true, true, false, false, false]);
      game = game.draw();
      expect(game.isComplete, isTrue);
      expect(game.hand.map((c) => c.id), ['C11', 'D11', 'H11', 'S11', 'D03']);
      expect(game.drawn, [false, false, true, true, true]);
      expect(game.result, VideoPokerHand.fourOfAKind);
      expect(game.payout, 125);
      expect(() => game.draw(), throwsStateError);
    });

    test('holding all five keeps the hand', () {
      var game = dealt(V.jacksOrBetter, '10S JS QS KS AS');
      for (var i = 0; i < 5; i++) {
        game = game.toggleHold(i);
      }
      game = game.draw();
      expect(game.result, VideoPokerHand.royalFlush);
      expect(game.payout, 4000);
    });

    test('the next deal starts from a completed hand with the same bet', () {
      final done = dealt(V.deucesWild, '', bet: 2).draw();
      expect(done.canDeal, isTrue);
      final next = done.withBet(4).deal(stackedDeck(V.deucesWild, ''));
      expect(next.bet, 4);
      expect(next.isHolding, isTrue);
      expect(next.held, everyElement(isFalse));
    });
  });

  group('saving', () {
    test('a held hand round-trips and draws the same cards', () {
      final game = dealt(
        V.jokerPoker,
        '9S 9D JK 4H 5C 9H 9C',
      ).toggleHold(0).toggleHold(1).toggleHold(2);
      final restored = VideoPokerGame.fromJson(
        jsonDecode(jsonEncode(game.toJson())) as Map<String, dynamic>,
      )!;
      expect(restored.variant, V.jokerPoker);
      expect(restored.bet, 5);
      expect(restored.hand, game.hand);
      expect(restored.held, game.held);
      expect(restored.stub.map((c) => c.id), game.stub.map((c) => c.id));
      expect(restored.draw().result, VideoPokerHand.fiveOfAKind);
    });

    test('malformed or finished hands load as null', () {
      final good = dealt(V.jacksOrBetter, '').toJson();
      Map<String, dynamic> with_(String key, Object? value) => {
        ...good,
        key: value,
      };
      for (final bad in [
        with_('version', 99),
        with_('variant', 'pai_gow'),
        with_('phase', 'complete'),
        with_('bet', 6),
        with_('bet', '5'),
        with_('held', [true]),
        with_('held', [1, 0, 0, 0, 0]),
        with_('hand', 'H01'),
        with_('hand', 'X01X02X03X04X05'),
        with_('stub', ''),
        // A card twice and one missing.
        with_(
          'stub',
          (good['stub'] as String).replaceFirst(
            RegExp('^...'),
            (good['hand'] as String).substring(0, 3).toLowerCase(),
          ),
        ),
        // A joker in a 52-card variant.
        with_('stub', 'j01${(good['stub'] as String).substring(3)}'),
      ]) {
        expect(VideoPokerGame.fromJson(bad), isNull, reason: '$bad');
      }
    });
  });

  group('achievements', () {
    Set<String> earnedBy(V variant, String hand, {Set<String>? paid}) {
      var game = dealt(variant, hand);
      for (var i = 0; i < 5; i++) {
        game = game.toggleHold(i);
      }
      return checkVideoPokerAchievements(
        game: game.draw(),
        variantsPaid: paid ?? {},
      ).earned;
    }

    test('each hand achievement unlocks on its hand', () {
      expect(earnedBy(V.jacksOrBetter, '7C 7D 7H 7S 2C'), {
        VideoPokerAchievementIds.fourOfAKind,
      });
      expect(earnedBy(V.jacksOrBetter, '9H 10H JH QH KH'), {
        VideoPokerAchievementIds.straightFlush,
      });
      expect(earnedBy(V.jokerPoker, '9S 9D 9H 9C JK'), {
        VideoPokerAchievementIds.fiveOfAKind,
      });
      expect(earnedBy(V.deucesWild, '2C 2D 2H 2S 9C'), {
        VideoPokerAchievementIds.fourDeuces,
      });
      expect(earnedBy(V.jacksOrBetter, '10S JS QS KS AS'), {
        VideoPokerAchievementIds.royalFlush,
      });
      expect(earnedBy(V.deucesWild, '10S JS QS KS 2D'), isEmpty);
      expect(earnedBy(V.jacksOrBetter, '3C 8D 5H JS 9C'), isEmpty);
    });

    test('Every Variant needs a paying hand in all three', () {
      final check = checkVideoPokerAchievements(
        game: dealt(
          V.jacksOrBetter,
          'JC JD 2H 5S 9C',
        ).toggleHold(0).toggleHold(1).draw(),
        variantsPaid: {'jokerPoker', 'deucesWild'},
      );
      expect(check.paidVariant, 'jacksOrBetter');
      expect(check.earned, contains(VideoPokerAchievementIds.everyVariant));

      final losing = checkVideoPokerAchievements(
        game: dealt(V.jacksOrBetter, '3C 8D 5H JS 9C 4D 6H 10C QH KD').draw(),
        variantsPaid: {'jokerPoker', 'deucesWild'},
      );
      expect(losing.paidVariant, isNull);
      expect(losing.earned, isEmpty);
    });
  });
}

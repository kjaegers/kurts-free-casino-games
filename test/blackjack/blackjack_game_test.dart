import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_achievements.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_game.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_hand.dart';

import '../../tools/blackjack/basic_strategy.dart';
import '../../tools/blackjack/return_check.dart';
import 'blackjack_test_support.dart';

void main() {
  group('hand totals', () {
    test('aces count 11 when that does not bust', () {
      expect(blackjackTotal(cards('AS 6H')), (total: 17, soft: true));
      expect(blackjackTotal(cards('AS 6H 9C')), (total: 16, soft: false));
      expect(blackjackTotal(cards('AS AH')), (total: 12, soft: true));
      expect(blackjackTotal(cards('AS AH 9C')), (total: 21, soft: true));
      expect(blackjackTotal(cards('KS QH')), (total: 20, soft: false));
      expect(blackjackTotal(cards('KS QH 2C')), (total: 22, soft: false));
    });

    test('a two-card 21 is blackjack only on the first deal', () {
      final natural = BlackjackHand(cards: cards('AS KH'), bet: 10);
      expect(natural.isBlackjack, isTrue);
      final split = BlackjackHand(
        cards: cards('AS KH'),
        bet: 10,
        fromSplit: true,
      );
      expect(split.isBlackjack, isFalse);
      expect(split.total, 21);
    });
  });

  group('the deal', () {
    test('deals player, dealer up, player, dealer hole', () {
      final g = dealt('9S 6H 7D 10C');
      expect(g.phase, BlackjackPhase.playerTurn);
      expect(g.hands.single.cards.map((c) => c.id), ['S09', 'D07']);
      expect(g.dealer.map((c) => c.id), ['H06', 'C10']);
      expect(g.dealer[1].faceUp, isFalse);
      expect(g.dealerVisibleTotal, 6);
      expect(g.shoe.length, blackjackShoeSize - 4);
      expect(g.freshShoe, isTrue);
    });

    test('needs a full shoe to shuffle, then deals from the same one', () {
      final table = BlackjackGame.newSession(bet: 10);
      expect(table.needsShuffle, isTrue);
      expect(() => table.deal(), throwsArgumentError);
      expect(
        () => table.deal(shuffledShoe: stackedShoe('').sublist(1)),
        throwsArgumentError,
      );
      final first = dealt('9S 6H 7D 10C').stand();
      expect(first.needsShuffle, isFalse);
      final second = first.deal();
      expect(second.freshShoe, isFalse);
      expect(second.shoe.length, first.shoe.length - 4);
    });

    test('reshuffles once fewer than a quarter of the shoe is left', () {
      final random = Random(3);
      var g = BlackjackGame.newSession(bet: 10);
      var shuffles = 0;
      for (var i = 0; i < 400; i++) {
        if (g.needsShuffle) shuffles++;
        expect(g.shoe.length < blackjackCutCard, g.needsShuffle);
        g = playBasicStrategy(
          g.deal(
            shuffledShoe: g.needsShuffle
                ? BlackjackGame.shuffledShoe((c) => c..shuffle(random))
                : null,
          ),
        );
        expect(g.shoe.length, greaterThan(0));
      }
      expect(shuffles, greaterThan(5));
    });

    test('a shuffled shoe holds every card six times', () {
      final shoe = BlackjackGame.shuffledShoe((c) => c..shuffle(Random(1)));
      expect(BlackjackGame.isFullShoe(shoe), isTrue);
      final counts = <String, int>{};
      for (final c in shoe) {
        counts[c.id] = (counts[c.id] ?? 0) + 1;
      }
      expect(counts.length, 52);
      expect(counts.values.toSet(), {6});
    });
  });

  group('blackjacks and the peek', () {
    test('a player blackjack pays 3:2 at once', () {
      final g = dealt('AS 9H KD 7C', bet: 20);
      expect(g.isComplete, isTrue);
      expect(g.outcomeOf(g.hands.single), BlackjackOutcome.blackjack);
      expect(g.payout, 50);
      expect(g.holeCardRevealed, isTrue);
      expect(g.dealer.length, 2, reason: 'the dealer does not draw');
    });

    test('a dealer blackjack under a ten ends the round before play', () {
      final g = dealt('9S KH 7D AC');
      expect(g.isComplete, isTrue);
      expect(g.outcomeOf(g.hands.single), BlackjackOutcome.lose);
      expect(g.payout, 0);
    });

    test('blackjack against blackjack is a push', () {
      final g = dealt('AS KH QD AC');
      expect(g.outcomeOf(g.hands.single), BlackjackOutcome.push);
      expect(g.payout, 10);
    });

    test('an ace up offers insurance, which pays 2:1', () {
      final g = dealt('9S AH 7D KC', bet: 20);
      expect(g.phase, BlackjackPhase.insurance);
      expect(g.canHit, isFalse);
      expect(g.insuranceCost, 10);
      final insured = g.decideInsurance(take: true);
      expect(insured.isComplete, isTrue);
      expect(insured.insurance, 10);
      expect(insured.totalWagered, 30);
      expect(insured.insurancePayout, 30);
      expect(insured.payout, 30, reason: 'the bet is lost, insurance pays');
    });

    test('insurance is lost when the dealer has no blackjack', () {
      final g = dealt('9S AH 7D 6C', bet: 20).decideInsurance(take: true);
      expect(g.phase, BlackjackPhase.playerTurn);
      expect(g.insurance, 10);
      final done = g.stand();
      expect(done.insurancePayout, 0);
      expect(done.totalWagered, 30);
    });

    test('declining insurance against a dealer blackjack loses the bet', () {
      final g = dealt('9S AH 7D KC').decideInsurance(take: false);
      expect(g.isComplete, isTrue);
      expect(g.payout, 0);
      expect(g.totalWagered, 10);
    });

    test('a player blackjack against an ace waits for the insurance call', () {
      final g = dealt('AS AH KD 6C', bet: 20);
      expect(g.phase, BlackjackPhase.insurance);
      final paid = g.decideInsurance(take: false);
      expect(paid.payout, 50);
    });
  });

  group('playing a hand', () {
    test('hitting past 21 busts and the dealer does not draw', () {
      final g = dealt('10S 6H 6D 10C 9H');
      expect(g.canHit, isTrue);
      final bust = g.hit();
      expect(bust.isComplete, isTrue);
      expect(bust.outcomeOf(bust.hands.single), BlackjackOutcome.bust);
      expect(bust.dealer.length, 2);
      expect(bust.payout, 0);
    });

    test('the dealer hits 16 and stands on soft 17', () {
      final g = dealt('10S 6H 9D 10C 5D 2H').stand();
      // Dealer 6 + 10 = 16, draws the 5 for 21.
      expect(g.dealerTotal, 21);
      expect(g.outcomeOf(g.hands.single), BlackjackOutcome.lose);

      final soft = dealt(
        '10S AH 8D 6C 9H',
      ).decideInsurance(take: false).stand();
      expect(soft.dealer.length, 2, reason: 'stands on soft 17');
      expect(soft.dealerTotal, 17);
      expect(soft.outcomeOf(soft.hands.single), BlackjackOutcome.win);
      expect(soft.payout, 20);
    });

    test('a dealer bust pays every standing hand', () {
      final g = dealt('10S 6H 2D 10C KH').stand();
      expect(g.dealerBust, isTrue);
      expect(g.outcomeOf(g.hands.single), BlackjackOutcome.win);
      expect(g.payout, 20);
    });

    test('equal totals push', () {
      final g = dealt('10S 10H 8D 8C').stand();
      expect(g.outcomeOf(g.hands.single), BlackjackOutcome.push);
      expect(g.payout, 10);
    });

    test('reaching 21 ends the hand by itself', () {
      final g = dealt('10S 6H 5D 10C 6S 3H');
      final done = g.hit();
      expect(done.hands.single.total, 21);
      expect(done.isComplete, isTrue);
    });

    test('double takes one card for twice the bet', () {
      final g = dealt('6S 6H 5D 10C 10H 9S', bet: 20);
      expect(g.canDouble, isTrue);
      expect(g.doubleCost, 20);
      final d = g.doubleDown();
      final hand = d.hands.single;
      expect(hand.doubled, isTrue);
      expect(hand.bet, 40);
      expect(hand.cards.length, 3);
      expect(d.isComplete, isTrue);
      // Dealer 6 + 10 + 9 busts.
      expect(d.payout, 80);
      expect(d.totalWagered, 40);
    });

    test('no double or surrender after a hit', () {
      final g = dealt('2S 6H 3D 10C 4H');
      final hit = g.hit();
      expect(hit.canDouble, isFalse);
      expect(hit.canSurrender, isFalse);
      expect(() => hit.doubleDown(), throwsStateError);
    });

    test('surrender returns half the bet', () {
      final g = dealt('10S 10H 6D 9C', bet: 30);
      expect(g.canSurrender, isTrue);
      final s = g.surrender();
      expect(s.isComplete, isTrue);
      expect(s.outcomeOf(s.hands.single), BlackjackOutcome.surrender);
      expect(s.payout, 15);
    });
  });

  group('splitting', () {
    test('splits a pair, dealing the second hand its card in turn', () {
      final g = dealt('8S 6H 8D 10C 3H 9C');
      expect(g.canSplit, isTrue);
      expect(g.splitCost, 10);
      final s = g.split();
      expect(s.hands.length, 2);
      expect(s.activeIndex, 0);
      expect(s.hands[0].cards.map((c) => c.id), ['S08', 'H03']);
      expect(s.hands[1].cards.length, 1);
      expect(s.canSurrender, isFalse);
      expect(s.canDouble, isTrue, reason: 'double after split');
      final second = s.stand();
      expect(second.activeIndex, 1);
      expect(second.hands[1].cards.map((c) => c.id), ['D08', 'C09']);
      final done = second.stand();
      expect(done.isComplete, isTrue);
      expect(done.totalWagered, 20);
    });

    test('split aces get one card each and 21 is not a blackjack', () {
      final g = dealt('AS 6H AD 10C KH 9C 10D').split();
      expect(g.isComplete, isTrue);
      expect(g.hands.map((h) => h.cards.length), [2, 2]);
      expect(g.hands[0].total, 21);
      expect(g.outcomeOf(g.hands[0]), BlackjackOutcome.win);
      expect(g.payoutOf(g.hands[0]), 20, reason: '1:1, not 3:2');
      // Dealer 6 + 10 + 10 busts, so the A9 wins too.
      expect(g.payout, 40);
    });

    test('pairs split again up to four hands', () {
      var g = dealt('8S 6H 8D 10C 8H 8C 8S 2D 3D 4D 5D');
      g = g.split(); // hand 1 gets 8H
      expect(g.canSplit, isTrue);
      g = g.split(); // hands: [8S 8C] [8H] [8D]
      expect(g.hands.length, 3);
      expect(g.canSplit, isTrue);
      g = g.split();
      expect(g.hands.length, blackjackMaxHands);
      expect(g.canSplit, isFalse, reason: 'four hands at most');
      expect(checkBlackjackAchievements(g), isEmpty);
    });

    test('cards that only share a value do not split', () {
      expect(dealt('KS 6H QD 10C').canSplit, isFalse);
    });
  });

  group('saving', () {
    BlackjackGame? roundTrip(BlackjackGame g) =>
        BlackjackGame.fromJson(jsonDecode(jsonEncode(g.toJson())));

    test('a split round in play restores exactly', () {
      final g = dealt('8S 6H 8D 10C 3H 9C 7S 7H').split();
      final restored = roundTrip(g)!;
      expect(restored.phase, BlackjackPhase.playerTurn);
      expect(restored.activeIndex, 0);
      expect(restored.hands.length, 2);
      expect(restored.shoe.length, g.shoe.length);
      expect(restored.dealer[1].faceUp, isFalse);
      final a = g.stand().stand();
      final b = restored.stand().stand();
      expect(b.payout, a.payout);
      expect(b.dealer.map((c) => c.id), a.dealer.map((c) => c.id));
    });

    test('an insurance decision restores', () {
      final restored = roundTrip(dealt('9S AH 7D 6C', bet: 20))!;
      expect(restored.phase, BlackjackPhase.insurance);
      expect(restored.decideInsurance(take: true).insurance, 10);
    });

    test('finished rounds and bad data are not restored', () {
      expect(roundTrip(dealt('AS 9H KD 7C')), isNull);
      final json = dealt('9S 6H 7D 10C').toJson();
      expect(BlackjackGame.fromJson({...json, 'version': 99}), isNull);
      expect(BlackjackGame.fromJson({...json, 'bet': 15}), isNull);
      expect(BlackjackGame.fromJson({...json, 'shoe': 'xx'}), isNull);
      expect(BlackjackGame.fromJson({...json, 'active': 3}), isNull);
      expect(BlackjackGame.fromJson({...json, 'hands': 'nope'}), isNull);
      expect(BlackjackGame.fromJson({...json, 'insurance': 7}), isNull);
      // A seventh copy of a card is not from a six-deck shoe.
      final shoe = json['shoe'] as String;
      expect(
        BlackjackGame.fromJson({...json, 'shoe': 's09s09s09s09s09s09$shoe'}),
        isNull,
      );
      expect(BlackjackGame.fromJson(const {}), isNull);
    });
  });

  group('achievements', () {
    test('a natural, a won double and a five-card 21', () {
      expect(checkBlackjackAchievements(dealt('AS 9H KD 7C')), {
        BlackjackAchievementIds.natural,
      });
      expect(
        checkBlackjackAchievements(dealt('6S 6H 5D 10C 10H 9S').doubleDown()),
        {BlackjackAchievementIds.doubleDown},
      );
      final five = dealt('2S 10H 3D 7C 4S 5H 7D').hit().hit().hit();
      expect(five.hands.single.total, 21);
      expect(
        checkBlackjackAchievements(five),
        contains(BlackjackAchievementIds.fiveCardTwentyOne),
      );
    });

    test('a clean sweep wins every split hand', () {
      final g = dealt('8S 6H 8D 10C 10H 10S 9C').split().stand().stand();
      expect(g.dealerBust, isTrue);
      expect(
        checkBlackjackAchievements(g),
        contains(BlackjackAchievementIds.cleanSweep),
      );
    });

    test('nothing for a lost round or one in play', () {
      expect(checkBlackjackAchievements(dealt('9S KH 7D AC')), isEmpty);
      expect(checkBlackjackAchievements(dealt('9S 6H 7D 10C')), isEmpty);
    });
  });

  test('basic strategy returns close to the published figure', () {
    // 200,000 rounds is a quick smoke test (one standard error is about
    // 0.25%); the full check is `dart run tools/blackjack/return_check.dart`.
    final result = simulateBasicStrategy(rounds: 200000, seed: 11);
    final percent = 100 + result.mean * 100;
    expect(
      (percent - double.parse(blackjackReturnPercent)).abs(),
      lessThan(4 * result.standardError * 100 + 0.05),
    );
  });
}

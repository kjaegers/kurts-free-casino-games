import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_ai.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_hand.dart';

import 'holdem_test_support.dart';

const _junk = ['2C 7D', '3C 8D', '4C 9D', '5C 10D', '6C JD', '2D 8C'];

void main() {
  group('blinds and order', () {
    test('three-handed: blinds left of the button, button acts first', () {
      final h = dealHand(
        stacks: [1000, 1000, 1000],
        holes: _junk.take(3).toList(),
      );
      expect(h.seats[1].committed, 5);
      expect(h.seats[1].lastMove, HoldemMove.smallBlind);
      expect(h.seats[2].committed, 10);
      expect(h.seats[2].lastMove, HoldemMove.bigBlind);
      expect(h.toAct, 0);
      expect(h.toCall, 10);
      expect(h.currentBet, 10);
      expect(h.canFold, isTrue);
      expect(h.canCheck, isFalse);
    });

    test('heads-up: the button posts the small blind and acts first', () {
      var h = dealHand(stacks: [1000, 1000], holes: ['AS AD', 'KS KD']);
      expect(h.seats[0].committed, 5);
      expect(h.seats[1].committed, 10);
      expect(h.toAct, 0);
      h = h.act(call);
      // The big blind still has the option.
      expect(h.toAct, 1);
      expect(h.canCheck, isTrue);
      h = h.act(call);
      expect(h.street, HoldemStreet.flop);
      expect(h.board, hasLength(3));
      // After the flop the big blind acts first.
      expect(h.toAct, 1);
    });

    test('hole cards are dealt one at a time from the button\'s left', () {
      final h = dealHand(
        stacks: [1000, 1000, 1000],
        holes: ['AS AD', 'KS KD', 'QS QD'],
        button: 1,
      );
      expect(h.seats[0].hole.map((c) => c.id), ['S01', 'D01']);
      expect(h.seats[1].hole.map((c) => c.id), ['S13', 'D13']);
      expect(h.seats[2].hole.map((c) => c.id), ['S12', 'D12']);
    });

    test('a short big blind posts what it has; the bet to call stays 10', () {
      final h = dealHand(
        stacks: [1000, 1000, 6],
        holes: _junk.take(3).toList(),
      );
      expect(h.seats[2].committed, 6);
      expect(h.seats[2].isAllIn, isTrue);
      expect(h.currentBet, 10);
      expect(h.toCall, 10);
    });
  });

  group('raising', () {
    test('a raise must be at least the last raise', () {
      var h = dealHand(
        stacks: [1000, 1000, 1000],
        holes: _junk.take(3).toList(),
      );
      expect(h.minRaiseTo, 20);
      expect(h.isLegal(raiseTo(15)), isFalse);
      expect(() => h.act(raiseTo(15)), throwsStateError);
      h = h.act(raiseTo(40));
      expect(h.seats[0].lastMove, HoldemMove.raise);
      expect(h.toAct, 1);
      expect(h.minRaiseTo, 70);
      expect(h.maxRaiseTo, 1000);
    });

    test('an opening bet after the flop is at least the big blind', () {
      var h = dealHand(stacks: [1000, 1000], holes: ['AS AD', 'KS KD']);
      h = play(h, [call, call]);
      expect(h.currentBet, 0);
      expect(h.minRaiseTo, 10);
      h = h.act(raiseTo(10));
      expect(h.seats[1].lastMove, HoldemMove.bet);
    });

    test('a full raise reopens the betting', () {
      var h = dealHand(
        stacks: [1000, 1000, 1000],
        holes: _junk.take(3).toList(),
      );
      h = play(h, [raiseTo(30), raiseTo(80), fold]);
      expect(h.toAct, 0);
      expect(h.canRaise, isTrue);
    });

    test('a short all-in raise does not reopen betting to those who acted', () {
      var h = dealHand(stacks: [1000, 45, 1000], holes: _junk.take(3).toList());
      h = h.act(raiseTo(30));
      // The small blind moves in for 45: 15 more, short of a 20 raise.
      expect(h.toAct, 1);
      expect(h.minRaiseTo, 45);
      h = h.act(raiseTo(45));
      expect(h.seats[1].lastMove, HoldemMove.allIn);
      expect(h.currentBet, 45);
      // The big blind hadn't acted, so may still raise.
      expect(h.toAct, 2);
      expect(h.canRaise, isTrue);
      h = h.act(call);
      // The first raiser must call the extra 15 but can't raise again.
      expect(h.toAct, 0);
      expect(h.toCall, 15);
      expect(h.canRaise, isFalse);
      h = h.act(call);
      expect(h.street, HoldemStreet.flop);
    });

    test('no raise when nobody left could call it', () {
      var h = dealHand(stacks: [1000, 50], holes: ['AS AD', 'KS KD']);
      h = h.act(raiseTo(200));
      expect(h.toAct, 1);
      expect(h.canRaise, isFalse);
      expect(h.toCall, 40);
    });

    test('folding is only offered with a bet to call', () {
      var h = dealHand(stacks: [1000, 1000], holes: ['AS AD', 'KS KD']);
      h = play(h, [call]);
      expect(h.canCheck, isTrue);
      expect(h.canFold, isFalse);
      expect(() => h.act(fold), throwsStateError);
    });
  });

  group('winning', () {
    test('everyone folding wins the pot; unmatched chips come back', () {
      var h = dealHand(stacks: [1000, 1000], holes: ['2C 7D', 'AS AD']);
      h = play(h, [raiseTo(100), fold]);
      expect(h.isComplete, isTrue);
      expect(h.showdown, isFalse);
      expect(h.pots.single.amount, 20);
      expect(h.pots.single.winners, [0]);
      expect(h.winnings, [110, 0]);
      expect(h.seats[0].stack, 1010);
      expect(h.seats[1].stack, 990);
      expect(h.isRevealed(0), isFalse);
    });

    test('all-in and called: the board runs out to a showdown', () {
      var h = dealHand(
        stacks: [1000, 200],
        holes: ['AS AD', 'KS KD'],
        board: '3H 8S 9C JD 4H',
      );
      h = play(h, [raiseTo(1000), call]);
      expect(h.isComplete, isTrue);
      expect(h.board, hasLength(5));
      expect(h.showdown, isTrue);
      expect(h.pots.single.amount, 400);
      expect(h.winnings, [1200, 0]);
      expect(h.seats[0].stack, 1200);
      expect(h.seats[1].stack, 0);
      expect(h.isRevealed(1), isTrue);
    });

    test('side pots: a short all-in only wins what it matched', () {
      var h = dealHand(
        stacks: [100, 300, 300],
        holes: ['AS AD', 'KS KD', '2C 7D'],
        board: '3H 8S 9C JD 4H',
      );
      h = play(h, [raiseTo(100), raiseTo(300), call]);
      expect(h.isComplete, isTrue);
      expect(h.pots, hasLength(2));
      expect(h.pots[0].amount, 300);
      expect(h.pots[0].eligible, [0, 1, 2]);
      expect(h.pots[0].winners, [0]);
      expect(h.pots[1].amount, 400);
      expect(h.pots[1].eligible, [1, 2]);
      expect(h.pots[1].winners, [1]);
      expect([for (final s in h.seats) s.stack], [300, 400, 0]);
    });

    test('a split pot gives the odd chip to the first winner left of the '
        'button', () {
      var h = dealHand(
        stacks: [1000, 1000, 1000],
        holes: ['2C 3D', '4C 5D', '6C 7D'],
        board: 'AS KS QS JS 10S',
      );
      // Button calls, small blind folds, big blind checks: a pot of 25.
      h = play(h, [call, fold, call]);
      h = checkDown(h);
      expect(h.pots.single.amount, 25);
      expect(h.pots.single.winners, [2, 0]);
      expect(h.winnings, [12, 0, 13]);
      expect(chipsOf(h), 3000);
    });

    test('a folded seat\'s chips stay in the pot but it cannot win', () {
      var h = dealHand(
        stacks: [1000, 1000, 1000],
        holes: ['AS AD', '2C 7D', 'KS KD'],
        board: '3H 8S 9C JD 4H',
      );
      h = play(h, [raiseTo(30), call, call]);
      // Flop: small blind bets, big blind folds, button calls.
      h = play(h, [raiseTo(50), fold, call]);
      h = checkDown(h);
      expect(h.pots.single.eligible, [0, 1]);
      expect(h.pots.single.winners, [0]);
      expect(h.pots.single.amount, 190);
    });
  });

  group('saving', () {
    test('a hand in play survives a round trip', () {
      var h = dealHand(
        stacks: [1000, 45, 800],
        holes: ['AS AD', 'KS KD', 'QS QD'],
        board: '3H 8S 9C JD 4H',
      );
      h = play(h, [raiseTo(30), raiseTo(45)]);
      final json = jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
      final restored = HoldemHand.fromJson(json)!;
      expect(restored.toJson(), h.toJson());
      // And plays on identically.
      expect(checkDown(restored).toJson(), checkDown(h).toJson());
      expect(checkDown(restored).winnings, checkDown(h).winnings);
    });

    test('malformed saves are rejected', () {
      final h = dealHand(stacks: [1000, 1000], holes: ['AS AD', 'KS KD']);
      Map<String, dynamic> json() =>
          jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
      expect(HoldemHand.fromJson(json()), isNotNull);
      expect(HoldemHand.fromJson(json()..['version'] = 99), isNull);
      expect(HoldemHand.fromJson(json()..['street'] = 'complete'), isNull);
      expect(HoldemHand.fromJson(json()..['toAct'] = 7), isNull);
      expect(HoldemHand.fromJson(json()..['board'] = 'S01'), isNull);
      expect(HoldemHand.fromJson(json()..remove('deck')), isNull);
      expect(HoldemHand.fromJson(json()..['deck'] = 'nonsense!'), isNull);
      final dup = json();
      (dup['seats'] as List)[1]['hole'] = (dup['seats'] as List)[0]['hole'];
      expect(HoldemHand.fromJson(dup), isNull);
      final badMove = json();
      (badMove['seats'] as List)[0]['move'] = 'teleport';
      expect(HoldemHand.fromJson(badMove), isNull);
    });
  });

  test('random play with the computer opponents never breaks the rules', () {
    final random = Random(7);
    for (var game = 0; game < 300; game++) {
      final n = 2 + random.nextInt(5);
      final stacks = [for (var i = 0; i < n; i++) 10 + random.nextInt(600)];
      final total = stacks.fold(0, (a, b) => a + b);
      final deck = const CardDeckFactory().createShuffledDeck(random: random);
      var h = HoldemHand.deal(
        stacks: stacks,
        button: random.nextInt(n),
        deck: deck,
        smallBlind: 5,
        bigBlind: 10,
      );
      final difficulty = HoldemDifficulty
          .values[random.nextInt(HoldemDifficulty.values.length)];
      var actions = 0;
      while (h.isInPlay) {
        expect(++actions, lessThan(200));
        final decision = decideHoldemAction(
          HoldemAiView.of(h),
          style: HoldemStyle.values[random.nextInt(HoldemStyle.values.length)],
          difficulty: difficulty,
          random: random,
        );
        expect(h.isLegal(decision), isTrue, reason: '$decision');
        h = h.act(decision);
        expect(chipsOf(h), total);
        if (h.isInPlay && random.nextInt(4) == 0) {
          final json =
              jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>;
          expect(HoldemHand.fromJson(json)?.toJson(), h.toJson());
        }
      }
      final potTotal = h.pots.fold(0, (sum, p) => sum + p.amount);
      expect(h.winnings.fold(0, (a, b) => a + b), h.pot);
      expect(potTotal, lessThanOrEqualTo(h.pot));
      expect(h.seats.every((s) => s.stack >= 0), isTrue);
      for (final pot in h.pots) {
        expect(pot.winners, isNotEmpty);
        expect(pot.eligible.toSet().containsAll(pot.winners), isTrue);
      }
    }
  });
}

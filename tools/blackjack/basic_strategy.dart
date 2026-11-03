// Basic strategy for this table's rules (six decks, dealer stands on all
// 17s, double after split, late surrender, no resplitting aces), used by
// `return_check.dart` to measure the return a perfect basic-strategy player
// gets. Dev-time only: the game itself never plays for the player.

import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_game.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_hand.dart';

enum BasicMove { hit, stand, double, split, surrender }

/// The basic-strategy move for [game]'s active hand. Insurance is always
/// declined (it is a losing bet without counting cards).
BasicMove basicStrategyMove(BlackjackGame game) {
  final hand = game.activeHand!;
  // The dealer's up card, with an ace as 11.
  final rawUp = blackjackCardValue(game.dealerUpCard!);
  final up = rawUp == 1 ? 11 : rawUp;

  BasicMove doubleOr(BasicMove otherwise) =>
      game.canDouble ? BasicMove.double : otherwise;

  if (game.canSurrender) {
    final total = hand.total;
    if (!hand.isSoft &&
        !(hand.isPair && hand.cards.first.rank.value == 8) &&
        ((total == 16 && up >= 9) || (total == 15 && up == 10))) {
      return BasicMove.surrender;
    }
  }

  if (game.canSplit) {
    final pair = blackjackCardValue(hand.cards.first);
    final split = switch (pair) {
      1 || 8 => true,
      9 => up != 7 && up < 10,
      7 || 3 || 2 => up <= 7,
      6 => up <= 6,
      4 => up == 5 || up == 6,
      _ => false, // 5s play as 10, 10s stand
    };
    if (split) return BasicMove.split;
  }

  final total = hand.total;
  if (hand.isSoft) {
    if (total >= 19) return BasicMove.stand;
    if (total == 18) {
      if (up >= 3 && up <= 6) return doubleOr(BasicMove.stand);
      return up >= 9 ? BasicMove.hit : BasicMove.stand;
    }
    final doubleFrom = switch (total) {
      17 => 3,
      16 || 15 => 4,
      _ => 5, // soft 13 and 14
    };
    if (up >= doubleFrom && up <= 6) return doubleOr(BasicMove.hit);
    return BasicMove.hit;
  }

  if (total >= 17) return BasicMove.stand;
  if (total >= 13) return up <= 6 ? BasicMove.stand : BasicMove.hit;
  if (total == 12) return up >= 4 && up <= 6 ? BasicMove.stand : BasicMove.hit;
  if (total == 11) return up == 11 ? BasicMove.hit : doubleOr(BasicMove.hit);
  if (total == 10) return up <= 9 ? doubleOr(BasicMove.hit) : BasicMove.hit;
  if (total == 9) {
    return up >= 3 && up <= 6 ? doubleOr(BasicMove.hit) : BasicMove.hit;
  }
  return BasicMove.hit;
}

/// Plays a dealt [game] to the end with basic strategy.
BlackjackGame playBasicStrategy(BlackjackGame game) {
  var g = game;
  if (g.canDecideInsurance) g = g.decideInsurance(take: false);
  while (g.phase == BlackjackPhase.playerTurn) {
    g = switch (basicStrategyMove(g)) {
      BasicMove.hit => g.hit(),
      BasicMove.stand => g.stand(),
      BasicMove.double => g.doubleDown(),
      BasicMove.split => g.split(),
      BasicMove.surrender => g.surrender(),
    };
  }
  return g;
}

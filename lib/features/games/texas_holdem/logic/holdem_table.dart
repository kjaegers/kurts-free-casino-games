import 'dart:math';

import '../../../../core/cards/card_deck_factory.dart';
import '../../../../core/cards/playing_card.dart';
import 'holdem_ai.dart';
import 'holdem_hand.dart';

// ── Table rules ──────────────────────────────────────────────────────────────

const int holdemSmallBlind = 5;
const int holdemBigBlind = 10;

/// What each computer opponent sits down with (100 big blinds).
const int holdemOpponentBuyIn = 1000;

const int holdemMinOpponents = 1;
const int holdemMaxOpponents = 5;

/// Names for the computer opponents. Original handles, nobody real.
const List<String> holdemOpponentNames = [
  'Volt',
  'Pixel',
  'Nova',
  'Glitch',
  'Byte',
  'Echo',
  'Vector',
  'Laser',
  'Sprite',
  'Cipher',
  'Flux',
  'Quark',
];

/// A computer opponent at the table.
class HoldemOpponent {
  const HoldemOpponent({
    required this.name,
    required this.style,
    required this.stack,
  });

  /// A new opponent with a fresh buy-in, named so no two at the table match.
  factory HoldemOpponent.random(Random random, Set<String> takenNames) {
    final free = holdemOpponentNames
        .where((n) => !takenNames.contains(n))
        .toList();
    return HoldemOpponent(
      name: free[random.nextInt(free.length)],
      style: HoldemStyle.values[random.nextInt(HoldemStyle.values.length)],
      stack: holdemOpponentBuyIn,
    );
  }

  final String name;
  final HoldemStyle style;

  /// Chips in front of them between hands.
  final int stack;

  HoldemOpponent withStack(int stack) =>
      HoldemOpponent(name: name, style: style, stack: stack);
}

/// The table between and during hands, as an immutable value: the player
/// in seat 0, the opponents in seats 1 and up (clockwise), the button and
/// the hand in play.
///
/// The player's chips aren't kept here: they come from the shared credit
/// balance. Each hand the player brings [playerStake] (taken from credits at
/// the deal) and takes back whatever stack is left at the end.
class HoldemTable {
  const HoldemTable._({
    required this.difficulty,
    required this.opponents,
    required this.button,
    required this.hand,
    required this.playerStake,
    required this.handsDealt,
  });

  /// A fresh table of [opponentCount] new opponents. The button starts at a
  /// random seat and moves on before each deal.
  factory HoldemTable.create({
    required int opponentCount,
    required HoldemDifficulty difficulty,
    required Random random,
  }) {
    final count = opponentCount.clamp(holdemMinOpponents, holdemMaxOpponents);
    final opponents = <HoldemOpponent>[];
    for (var i = 0; i < count; i++) {
      opponents.add(
        HoldemOpponent.random(random, {for (final o in opponents) o.name}),
      );
    }
    return HoldemTable._(
      difficulty: difficulty,
      opponents: List.unmodifiable(opponents),
      button: random.nextInt(count + 1),
      hand: null,
      playerStake: 0,
      handsDealt: 0,
    );
  }

  final HoldemDifficulty difficulty;
  final List<HoldemOpponent> opponents;

  /// The seat with the dealer button for the current (or last) hand.
  final int button;

  /// The hand in play, or the last one (complete) until the next deal.
  final HoldemHand? hand;

  /// The chips the player brought to [hand].
  final int playerStake;

  /// Hands dealt at this table.
  final int handsDealt;

  int get seatCount => opponents.length + 1;
  bool get isInPlay => hand?.isInPlay ?? false;

  /// The most the player can bring to a hand: as much as the deepest
  /// opponent stack (a busted opponent is replaced by a full buy-in), since
  /// more could never be won or lost.
  int get playerCap => opponents
      .map((o) => o.stack == 0 ? holdemOpponentBuyIn : o.stack)
      .reduce(max);

  /// What the player takes back once [hand] is complete.
  int get playerFinalStack =>
      hand?.isComplete == true ? hand!.seats[0].stack : 0;

  /// Replaces busted opponents with new ones, moves the button on and deals
  /// a hand from [deck] (a full, shuffled deck) with the player bringing
  /// [playerStack] chips.
  HoldemTable deal({
    required int playerStack,
    required List<PlayingCard> deck,
    required Random random,
  }) {
    if (isInPlay) throw StateError('A hand is already in play');
    if (playerStack <= 0) throw ArgumentError('The player needs chips');
    final seated = <HoldemOpponent>[];
    for (final o in opponents) {
      if (o.stack > 0) {
        seated.add(o);
      } else {
        final taken = {
          for (final other in opponents) other.name,
          for (final other in seated) other.name,
        };
        seated.add(HoldemOpponent.random(random, taken));
      }
    }
    final nextButton = (button + 1) % seatCount;
    final hand = HoldemHand.deal(
      stacks: [playerStack, for (final o in seated) o.stack],
      button: nextButton,
      deck: deck,
      smallBlind: holdemSmallBlind,
      bigBlind: holdemBigBlind,
    );
    return HoldemTable._(
      difficulty: difficulty,
      opponents: List.unmodifiable(seated),
      button: nextButton,
      hand: hand,
      playerStake: playerStack,
      handsDealt: handsDealt + 1,
    )._settled();
  }

  /// The seat to act makes [decision].
  HoldemTable act(HoldemDecision decision) {
    final current = hand;
    if (current == null || !current.isInPlay) {
      throw StateError('No hand in play');
    }
    return _withHand(current.act(decision))._settled();
  }

  /// The computer opponent to act now, or null when it's the player's turn
  /// or no hand is in play.
  HoldemOpponent? get opponentToAct {
    final current = hand;
    if (current == null || current.toAct <= 0) return null;
    return opponents[current.toAct - 1];
  }

  bool get isPlayerTurn => hand?.toAct == 0;

  HoldemTable _withHand(HoldemHand hand) => HoldemTable._(
    difficulty: difficulty,
    opponents: opponents,
    button: button,
    hand: hand,
    playerStake: playerStake,
    handsDealt: handsDealt,
  );

  /// Once the hand is complete, the opponents keep their final stacks.
  HoldemTable _settled() {
    final current = hand;
    if (current == null || !current.isComplete) return this;
    return HoldemTable._(
      difficulty: difficulty,
      opponents: List.unmodifiable([
        for (var i = 0; i < opponents.length; i++)
          opponents[i].withStack(current.seats[i + 1].stack),
      ]),
      button: button,
      hand: current,
      playerStake: playerStake,
      handsDealt: handsDealt,
    );
  }

  /// A full deck, shuffled by [shuffle].
  static List<PlayingCard> shuffledDeck(
    List<PlayingCard> Function(List<PlayingCard>) shuffle,
  ) => shuffle(const CardDeckFactory().createOrderedDeck());

  // ── Persistence ────────────────────────────────────────────────────────────

  static const int schemaVersion = 1;

  /// The table, with the hand only while it is in play.
  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'difficulty': difficulty.name,
    'opponents': [
      for (final o in opponents)
        {'name': o.name, 'style': o.style.name, 'stack': o.stack},
    ],
    'button': button,
    'handsDealt': handsDealt,
    if (hand case final h? when h.isInPlay) ...{
      'hand': h.toJson(),
      'playerStake': playerStake,
    },
  };

  /// Restores a saved table. Returns null for anything malformed, never
  /// throwing. A hand that can't be restored invalidates the whole save,
  /// so its chips are never silently dropped while the table carries on.
  static HoldemTable? fromJson(Map<String, dynamic> json) {
    try {
      if (json['version'] != schemaVersion) return null;
      final difficulty = HoldemDifficulty.byName(json['difficulty'] as String?);
      final rawOpponents = json['opponents'];
      final button = json['button'];
      final handsDealt = json['handsDealt'];
      if (difficulty == null ||
          rawOpponents is! List ||
          rawOpponents.length < holdemMinOpponents ||
          rawOpponents.length > holdemMaxOpponents ||
          button is! int ||
          button < 0 ||
          button > rawOpponents.length ||
          handsDealt is! int ||
          handsDealt < 0) {
        return null;
      }
      final opponents = <HoldemOpponent>[];
      for (final raw in rawOpponents) {
        if (raw is! Map) return null;
        final name = raw['name'];
        final style = HoldemStyle.values
            .where((s) => s.name == raw['style'])
            .firstOrNull;
        final stack = raw['stack'];
        if (name is! String ||
            name.isEmpty ||
            style == null ||
            stack is! int ||
            stack < 0) {
          return null;
        }
        opponents.add(HoldemOpponent(name: name, style: style, stack: stack));
      }
      HoldemHand? hand;
      var stake = 0;
      final rawHand = json['hand'];
      if (rawHand != null) {
        final rawStake = json['playerStake'];
        if (rawHand is! Map<String, dynamic> || rawStake is! int) return null;
        hand = HoldemHand.fromJson(rawHand);
        if (hand == null ||
            hand.seatCount != opponents.length + 1 ||
            hand.button != button ||
            rawStake <= 0 ||
            hand.seats[0].stack + hand.seats[0].committed != rawStake) {
          return null;
        }
        stake = rawStake;
      }
      return HoldemTable._(
        difficulty: difficulty,
        opponents: List.unmodifiable(opponents),
        button: button,
        hand: hand,
        playerStake: stake,
        handsDealt: handsDealt,
      );
    } on TypeError {
      return null;
    }
  }
}

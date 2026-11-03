import 'package:kurts_free_casino_games/core/audio/kfg_tone_player.dart';
import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/core/cards/playing_card.dart';
import 'package:kurts_free_casino_games/core/services/persistent_storage.dart';
import 'package:kurts_free_casino_games/features/games/texas_holdem/logic/holdem_hand.dart';

/// Parses a card such as `AS`, `10H` or `2d`.
PlayingCard card(String text) {
  final t = text.toUpperCase();
  final suit = CardSuit.values.firstWhere((s) => s.symbol == t[t.length - 1]);
  final rankText = t.substring(0, t.length - 1);
  final rank = CardRank.values.firstWhere((r) => r.label == rankText);
  return PlayingCard(
    id: '${suit.symbol}${rank.value.toString().padLeft(2, '0')}',
    suit: suit,
    rank: rank,
    faceUp: true,
  );
}

/// Parses a space-separated list of cards.
List<PlayingCard> cards(String text) =>
    text.split(' ').where((t) => t.isNotEmpty).map(card).toList();

/// A full deck whose top cards are [top] in order, the rest in factory
/// order.
List<PlayingCard> stackedDeck(List<PlayingCard> top) {
  final rest = const CardDeckFactory().createOrderedDeck();
  for (final c in top) {
    final i = rest.indexWhere((r) => r.id == c.id);
    if (i < 0) throw ArgumentError('${c.id} used twice');
    rest.removeAt(i);
  }
  return [...top.map((c) => c.copyWith(faceUp: false)), ...rest];
}

/// A deck that deals [holes] (one string of two cards per seat, seat 0
/// first) with the button at [button], then [board] as the flop, turn and
/// river.
List<PlayingCard> deckFor({
  required List<String> holes,
  required int button,
  String board = '',
}) {
  final n = holes.length;
  final parsed = [for (final h in holes) cards(h)];
  final top = <PlayingCard>[
    for (var round = 0; round < 2; round++)
      for (var i = 1; i <= n; i++) parsed[(button + i) % n][round],
    ...cards(board),
  ];
  return stackedDeck(top);
}

/// Deals a hand with known cards.
HoldemHand dealHand({
  required List<int> stacks,
  required List<String> holes,
  int button = 0,
  String board = '',
}) {
  return HoldemHand.deal(
    stacks: stacks,
    button: button,
    deck: deckFor(holes: holes, button: button, board: board),
    smallBlind: 5,
    bigBlind: 10,
  );
}

const call = HoldemDecision.checkOrCall();
const fold = HoldemDecision.fold();
HoldemDecision raiseTo(int amount) => HoldemDecision.raiseTo(amount);

/// Plays [decisions] in order from whoever is to act.
HoldemHand play(HoldemHand hand, List<HoldemDecision> decisions) {
  var h = hand;
  for (final d in decisions) {
    h = h.act(d);
  }
  return h;
}

/// Calls or checks until the hand is complete.
HoldemHand checkDown(HoldemHand hand) {
  var h = hand;
  while (h.isInPlay) {
    h = h.act(call);
  }
  return h;
}

/// Every chip at the table: stacks plus what's in the pot.
int chipsOf(HoldemHand hand) => hand.isComplete
    ? hand.seats.fold(0, (sum, s) => sum + s.stack)
    : hand.seats.fold(0, (sum, s) => sum + s.stack + s.committed);

class SilentTonePlayer extends KfgTonePlayer {
  SilentTonePlayer();

  @override
  Future<void> playFrequency(double frequencyHz) async {}

  @override
  void dispose() {}
}

class MemoryPersistentStorage implements PersistentStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();
}

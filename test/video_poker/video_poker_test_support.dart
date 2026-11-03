import 'package:kurts_free_casino_games/core/audio/kfg_tone_player.dart';
import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/core/cards/playing_card.dart';
import 'package:kurts_free_casino_games/core/services/persistent_storage.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_variant.dart';

/// Parses a card such as `AS`, `10H`, `2d` or `JK` (a joker).
PlayingCard card(String text) {
  final t = text.toUpperCase();
  if (t == 'JK') return const PlayingCard.joker(id: 'J01', faceUp: true);
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

/// A full [variant] deck whose top cards are [top] (the deal first, then
/// the draw order), the rest in factory order.
List<PlayingCard> stackedDeck(VideoPokerVariant variant, String top) {
  final first = cards(top);
  final ids = first.map((c) => c.id).toSet();
  return [
    ...first.map((c) => c.copyWith(faceUp: false)),
    ...const CardDeckFactory()
        .createOrderedDeck(jokers: variant.jokers)
        .where((c) => !ids.contains(c.id)),
  ];
}

/// Deals the queued deck tops in order, then a losing hand forever.
class ScriptedShuffler {
  ScriptedShuffler([List<String> decks = const []]) : _decks = List.of(decks);

  final List<String> _decks;
  int dealt = 0;

  void queue(String top) => _decks.add(top);

  List<PlayingCard> call(VideoPokerVariant variant) {
    dealt++;
    final top = _decks.isEmpty
        ? '3C 8D 5H JS 9C 4D 6H 10C QH KD'
        : _decks.removeAt(0);
    return stackedDeck(variant, top);
  }
}

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

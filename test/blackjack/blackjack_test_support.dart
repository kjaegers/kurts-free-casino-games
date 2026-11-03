import 'package:kurts_free_casino_games/core/audio/kfg_tone_player.dart';
import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/core/cards/playing_card.dart';
import 'package:kurts_free_casino_games/core/services/persistent_storage.dart';
import 'package:kurts_free_casino_games/features/games/blackjack/logic/blackjack_game.dart';

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

/// A full six-deck shoe whose top cards are [top] in dealing order (player,
/// dealer up, player, dealer hole, then hits), the rest in factory order.
List<PlayingCard> stackedShoe(String top) {
  final rest = [
    for (var d = 0; d < blackjackDecks; d++)
      ...const CardDeckFactory().createOrderedDeck(),
  ];
  final first = cards(top);
  for (final c in first) {
    final i = rest.indexWhere((r) => r.id == c.id);
    if (i < 0) throw ArgumentError('More than six of ${c.id}');
    rest.removeAt(i);
  }
  return [...first.map((c) => c.copyWith(faceUp: false)), ...rest];
}

/// A round dealt from a shoe stacked with [top], at [bet].
BlackjackGame dealt(String top, {int bet = 10}) =>
    BlackjackGame.newSession(bet: bet).deal(shuffledShoe: stackedShoe(top));

/// Shuffles the queued shoe tops in order, then factory-ordered shoes.
class ScriptedShoe {
  ScriptedShoe([List<String> tops = const []]) : _tops = List.of(tops);

  final List<String> _tops;
  int shuffles = 0;

  void queue(String top) => _tops.add(top);

  List<PlayingCard> call() {
    shuffles++;
    return stackedShoe(_tops.isEmpty ? '' : _tops.removeAt(0));
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

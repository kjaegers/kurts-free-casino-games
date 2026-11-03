import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/cards/card_deck_factory.dart';
import 'package:kurts_free_casino_games/core/cards/playing_card.dart';
import 'package:kurts_free_casino_games/core/cards/playing_card_codec.dart';

void main() {
  group('CardDeckFactory', () {
    test('deck has 52 unique cards, all face down', () {
      final deck = const CardDeckFactory().createOrderedDeck();

      expect(deck.length, 52);
      expect(deck.map((card) => card.id).toSet().length, 52);
      expect(deck.every((card) => !card.faceUp), isTrue);
    });

    test('jokers are only added when asked for', () {
      final plain = const CardDeckFactory().createShuffledDeck(seed: 3);
      expect(plain.where((c) => c.isJoker), isEmpty);

      final deck = const CardDeckFactory().createOrderedDeck(jokers: 2);
      expect(deck.length, 54);
      expect(deck.map((card) => card.id).toSet().length, 54);
      expect(deck.where((c) => c.isJoker).map((c) => c.id), ['J01', 'J02']);
    });

    test('seeded shuffle is deterministic', () {
      final first = const CardDeckFactory().createShuffledDeck(seed: 12345);
      final second = const CardDeckFactory().createShuffledDeck(seed: 12345);

      expect(first.map((c) => c.id), second.map((c) => c.id));
    });
  });

  group('playing card codec', () {
    test('round-trips a pile, keeping face-up state', () {
      final deck = const CardDeckFactory().createShuffledDeck(seed: 7);
      final pile = [
        for (var i = 0; i < deck.length; i++)
          deck[i].copyWith(faceUp: i.isEven),
      ];

      expect(decodeCardPile(encodeCardPile(pile)), pile);
    });

    test('encodes face-up upper case and face-down lower case', () {
      const cards = [
        PlayingCard(
          id: 'H01',
          suit: CardSuit.hearts,
          rank: CardRank.ace,
          faceUp: true,
        ),
        PlayingCard(
          id: 'S12',
          suit: CardSuit.spades,
          rank: CardRank.queen,
          faceUp: false,
        ),
      ];

      expect(encodeCardPile(cards), 'H01s12');
    });

    test('round-trips jokers', () {
      final pile = [
        const PlayingCard.joker(id: 'J01', faceUp: true),
        const PlayingCard.joker(id: 'J02'),
        const PlayingCard(
          id: 'D10',
          suit: CardSuit.diamonds,
          rank: CardRank.ten,
          faceUp: true,
        ),
      ];

      expect(encodeCardPile(pile), 'J01j02D10');
      expect(decodeCardPile('J01j02D10'), pile);
    });

    test('rejects malformed input', () {
      expect(() => decodeCardPile('H0'), throwsFormatException);
      expect(() => decodeCardPile('X01'), throwsFormatException);
      expect(() => decodeCardPile('H14'), throwsFormatException);
      expect(() => decodeCardPile('Jxx'), throwsFormatException);
    });
  });

  group('joker', () {
    test('has no suit, rank or colour and stays a joker', () {
      const joker = PlayingCard.joker(id: 'J01');

      expect(joker.isJoker, isTrue);
      expect(joker.faceUpLabel, 'Joker');
      expect(joker.isAce, isFalse);
      expect(() => joker.suit, throwsStateError);
      expect(() => joker.rank, throwsStateError);
      expect(() => joker.color, throwsStateError);
      final flipped = joker.copyWith(faceUp: true);
      expect(flipped.isJoker, isTrue);
      expect(flipped.faceUp, isTrue);
    });

    test('is not equal to a real card', () {
      const joker = PlayingCard.joker(id: 'S01', faceUp: true);
      const ace = PlayingCard(
        id: 'S01',
        suit: CardSuit.spades,
        rank: CardRank.ace,
        faceUp: true,
      );
      expect(joker == ace, isFalse);
    });
  });
}

import 'playing_card.dart';

/// Compact text encoding for a pile of playing cards, shared by the
/// solitaire save files.
///
/// Each card is a three-character token: the suit letter (upper case face
/// up, lower case face down) and the two-digit rank, e.g. `H01` is a face-up
/// Ace of Hearts and `s12` a face-down Queen of Spades. A joker is `J`
/// (or `j`) and its two-digit number from a `CardDeckFactory` id, e.g. `J01`.
String encodeCardPile(Iterable<PlayingCard> pile) {
  final buffer = StringBuffer();
  for (final card in pile) {
    if (card.isJoker) {
      final number = int.tryParse(card.id.substring(1)) ?? 0;
      buffer
        ..write(card.faceUp ? 'J' : 'j')
        ..write(number.clamp(0, 99).toString().padLeft(2, '0'));
      continue;
    }
    final letter = card.suit.symbol;
    buffer
      ..write(card.faceUp ? letter : letter.toLowerCase())
      ..write(card.rank.value.toString().padLeft(2, '0'));
  }
  return buffer.toString();
}

/// Decodes a pile written by [encodeCardPile]. Throws [FormatException] on
/// malformed input.
List<PlayingCard> decodeCardPile(String encoded) {
  if (encoded.length % 3 != 0) {
    throw const FormatException('Malformed card pile');
  }
  final cards = <PlayingCard>[];
  for (var i = 0; i < encoded.length; i += 3) {
    final letter = encoded[i];
    final upper = letter.toUpperCase();
    if (upper == 'J') {
      final digits = encoded.substring(i + 1, i + 3);
      if (int.tryParse(digits) == null) {
        throw FormatException('Unknown joker $digits');
      }
      cards.add(PlayingCard.joker(id: 'J$digits', faceUp: letter == 'J'));
      continue;
    }
    final suit = CardSuit.values.firstWhere(
      (s) => s.symbol == upper,
      orElse: () => throw FormatException('Unknown suit $letter'),
    );
    final rankValue = int.parse(encoded.substring(i + 1, i + 3));
    final rank = CardRank.values.firstWhere(
      (r) => r.value == rankValue,
      orElse: () => throw FormatException('Unknown rank $rankValue'),
    );
    cards.add(
      PlayingCard(
        id: '$upper${encoded.substring(i + 1, i + 3)}',
        suit: suit,
        rank: rank,
        faceUp: letter == upper,
      ),
    );
  }
  return cards;
}

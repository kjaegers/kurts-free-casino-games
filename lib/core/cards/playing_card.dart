enum CardColor { red, black }

enum CardSuit {
  hearts,
  diamonds,
  clubs,
  spades;

  CardColor get color {
    return switch (this) {
      CardSuit.hearts || CardSuit.diamonds => CardColor.red,
      CardSuit.clubs || CardSuit.spades => CardColor.black,
    };
  }

  String get symbol {
    return switch (this) {
      CardSuit.hearts => 'H',
      CardSuit.diamonds => 'D',
      CardSuit.clubs => 'C',
      CardSuit.spades => 'S',
    };
  }

  String get displayName {
    return switch (this) {
      CardSuit.hearts => 'Hearts',
      CardSuit.diamonds => 'Diamonds',
      CardSuit.clubs => 'Clubs',
      CardSuit.spades => 'Spades',
    };
  }
}

enum CardRank {
  ace(1, 'A'),
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K');

  const CardRank(this.value, this.label);

  final int value;
  final String label;

  String get displayName {
    return switch (this) {
      CardRank.ace => 'Ace',
      CardRank.two => 'Two',
      CardRank.three => 'Three',
      CardRank.four => 'Four',
      CardRank.five => 'Five',
      CardRank.six => 'Six',
      CardRank.seven => 'Seven',
      CardRank.eight => 'Eight',
      CardRank.nine => 'Nine',
      CardRank.ten => 'Ten',
      CardRank.jack => 'Jack',
      CardRank.queen => 'Queen',
      CardRank.king => 'King',
    };
  }
}

/// One playing card, or a joker.
///
/// Jokers exist only in decks that ask for them
/// (`CardDeckFactory.createOrderedDeck(jokers: n)`). A joker has no suit or
/// rank: reading [suit], [rank] or [color] on one throws, so code that
/// forgets to check [isJoker] fails loudly instead of treating it as a
/// real card.
class PlayingCard {
  // The fields are private and nullable (null = joker) while the public
  // parameters stay non-null, so initializing formals can't be used.
  const PlayingCard({
    required this.id,
    required CardSuit suit,
    required CardRank rank,
    required this.faceUp,
  }) : _suit = suit, // ignore: prefer_initializing_formals
       _rank = rank; // ignore: prefer_initializing_formals

  const PlayingCard.joker({required this.id, this.faceUp = false})
    : _suit = null,
      _rank = null;

  final String id;
  final CardSuit? _suit;
  final CardRank? _rank;
  final bool faceUp;

  bool get isJoker => _suit == null;

  CardSuit get suit => _suit ?? (throw StateError('A joker has no suit'));
  CardRank get rank => _rank ?? (throw StateError('A joker has no rank'));

  CardColor get color => suit.color;
  bool get isAce => _rank == CardRank.ace;
  bool get isKing => _rank == CardRank.king;
  String get faceUpLabel =>
      isJoker ? 'Joker' : '${rank.displayName} of ${suit.displayName}';

  /// A joker stays a joker: only [id] and [faceUp] can change on one.
  PlayingCard copyWith({
    String? id,
    CardSuit? suit,
    CardRank? rank,
    bool? faceUp,
  }) {
    if (isJoker) {
      assert(suit == null && rank == null, 'A joker has no suit or rank');
      return PlayingCard.joker(
        id: id ?? this.id,
        faceUp: faceUp ?? this.faceUp,
      );
    }
    return PlayingCard(
      id: id ?? this.id,
      suit: suit ?? this.suit,
      rank: rank ?? this.rank,
      faceUp: faceUp ?? this.faceUp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayingCard &&
        other.id == id &&
        other._suit == _suit &&
        other._rank == _rank &&
        other.faceUp == faceUp;
  }

  @override
  int get hashCode => Object.hash(id, _suit, _rank, faceUp);

  @override
  String toString() {
    if (isJoker) return 'PlayingCard.joker(id: $id, faceUp: $faceUp)';
    return 'PlayingCard(id: $id, suit: $suit, rank: $rank, faceUp: $faceUp)';
  }
}

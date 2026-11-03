/// Categories used to group games in the registry and home screen filter.
enum GameCategory {
  card,
  table,
  dice,
  slots;

  String get displayName {
    return switch (this) {
      GameCategory.card => 'Card',
      GameCategory.table => 'Table',
      GameCategory.dice => 'Dice',
      GameCategory.slots => 'Slots',
    };
  }
}

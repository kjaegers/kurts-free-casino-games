enum CardDragMode {
  immediate,
  longPress;

  String get label {
    return switch (this) {
      CardDragMode.immediate => 'Immediate Drag',
      CardDragMode.longPress => 'Long-Press Drag',
    };
  }
}

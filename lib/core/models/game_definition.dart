import 'package:flutter/material.dart';

import 'game_category.dart';

/// Whether a game is fully implemented, a stub, or not yet started.
enum GameStatus {
  comingSoon,
  playableStub,
  prototype;

  String get label {
    return switch (this) {
      GameStatus.comingSoon => 'Coming Soon',
      GameStatus.playableStub => 'Playable Stub',
      GameStatus.prototype => 'Prototype',
    };
  }
}

/// Ids of registered games that are finished and playable. A game shows as
/// READY on the home screen only when it is listed here.
const Set<String> kReadyPlayableGameIds = <String>{
  'video_poker',
  'slots_cherry_run',
  'slots_retro_tech',
  'blackjack',
  'roulette',
  'texas_holdem',
};

/// Describes a single game entry in the game registry.
class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.routeName,
    required this.icon,
    this.iconBuilder,
    this.tags = const [],
    this.showInMenu = true,
  });

  final String id;
  final String title;
  final String description;
  final GameCategory category;
  final GameStatus status;

  /// Named route used to navigate to this game's screen.
  final String routeName;

  final IconData icon;

  /// Paints a custom menu icon (in the given colour and size) in place of
  /// [icon], for glyphs Material Icons lacks. [icon] stays as the fallback.
  final Widget Function(Color color, double size)? iconBuilder;

  final List<String> tags;

  /// Whether this game should be shown in the main game-selection menu.
  ///
  /// Hidden games remain registered and routable for internal use/testing.
  final bool showInMenu;

  bool get isReady =>
      status == GameStatus.playableStub && kReadyPlayableGameIds.contains(id);
}

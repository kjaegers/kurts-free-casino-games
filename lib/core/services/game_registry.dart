import 'package:flutter/material.dart';

import '../models/game_category.dart';
import '../models/game_definition.dart';
import '../widgets/kfg_game_icon.dart';

/// Central registry of all games available in the app.
///
/// Add a new game by appending a [GameDefinition] to [_games].
/// The home screen rebuilds itself from this list automatically.
class GameRegistry {
  GameRegistry._();

  static final GameRegistry instance = GameRegistry._();

  List<GameDefinition> get games => _games;

  List<GameDefinition> get visibleGames =>
      _games.where((g) => g.showInMenu).toList();

  List<GameDefinition> getByCategory(GameCategory category) =>
      _games.where((g) => g.category == category).toList();
}

const List<GameDefinition> _games = [
  GameDefinition(
    id: 'video_poker',
    title: 'Video Poker',
    description:
        'Five-card draw against a paytable: Joker Poker, Jacks or Better '
        'and Deuces Wild.',
    category: GameCategory.card,
    status: GameStatus.playableStub,
    routeName: '/game/video-poker',
    icon: Icons.style,
    tags: ['poker', 'cards', 'draw'],
  ),
  GameDefinition(
    id: 'slots_cherry_run',
    title: 'Slots: Cherry Run',
    description:
        'A classic three-reel, three-line slot machine with cherries, bells, '
        'bars and sevens.',
    category: GameCategory.slots,
    status: GameStatus.playableStub,
    routeName: '/game/slots-cherry-run',
    icon: Icons.casino,
    iconBuilder: kfgCherryIcon,
    tags: ['slots', 'reels', 'classic'],
  ),
  GameDefinition(
    id: 'slots_retro_tech',
    title: 'Slots: Retro Tech',
    description:
        'A cascading 5 × 5 slot machine of floppies, joysticks and arcade '
        'tokens: clusters pay, vanish and make room for more.',
    category: GameCategory.slots,
    status: GameStatus.playableStub,
    routeName: '/game/slots-retro-tech',
    icon: Icons.videogame_asset,
    tags: ['slots', 'cascade', 'clusters', 'retro'],
  ),
  GameDefinition(
    id: 'blackjack',
    title: 'Blackjack',
    description:
        'Beat the dealer to 21 from a six-deck shoe: double, split, '
        'surrender and blackjack pays 3:2.',
    category: GameCategory.table,
    status: GameStatus.playableStub,
    routeName: '/game/blackjack',
    icon: Icons.layers,
    tags: ['blackjack', 'cards', '21'],
  ),
  GameDefinition(
    id: 'roulette',
    title: 'Roulette',
    description:
        'Single-zero roulette: bet on numbers, splits, corners, dozens, red '
        'or black, and watch the ball drop.',
    category: GameCategory.table,
    status: GameStatus.playableStub,
    routeName: '/game/roulette',
    icon: Icons.album,
    tags: ['roulette', 'wheel', 'table'],
  ),
  GameDefinition(
    id: 'texas_holdem',
    title: "Texas Hold'em",
    description:
        "No-limit Texas Hold'em against one to five computer opponents, "
        'from easy to hard.',
    category: GameCategory.card,
    status: GameStatus.playableStub,
    routeName: '/game/texas-holdem',
    icon: Icons.groups,
    tags: ['poker', 'cards', 'holdem'],
  ),
];

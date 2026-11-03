import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import '../../core/models/game_category.dart';
import '../../core/models/game_definition.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/game_registry.dart';
import '../../core/widgets/kfg_credits_badge.dart';
import 'widgets/game_card.dart';
import 'widgets/game_category_filter.dart';

/// The main game-selection screen shown on the Home tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameCategory? _selectedCategory;

  final FavoritesService _favorites = FavoritesService.instance;

  @override
  void initState() {
    super.initState();
    _favorites.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _favorites.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() => setState(() {});

  List<GameDefinition> get _filteredGames {
    final all = GameRegistry.instance.visibleGames;
    final filtered = _selectedCategory == null
        ? all.toList()
        : all.where((g) => g.category == _selectedCategory).toList();

    return sortMenuGames(filtered, _favorites.favoriteIds);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGames;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Header()),
        SliverToBoxAdapter(
          child: GameCategoryFilter(
            selectedCategory: _selectedCategory,
            onCategorySelected: (cat) =>
                setState(() => _selectedCategory = cat),
          ),
        ),
        filtered.isEmpty
            ? const SliverFillRemaining(child: _EmptyState())
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final game = filtered[index];
                    return GameCard(
                      key: ValueKey(game.id),
                      game: game,
                      isFavorite: _favorites.isFavorite(game.id),
                      onToggleFavorite: () => _favorites.toggle(game.id),
                    );
                  }, childCount: filtered.length),
                ),
              ),
      ],
    );
  }
}

/// Orders games for the home menu: favorites first, then ready games, then by
/// status, with an alphabetical sub-sort by title within each group.
List<GameDefinition> sortMenuGames(
  Iterable<GameDefinition> games,
  Set<String> favoriteIds,
) {
  return games.toList()..sort((a, b) {
    final favoriteOrder = (favoriteIds.contains(a.id) ? 0 : 1).compareTo(
      favoriteIds.contains(b.id) ? 0 : 1,
    );
    if (favoriteOrder != 0) return favoriteOrder;

    final readyOrder = (a.isReady ? 0 : 1).compareTo(b.isReady ? 0 : 1);
    if (readyOrder != 0) return readyOrder;

    final statusOrder = a.status.index.compareTo(b.status.index);
    if (statusOrder != 0) return statusOrder;

    return a.title.compareTo(b.title);
  });
}

class _Header extends StatelessWidget {
  // ignore: unused_element
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "KURT'S FREE CASINO GAMES",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: KfgColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Play for fun. Offline. No ads. No nonsense.',
            style: TextStyle(
              color: KfgColors.textMuted,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          const KfgCreditsBadge(large: true),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videogame_asset_off, color: KfgColors.textMuted, size: 48),
          SizedBox(height: 12),
          Text(
            'No games in this category yet.',
            style: TextStyle(color: KfgColors.textMuted),
          ),
        ],
      ),
    );
  }
}

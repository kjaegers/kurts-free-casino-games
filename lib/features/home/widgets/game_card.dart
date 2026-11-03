import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/models/game_category.dart';
import '../../../../core/models/game_definition.dart';
import '../../../../core/widgets/kfg_game_icon.dart';
import '../../../../core/widgets/kfg_neon_card.dart';

/// A card displayed in the home-screen game grid for a single game.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  final GameDefinition game;
  final bool isFavorite;

  /// Called when the player taps the favorite star. The star is hidden when
  /// this is null.
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return KfgNeonCard(
      onTap: () => Navigator.of(context).pushNamed(game.routeName),
      padding: const EdgeInsets.all(12),
      borderColor: isFavorite
          ? KfgColors.warning.withValues(alpha: 0.7)
          : KfgColors.cardBorder,
      glowColor: game.status == GameStatus.playableStub
          ? KfgColors.primary
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KfgGameIcon(game: game, color: _iconColor(), size: 26),
              // Scales down rather than overflowing narrow cards with
              // Large Text.
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _StatusChip(
                      status: game.status,
                      isReady: game.isReady,
                    ),
                  ),
                ),
              ),
              if (onToggleFavorite != null)
                _FavoriteButton(
                  isFavorite: isFavorite,
                  gameTitle: game.title,
                  onPressed: onToggleFavorite!,
                ),
            ],
          ),
          SizedBox(height: onToggleFavorite != null ? 4 : 10),
          Text(
            game.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: KfgColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              game.description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          _CategoryChip(category: game.category),
        ],
      ),
    );
  }

  Color _iconColor() => switch (game.category) {
    GameCategory.card => KfgColors.highlight,
    GameCategory.table => KfgColors.primary,
    GameCategory.dice => KfgColors.warning,
    GameCategory.slots => KfgColors.secondary,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isReady});

  final GameStatus status;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      GameStatus.comingSoon => (KfgColors.textMuted, 'SOON'),
      // Every playable game is still in beta.
      GameStatus.playableStub =>
        isReady ? (KfgColors.warning, 'IN BETA') : (KfgColors.primary, 'STUB'),
      GameStatus.prototype => (KfgColors.highlight, 'PROTO'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.gameTitle,
    required this.onPressed,
  });

  final bool isFavorite;
  final String gameTitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: isFavorite
          ? 'Remove $gameTitle from favorites'
          : 'Add $gameTitle to favorites',
      icon: Icon(
        isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
        color: isFavorite ? KfgColors.warning : KfgColors.textMuted,
      ),
      iconSize: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final GameCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        color: KfgColors.surfaceVariant,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        category.displayName.toUpperCase(),
        style: const TextStyle(
          color: KfgColors.textMuted,
          fontSize: 9,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/models/game_category.dart';

/// Horizontal scrolling filter chips for selecting a game category.
///
/// Pass [selectedCategory] as null to show all games.
class GameCategoryFilter extends StatelessWidget {
  const GameCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final GameCategory? selectedCategory;
  final ValueChanged<GameCategory?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: selectedCategory == null,
            onSelected: () => onCategorySelected(null),
          ),
          const SizedBox(width: 6),
          ...GameCategory.values.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: cat.displayName,
                selected: selectedCategory == cat,
                onSelected: () =>
                    onCategorySelected(selectedCategory == cat ? null : cat),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? KfgColors.primary.withValues(alpha: 0.15)
              : KfgColors.surfaceVariant,
          border: Border.all(
            color: selected ? KfgColors.primary : KfgColors.cardBorder,
            width: selected ? 1.0 : 0.5,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? KfgColors.primary : KfgColors.textMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

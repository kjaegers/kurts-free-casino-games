import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import '../models/achievement.dart';

/// The **Achievements Unlocked** block in a result dialog: every
/// achievement first unlocked by the game that just ended.
class KfgAchievementsUnlocked extends StatelessWidget {
  const KfgAchievementsUnlocked({super.key, required this.achievements});

  final List<AchievementDefinition> achievements;

  static const String heading = 'ACHIEVEMENTS UNLOCKED';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KfgColors.highlight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KfgColors.highlight.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: const Text(
              heading,
              style: TextStyle(
                color: KfgColors.highlight,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                fontSize: 13,
              ),
            ),
          ),
          for (final a in achievements)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.military_tech,
                        size: 18,
                        color: KfgColors.highlight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: const TextStyle(
                              color: KfgColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            a.description,
                            style: const TextStyle(
                              color: KfgColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

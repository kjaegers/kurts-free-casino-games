import 'package:flutter/foundation.dart';

/// One achievement in the shared catalog.
///
/// [id] is a persistence key (`<gameId>.<name>`) and must never change once
/// shipped.
@immutable
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.gameId,
    required this.title,
    required this.description,
    this.progressTarget,
  });

  final String id;
  final String gameId;
  final String title;
  final String description;

  /// For cumulative achievements: the progress value that unlocks it
  /// (distinct entries, a stored count, or a game statistic).
  final int? progressTarget;
}

/// What is stored for one achievement on this device.
@immutable
class AchievementState {
  const AchievementState({
    this.unlocked = false,
    this.unlockedAt,
    this.progress = const {},
    this.count = 0,
  });

  final bool unlocked;

  /// When it was unlocked; null when locked or not known.
  final DateTime? unlockedAt;

  /// Distinct progress entries for cumulative achievements (e.g. map IDs).
  final Set<String> progress;

  /// A running number kept for an achievement (e.g. a win streak).
  final int count;

  static const AchievementState locked = AchievementState();

  AchievementState copyWith({
    bool? unlocked,
    DateTime? unlockedAt,
    Set<String>? progress,
    int? count,
  }) {
    return AchievementState(
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      count: count ?? this.count,
    );
  }
}

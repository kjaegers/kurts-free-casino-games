/// Records the outcome of a completed game session.
///
/// Games report results to [StatsService] via [StatsService.recordResult] or
/// [StatsService.recordGameFinished].
class GameResult {
  const GameResult({
    required this.gameId,
    required this.playedAt,
    required this.won,
    this.durationSeconds,
    this.score,
    this.metadata = const {},
    this.hasOutcome = true,
  });

  final String gameId;
  final DateTime playedAt;

  /// Whether the game was won. Meaningless when [hasOutcome] is false.
  final bool won;

  /// False for endless / score-attack runs, which end without a win or loss.
  final bool hasOutcome;
  final int? durationSeconds;
  final int? score;

  /// Game-specific extras (e.g. difficulty, board seed).
  final Map<String, dynamic> metadata;
}

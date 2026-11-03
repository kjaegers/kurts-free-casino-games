import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import '../../core/achievements/achievement_catalog.dart';
import '../../core/models/achievement.dart';
import '../../core/models/blackjack_stats.dart';
import '../../core/models/roulette_stats.dart';
import '../../core/models/slots_cherry_run_stats.dart';
import '../../core/models/slots_retro_tech_stats.dart';
import '../../core/models/texas_holdem_stats.dart';
import '../../core/models/video_poker_stats.dart';
import '../../core/services/credits_service.dart';
import '../../core/services/game_registry.dart';
import '../../core/services/stats_service.dart';
import '../../core/widgets/kfg_game_icon.dart';
import '../../core/widgets/kfg_neon_card.dart';
import '../../core/widgets/kfg_section_header.dart';

/// Stats screen shown on the Stats tab.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StatsService.instance,
      builder: (context, _) => _StatsContent(),
    );
  }
}

class _StatsContent extends StatefulWidget {
  const _StatsContent();

  @override
  State<_StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends State<_StatsContent> {
  String? _expandedGameId;

  void _toggleGame(String gameId) {
    setState(() {
      _expandedGameId = _expandedGameId == gameId ? null : gameId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = StatsService.instance.stats;
    final registry = GameRegistry.instance;

    final favoriteTitle = stats.favoriteGameId != null
        ? registry.games
              .where((g) => g.id == stats.favoriteGameId)
              .map((g) => g.title)
              .firstOrNull
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageTitle(),
          const SizedBox(height: 20),

          // ── Overview ───────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Overview'),
          const SizedBox(height: 10),
          _StatGrid(
            items: [
              _StatItem(
                label: 'Games Played',
                value: '${stats.totalGamesPlayed}',
                icon: Icons.videogame_asset,
              ),
              _StatItem(
                label: 'Games Won',
                value: '${stats.totalGamesWon}',
                icon: Icons.emoji_events,
                color: KfgColors.highlight,
              ),
              _StatItem(
                label: 'Win Rate',
                value: stats.totalGamesDecided == 0
                    ? '—'
                    : '${(stats.winRate * 100).round()}%',
                icon: Icons.percent,
                color: KfgColors.secondary,
              ),
              _StatItem(
                label: 'Time Played',
                value: stats.totalSecondsPlayed == 0
                    ? '—'
                    : stats.formattedTimePlayed,
                icon: Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Streaks ────────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Streaks'),
          const SizedBox(height: 10),
          _StatGrid(
            items: [
              _StatItem(
                label: 'Current Streak',
                value: '${stats.currentStreak}',
                icon: Icons.local_fire_department,
                color: KfgColors.warning,
              ),
              _StatItem(
                label: 'Best Streak',
                value: '${stats.bestStreak}',
                icon: Icons.military_tech,
                color: KfgColors.highlight,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Per-game stats (collapsible, one open at a time) ────────────
          // One per game, alphabetical, each followed by SizedBox(height: 10).
          const KfgSectionHeader(title: 'Games'),
          const SizedBox(height: 10),
          _GameStatsSection(
            gameId: 'blackjack',
            title: 'Blackjack',
            expanded: _expandedGameId == 'blackjack',
            onToggle: () => _toggleGame('blackjack'),
            child: _WithAchievements(
              gameId: 'blackjack',
              child: _BlackjackStatsSection(
                stats: StatsService.instance.blackjackStats,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GameStatsSection(
            gameId: 'roulette',
            title: 'Roulette',
            expanded: _expandedGameId == 'roulette',
            onToggle: () => _toggleGame('roulette'),
            child: _WithAchievements(
              gameId: 'roulette',
              progress: {
                'roulette.inside_story': StatsService.instance
                    .achievementState('roulette.inside_story')
                    .progress
                    .length,
              },
              child: _RouletteStatsSection(
                stats: StatsService.instance.rouletteStats,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GameStatsSection(
            gameId: 'slots_cherry_run',
            title: 'Slots: Cherry Run',
            expanded: _expandedGameId == 'slots_cherry_run',
            onToggle: () => _toggleGame('slots_cherry_run'),
            child: _WithAchievements(
              gameId: 'slots_cherry_run',
              progress: {
                'slots_cherry_run.fruit_salad': StatsService.instance
                    .achievementState('slots_cherry_run.fruit_salad')
                    .progress
                    .length,
              },
              child: _CherryRunStatsSection(
                stats: StatsService.instance.cherryRunStats,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GameStatsSection(
            gameId: 'slots_retro_tech',
            title: 'Slots: Retro Tech',
            expanded: _expandedGameId == 'slots_retro_tech',
            onToggle: () => _toggleGame('slots_retro_tech'),
            child: _WithAchievements(
              gameId: 'slots_retro_tech',
              progress: {
                'slots_retro_tech.full_collection': StatsService.instance
                    .achievementState('slots_retro_tech.full_collection')
                    .progress
                    .length,
              },
              child: _RetroTechStatsSection(
                stats: StatsService.instance.retroTechStats,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GameStatsSection(
            gameId: 'texas_holdem',
            title: "Texas Hold'em",
            expanded: _expandedGameId == 'texas_holdem',
            onToggle: () => _toggleGame('texas_holdem'),
            child: _WithAchievements(
              gameId: 'texas_holdem',
              progress: {
                'texas_holdem.every_difficulty': StatsService.instance
                    .achievementState('texas_holdem.every_difficulty')
                    .progress
                    .length,
              },
              child: _TexasHoldemStatsSection(
                stats: StatsService.instance.texasHoldemStats,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GameStatsSection(
            gameId: 'video_poker',
            title: 'Video Poker',
            expanded: _expandedGameId == 'video_poker',
            onToggle: () => _toggleGame('video_poker'),
            child: _WithAchievements(
              gameId: 'video_poker',
              progress: {
                'video_poker.every_variant': StatsService.instance
                    .achievementState('video_poker.every_variant')
                    .progress
                    .length,
              },
              child: _VideoPokerStatsSection(
                stats: StatsService.instance.videoPokerStats,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Most played ────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Most Played'),
          const SizedBox(height: 10),
          KfgNeonCard(
            child: Row(
              children: [
                const Icon(
                  Icons.favorite,
                  color: KfgColors.secondary,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    favoriteTitle ?? 'Play some games first!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: favoriteTitle != null
                          ? KfgColors.textPrimary
                          : KfgColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Recently played ────────────────────────────────────────────
          const KfgSectionHeader(title: 'Recently Played'),
          const SizedBox(height: 10),
          stats.recentGames.isEmpty
              ? KfgNeonCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No games played yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: KfgColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: stats.recentGames.map((result) {
                    final gameTitle = registry.games
                        .where((g) => g.id == result.gameId)
                        .map((g) => g.title)
                        .firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: KfgNeonCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              !result.hasOutcome
                                  ? Icons.flag
                                  : result.won
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: !result.hasOutcome
                                  ? KfgColors.textSecondary
                                  : result.won
                                  ? KfgColors.highlight
                                  : KfgColors.error,
                              size: 18,
                              semanticLabel: !result.hasOutcome
                                  ? 'Finished'
                                  : result.won
                                  ? 'Won'
                                  : 'Lost',
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(gameTitle ?? result.gameId)),
                            Text(
                              _formatDate(result.playedAt),
                              style: const TextStyle(
                                color: KfgColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'STATISTICS',
      style: TextStyle(
        color: KfgColors.primary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 3,
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color = KfgColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return KfgNeonCard(
      padding: const EdgeInsets.all(12),
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: KfgColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Scales down rather than overflowing the fixed-aspect tile with
          // Large Text or long values.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-game stats ───────────────────────────────────────────────────────────

class _BlackjackStatsSection extends StatelessWidget {
  const _BlackjackStatsSection({required this.stats});

  final BlackjackStats stats;

  @override
  Widget build(BuildContext context) {
    final rounds = stats.rounds;
    final net = stats.net;
    return _StatGrid(
      items: [
        _StatItem(
          label: 'Rounds Played',
          value: formatCredits(rounds),
          icon: Icons.layers,
        ),
        _StatItem(
          label: 'Winning Rounds',
          value: rounds == 0 ? '—' : formatCredits(stats.roundsWon),
          icon: Icons.emoji_events,
          color: KfgColors.highlight,
        ),
        _StatItem(
          label: 'Net Credits',
          value: rounds == 0
              ? '—'
              : '${net > 0 ? '+' : ''}${formatCredits(net)}',
          icon: Icons.toll,
          color: net >= 0 ? KfgColors.warning : KfgColors.error,
        ),
        _StatItem(
          label: 'Biggest Win',
          value: stats.biggestWin == 0 ? '—' : formatCredits(stats.biggestWin),
          icon: Icons.star,
          color: KfgColors.warning,
        ),
        _StatItem(
          label: 'Actual Return',
          value: stats.wagered == 0
              ? '—'
              : '${(stats.paid * 100 / stats.wagered).toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: KfgColors.secondary,
        ),
        _StatItem(
          label: 'Blackjacks',
          value: rounds == 0 ? '—' : formatCredits(stats.blackjacks),
          icon: Icons.workspace_premium,
          color: KfgColors.highlight,
        ),
      ],
    );
  }
}

class _TexasHoldemStatsSection extends StatelessWidget {
  const _TexasHoldemStatsSection({required this.stats});

  final TexasHoldemStats stats;

  @override
  Widget build(BuildContext context) {
    final hands = stats.hands;
    final net = stats.net;
    return _StatGrid(
      items: [
        _StatItem(
          label: 'Hands Played',
          value: formatCredits(hands),
          icon: Icons.groups,
        ),
        _StatItem(
          label: 'Winning Hands',
          value: hands == 0 ? '—' : formatCredits(stats.handsWon),
          icon: Icons.emoji_events,
          color: KfgColors.highlight,
        ),
        _StatItem(
          label: 'Net Credits',
          value: hands == 0
              ? '—'
              : '${net > 0 ? '+' : ''}${formatCredits(net)}',
          icon: Icons.toll,
          color: net >= 0 ? KfgColors.warning : KfgColors.error,
        ),
        _StatItem(
          label: 'Biggest Pot',
          value: stats.biggestPot == 0 ? '—' : formatCredits(stats.biggestPot),
          icon: Icons.star,
          color: KfgColors.warning,
        ),
        _StatItem(
          label: 'Showdowns Won',
          value: stats.showdowns == 0
              ? '—'
              : '${formatCredits(stats.showdownsWon)} / '
                    '${formatCredits(stats.showdowns)}',
          icon: Icons.visibility,
          color: KfgColors.secondary,
        ),
        _StatItem(
          label: 'Best Hand Shown',
          value: stats.bestShowdownLabel ?? '—',
          icon: Icons.workspace_premium,
          color: KfgColors.highlight,
        ),
      ],
    );
  }
}

class _RouletteStatsSection extends StatelessWidget {
  const _RouletteStatsSection({required this.stats});

  final RouletteStats stats;

  @override
  Widget build(BuildContext context) {
    final spins = stats.spins;
    final net = stats.net;
    return _StatGrid(
      items: [
        _StatItem(
          label: 'Spins',
          value: formatCredits(spins),
          icon: Icons.album,
        ),
        _StatItem(
          label: 'Winning Spins',
          value: spins == 0 ? '—' : formatCredits(stats.spinsWon),
          icon: Icons.emoji_events,
          color: KfgColors.highlight,
        ),
        _StatItem(
          label: 'Net Credits',
          value: spins == 0
              ? '—'
              : '${net > 0 ? '+' : ''}${formatCredits(net)}',
          icon: Icons.toll,
          color: net >= 0 ? KfgColors.warning : KfgColors.error,
        ),
        _StatItem(
          label: 'Biggest Win',
          value: stats.biggestWin == 0 ? '—' : formatCredits(stats.biggestWin),
          icon: Icons.star,
          color: KfgColors.warning,
        ),
        _StatItem(
          label: 'Actual Return',
          value: stats.wagered == 0
              ? '—'
              : '${(stats.paid * 100 / stats.wagered).toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: KfgColors.secondary,
        ),
        _StatItem(
          label: 'Straight-Up Wins',
          value: spins == 0 ? '—' : formatCredits(stats.straightWins),
          icon: Icons.gps_fixed,
          color: KfgColors.highlight,
        ),
      ],
    );
  }
}

class _CherryRunStatsSection extends StatelessWidget {
  const _CherryRunStatsSection({required this.stats});

  final CherryRunStats stats;

  @override
  Widget build(BuildContext context) {
    final spins = stats.spins;
    final net = stats.net;
    return _StatGrid(
      items: [
        _StatItem(
          label: 'Spins',
          value: formatCredits(spins),
          icon: Icons.casino,
        ),
        _StatItem(
          label: 'Winning Spins',
          value: spins == 0 ? '—' : formatCredits(stats.spinsWon),
          icon: Icons.emoji_events,
          color: KfgColors.highlight,
        ),
        _StatItem(
          label: 'Net Credits',
          value: spins == 0
              ? '—'
              : '${net > 0 ? '+' : ''}${formatCredits(net)}',
          icon: Icons.toll,
          color: net >= 0 ? KfgColors.warning : KfgColors.error,
        ),
        _StatItem(
          label: 'Biggest Win',
          value: stats.biggestWin == 0 ? '—' : formatCredits(stats.biggestWin),
          icon: Icons.star,
          color: KfgColors.warning,
        ),
        _StatItem(
          label: 'Actual Return',
          value: stats.wagered == 0
              ? '—'
              : '${(stats.paid * 100 / stats.wagered).toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: KfgColors.secondary,
        ),
        _StatItem(
          label: 'Three 7s',
          value: spins == 0 ? '—' : '${stats.countOf('sevens')}',
          icon: Icons.workspace_premium,
          color: KfgColors.highlight,
        ),
      ],
    );
  }
}

class _RetroTechStatsSection extends StatelessWidget {
  const _RetroTechStatsSection({required this.stats});

  final RetroTechStats stats;

  @override
  Widget build(BuildContext context) {
    final spins = stats.spins;
    final net = stats.net;
    return _StatGrid(
      items: [
        _StatItem(
          label: 'Spins',
          value: formatCredits(spins),
          icon: Icons.casino,
        ),
        _StatItem(
          label: 'Winning Spins',
          value: spins == 0 ? '—' : formatCredits(stats.spinsWon),
          icon: Icons.emoji_events,
          color: KfgColors.highlight,
        ),
        _StatItem(
          label: 'Net Credits',
          value: spins == 0
              ? '—'
              : '${net > 0 ? '+' : ''}${formatCredits(net)}',
          icon: Icons.toll,
          color: net >= 0 ? KfgColors.warning : KfgColors.error,
        ),
        _StatItem(
          label: 'Biggest Win',
          value: stats.biggestWin == 0 ? '—' : formatCredits(stats.biggestWin),
          icon: Icons.star,
          color: KfgColors.warning,
        ),
        _StatItem(
          label: 'Actual Return',
          value: stats.wagered == 0
              ? '—'
              : '${(stats.paid * 100 / stats.wagered).toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: KfgColors.secondary,
        ),
        _StatItem(
          label: 'Longest Chain',
          value: stats.longestChain == 0 ? '—' : '${stats.longestChain}',
          icon: Icons.keyboard_double_arrow_down,
          color: KfgColors.highlight,
        ),
      ],
    );
  }
}

class _VideoPokerStatsSection extends StatelessWidget {
  const _VideoPokerStatsSection({required this.stats});

  final VideoPokerStats stats;

  @override
  Widget build(BuildContext context) {
    final hands = stats.hands;
    final net = stats.net;
    return _StatGrid(
      items: [
        _StatItem(label: 'Hands Played', value: '$hands', icon: Icons.style),
        _StatItem(
          label: 'Winning Hands',
          value: hands == 0 ? '—' : formatCredits(stats.handsWon),
          icon: Icons.emoji_events,
          color: KfgColors.highlight,
        ),
        _StatItem(
          label: 'Net Credits',
          value: hands == 0
              ? '—'
              : '${net > 0 ? '+' : ''}${formatCredits(net)}',
          icon: Icons.toll,
          color: net >= 0 ? KfgColors.warning : KfgColors.error,
        ),
        _StatItem(
          label: 'Biggest Win',
          value: stats.biggestWin == 0 ? '—' : formatCredits(stats.biggestWin),
          icon: Icons.star,
          color: KfgColors.warning,
        ),
        _StatItem(
          label: 'Actual Return',
          value: stats.wagered == 0
              ? '—'
              : '${(stats.paid * 100 / stats.wagered).toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: KfgColors.secondary,
        ),
        _StatItem(
          label: 'Royal Flushes',
          value: hands == 0 ? '—' : '${stats.countOf('royalFlush')}',
          icon: Icons.workspace_premium,
          color: KfgColors.highlight,
        ),
      ],
    );
  }
}

// ── Collapsible per-game stats banner ───────────────────────────────────────

/// A tappable banner (game icon + title) that expands to reveal [child] and
/// collapses back down. Only one of these is open at a time — the parent
/// drives [expanded] from a single piece of state so selecting a different
/// game's banner closes whichever one was previously open.
class _GameStatsSection extends StatelessWidget {
  const _GameStatsSection({
    required this.gameId,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String gameId;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final game = GameRegistry.instance.games
        .where((g) => g.id == gameId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KfgNeonCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderColor: expanded ? KfgColors.primary : KfgColors.cardBorder,
          onTap: onToggle,
          child: Row(
            children: [
              if (game != null)
                KfgGameIcon(game: game, color: KfgColors.primary, size: 20)
              else
                const Icon(
                  Icons.videogame_asset,
                  color: KfgColors.primary,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KfgColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.expand_more,
                  color: KfgColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(padding: const EdgeInsets.only(top: 10), child: child)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ── Achievements subsection (shared by games that have achievements) ─────────

/// A game's stats followed by its Achievements subsection.
class _WithAchievements extends StatelessWidget {
  const _WithAchievements({
    required this.gameId,
    required this.child,
    this.progress = const {},
  });

  final String gameId;
  final Widget child;

  /// See [_AchievementsSubsection.progress].
  final Map<String, int> progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        const SizedBox(height: 14),
        _AchievementsSubsection(gameId: gameId, progress: progress),
      ],
    );
  }
}

class _AchievementsSubsection extends StatelessWidget {
  const _AchievementsSubsection({
    required this.gameId,
    this.progress = const {},
  });

  final String gameId;

  /// Progress values for cumulative achievements that aren't counted in
  /// their stored progress entries (a streak count or a game statistic).
  final Map<String, int> progress;

  @override
  Widget build(BuildContext context) {
    final definitions = AchievementCatalog.forGame(gameId);
    final stats = StatsService.instance;
    final states = [for (final a in definitions) stats.achievementState(a.id)];
    final unlocked = states.where((s) => s.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KfgSectionHeader(
          title: 'Achievements',
          trailing: Text(
            '$unlocked/${definitions.length}',
            style: const TextStyle(
              color: KfgColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < definitions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _AchievementTile(
            definition: definitions[i],
            state: states[i],
            progressValue: progress[definitions[i].id],
          ),
        ],
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.definition,
    required this.state,
    this.progressValue,
  });

  final AchievementDefinition definition;
  final AchievementState state;

  /// Overrides the stored progress entry count.
  final int? progressValue;

  static String _date(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final unlocked = state.unlocked;
    final color = unlocked ? KfgColors.highlight : KfgColors.textMuted;
    final target = definition.progressTarget;
    final progress = target == null
        ? null
        : unlocked
        ? target
        : (progressValue ?? state.progress.length).clamp(0, target);
    final status = unlocked
        ? (state.unlockedAt == null
              ? 'Unlocked'
              : 'Unlocked ${_date(state.unlockedAt!)}')
        : 'Locked';

    return MergeSemantics(
      child: KfgNeonCard(
        padding: const EdgeInsets.all(12),
        glowColor: unlocked ? KfgColors.highlight : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unlocked ? Icons.military_tech : Icons.lock_outline,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.title,
                    style: TextStyle(
                      color: unlocked
                          ? KfgColors.textPrimary
                          : KfgColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.description,
                    style: const TextStyle(
                      color: KfgColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress == null
                        ? status
                        : '$status · Progress $progress/$target',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (progress != null && !unlocked) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress / target!,
                        minHeight: 5,
                        color: KfgColors.primary,
                        backgroundColor: KfgColors.surfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

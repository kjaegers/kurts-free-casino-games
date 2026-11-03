import '../models/achievement.dart';

/// Every achievement in the collection, in display order. Unlock state is
/// kept by `StatsService`; each game decides when its conditions are met.
abstract final class AchievementCatalog {
  static final List<AchievementDefinition> all = List.unmodifiable(
    <AchievementDefinition>[
      // ── Video Poker ──────────────────────────────────────────────────────
      AchievementDefinition(
        id: 'video_poker.four_of_a_kind',
        gameId: 'video_poker',
        title: 'Four of a Kind',
        description: 'Finish a hand with four of a kind.',
      ),
      AchievementDefinition(
        id: 'video_poker.straight_flush',
        gameId: 'video_poker',
        title: 'Straight Flush',
        description: 'Finish a hand with a straight flush.',
      ),
      AchievementDefinition(
        id: 'video_poker.five_of_a_kind',
        gameId: 'video_poker',
        title: 'Five of a Kind',
        description:
            'Make five of a kind with a wild card, in Joker Poker or '
            'Deuces Wild.',
      ),
      AchievementDefinition(
        id: 'video_poker.four_deuces',
        gameId: 'video_poker',
        title: 'All the Deuces',
        description: 'Finish a Deuces Wild hand holding all four 2s.',
      ),
      AchievementDefinition(
        id: 'video_poker.royal_flush',
        gameId: 'video_poker',
        title: 'Royal Flush',
        description: 'Make a natural royal flush, with no wild cards.',
      ),
      AchievementDefinition(
        id: 'video_poker.every_variant',
        gameId: 'video_poker',
        title: 'Every Variant',
        description: 'Win a hand in all three variants.',
        progressTarget: 3,
      ),

      // ── Slots: Cherry Run ────────────────────────────────────────────────
      AchievementDefinition(
        id: 'slots_cherry_run.lucky_sevens',
        gameId: 'slots_cherry_run',
        title: 'Lucky Sevens',
        description: 'Line up three 7s on a line you played.',
      ),
      AchievementDefinition(
        id: 'slots_cherry_run.top_bar',
        gameId: 'slots_cherry_run',
        title: 'Top Bar',
        description: 'Line up three Triple Bars on a line you played.',
      ),
      AchievementDefinition(
        id: 'slots_cherry_run.bell_ringer',
        gameId: 'slots_cherry_run',
        title: 'Bell Ringer',
        description: 'Line up three Bells on a line you played.',
      ),
      AchievementDefinition(
        id: 'slots_cherry_run.cherry_run',
        gameId: 'slots_cherry_run',
        title: 'Cherry Run',
        description: 'Line up three Cherries on a line you played.',
      ),
      AchievementDefinition(
        id: 'slots_cherry_run.fruit_salad',
        gameId: 'slots_cherry_run',
        title: 'Fruit Salad',
        description: 'Win with three Cherries, three Plums and three Lemons.',
        progressTarget: 3,
      ),

      // ── Slots: Retro Tech ────────────────────────────────────────────────
      AchievementDefinition(
        id: 'slots_retro_tech.token_rush',
        gameId: 'slots_retro_tech',
        title: 'Token Rush',
        description: 'Win with a cluster of Arcade Tokens.',
      ),
      AchievementDefinition(
        id: 'slots_retro_tech.player_one',
        gameId: 'slots_retro_tech',
        title: 'Player One',
        description: 'Win with a cluster of Pixel Runners.',
      ),
      AchievementDefinition(
        id: 'slots_retro_tech.chain_reaction',
        gameId: 'slots_retro_tech',
        title: 'Chain Reaction',
        description: 'Cascade four or more times in one spin.',
      ),
      AchievementDefinition(
        id: 'slots_retro_tech.mega_cluster',
        gameId: 'slots_retro_tech',
        title: 'Mega Cluster',
        description: 'Make a cluster of 11 or more matching symbols.',
      ),
      AchievementDefinition(
        id: 'slots_retro_tech.full_collection',
        gameId: 'slots_retro_tech',
        title: 'Full Collection',
        description: 'Win with a cluster of every symbol.',
        progressTarget: 8,
      ),

      // ── Blackjack ────────────────────────────────────────────────────────
      AchievementDefinition(
        id: 'blackjack.natural',
        gameId: 'blackjack',
        title: 'Natural',
        description: "Be dealt a blackjack the dealer doesn't match.",
      ),
      AchievementDefinition(
        id: 'blackjack.double_down',
        gameId: 'blackjack',
        title: 'Double Down',
        description: 'Win a hand you doubled.',
      ),
      AchievementDefinition(
        id: 'blackjack.five_card_21',
        gameId: 'blackjack',
        title: 'Five-Card 21',
        description: 'Make 21 with five or more cards.',
      ),
      AchievementDefinition(
        id: 'blackjack.four_hands',
        gameId: 'blackjack',
        title: 'Four Hands',
        description: 'Split your way to four hands in one round.',
      ),
      AchievementDefinition(
        id: 'blackjack.clean_sweep',
        gameId: 'blackjack',
        title: 'Clean Sweep',
        description: 'Split and win every hand of the round.',
      ),

      // ── Roulette ─────────────────────────────────────────────────────────
      AchievementDefinition(
        id: 'roulette.straight_up',
        gameId: 'roulette',
        title: 'Straight Up',
        description: 'Win a bet on a single number.',
      ),
      AchievementDefinition(
        id: 'roulette.green_zero',
        gameId: 'roulette',
        title: 'Green Zero',
        description: 'Win a bet when the ball lands on 0.',
      ),
      AchievementDefinition(
        id: 'roulette.inside_story',
        gameId: 'roulette',
        title: 'Inside Story',
        description:
            'Win a straight-up, a split, a street, a corner and a six line '
            'bet.',
        progressTarget: 5,
      ),
      AchievementDefinition(
        id: 'roulette.deja_vu',
        gameId: 'roulette',
        title: 'Déjà Vu',
        description:
            'Win a straight-up bet on the number that came up the spin '
            'before.',
      ),

      // ── Texas Hold'em ────────────────────────────────────────────────────
      AchievementDefinition(
        id: 'texas_holdem.knockout',
        gameId: 'texas_holdem',
        title: 'Knockout',
        description: "Win an opponent's last chips.",
      ),
      AchievementDefinition(
        id: 'texas_holdem.bluff',
        gameId: 'texas_holdem',
        title: 'Stone Cold Bluff',
        description:
            'After the flop, bet or raise with nothing better than high card '
            'and make everyone fold.',
      ),
      AchievementDefinition(
        id: 'texas_holdem.quads',
        gameId: 'texas_holdem',
        title: 'Four of a Kind',
        description: 'Win a showdown with four of a kind.',
      ),
      AchievementDefinition(
        id: 'texas_holdem.straight_flush',
        gameId: 'texas_holdem',
        title: 'Straight Flush',
        description: 'Win a showdown with a straight flush.',
      ),
      AchievementDefinition(
        id: 'texas_holdem.every_difficulty',
        gameId: 'texas_holdem',
        title: 'Every Table',
        description: 'Win a pot at every difficulty.',
        progressTarget: 3,
      ),
    ],
  );

  static final Map<String, AchievementDefinition> _byId = {
    for (final a in all) a.id: a,
  };

  static AchievementDefinition? byId(String id) => _byId[id];

  static List<AchievementDefinition> forGame(String gameId) =>
      all.where((a) => a.gameId == gameId).toList(growable: false);
}

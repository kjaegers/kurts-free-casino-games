import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../achievements/achievement_catalog.dart';
import '../models/achievement.dart';
import '../models/blackjack_stats.dart';
import '../models/game_result.dart';
import '../models/roulette_stats.dart';
import '../models/slots_cherry_run_stats.dart';
import '../models/slots_retro_tech_stats.dart';
import '../models/texas_holdem_stats.dart';
import '../models/video_poker_stats.dart';
import 'persistent_storage.dart';

/// Aggregated statistics displayed on the Stats screen.
///
/// See [StatsService] for the rule that feeds these numbers.
class GameStats {
  const GameStats({
    this.totalGamesPlayed = 0,
    this.totalGamesWon = 0,
    int? totalGamesDecided,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalSecondsPlayed = 0,
    this.playsByGame = const {},
    this.recentGames = const [],
  }) : totalGamesDecided = totalGamesDecided ?? totalGamesPlayed;

  final int totalGamesPlayed;
  final int totalGamesWon;

  /// Finished games that ended in a win or a loss. Excludes endless runs,
  /// which have no outcome, so they don't drag the win rate down.
  final int totalGamesDecided;
  final int currentStreak;
  final int bestStreak;
  final int totalSecondsPlayed;

  /// Finished games per game id.
  final Map<String, int> playsByGame;
  final List<GameResult> recentGames;

  double get winRate =>
      totalGamesDecided == 0 ? 0 : totalGamesWon / totalGamesDecided;

  /// The game finished most often. Ties go to the one played most recently.
  String? get favoriteGameId {
    String? best;
    var bestPlays = 0;
    for (final entry in playsByGame.entries) {
      if (entry.value > bestPlays ||
          (entry.value == bestPlays &&
              best != null &&
              _recency(entry.key) < _recency(best))) {
        best = entry.key;
        bestPlays = entry.value;
      }
    }
    return best;
  }

  int _recency(String gameId) {
    final index = recentGames.indexWhere((r) => r.gameId == gameId);
    return index < 0 ? recentGames.length : index;
  }

  String get formattedTimePlayed {
    final hours = totalSecondsPlayed ~/ 3600;
    final minutes = (totalSecondsPlayed % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

/// Tracks game outcomes and exposes aggregated statistics.
///
/// **Overview rule ([GameStats]).** Every finished game or run is reported
/// exactly once, at the moment it ends, through [recordGameFinished] (or
/// [recordResult], which calls it). Abandoned games are not reported.
/// - Every finished game counts as played, adds its duration to time played
///   and counts toward [GameStats.favoriteGameId].
/// - A win adds to games won and extends the streak; a loss resets the streak.
/// - Endless / score-attack runs (`won: null`) have no outcome: they count as
///   played but never as a win or a loss, so they change neither the streak
///   nor the win rate.
///
/// Games keep their own detailed stats through their bespoke `record*`
/// methods in addition to this. To add a game's stats: a private field and
/// public getter, `record…`/`set…Preferences` methods, and entries in
/// [reset], `_loadFromStorage` and `_toJson` with a tolerant `_parse…`.
class StatsService extends ChangeNotifier {
  StatsService._() {
    // Best-effort eager load. main() also awaits ensureLoaded() at startup.
    unawaited(ensureLoaded());
  }

  static final StatsService instance = StatsService._();

  @visibleForTesting
  static const String storageKey = 'kfcg_stats_v1';

  static const int _schemaVersion = 1;

  GameStats _stats = const GameStats();
  Map<String, AchievementState> _achievements = const {};
  VideoPokerStats _videoPokerStats = const VideoPokerStats();
  CherryRunStats _cherryRunStats = const CherryRunStats();
  RetroTechStats _retroTechStats = const RetroTechStats();
  BlackjackStats _blackjackStats = const BlackjackStats();
  RouletteStats _rouletteStats = const RouletteStats();
  TexasHoldemStats _texasHoldemStats = const TexasHoldemStats();
  Future<void>? _loadFuture;
  bool _loaded = false;

  GameStats get stats => _stats;

  /// Video Poker results per variant, and the last variant and bet chosen.
  VideoPokerStats get videoPokerStats => _videoPokerStats;

  /// Slots: Cherry Run results, and the last lines and bet per line chosen.
  CherryRunStats get cherryRunStats => _cherryRunStats;

  /// Slots: Retro Tech results, and the last bet level chosen.
  RetroTechStats get retroTechStats => _retroTechStats;

  /// Blackjack results, and the last opening bet chosen.
  BlackjackStats get blackjackStats => _blackjackStats;

  /// Roulette results, and the last chip value chosen.
  RouletteStats get rouletteStats => _rouletteStats;

  /// Texas Hold'em results, and the last table (opponents, difficulty).
  TexasHoldemStats get texasHoldemStats => _texasHoldemStats;

  /// The stored state of achievement [id] (locked when never touched).
  AchievementState achievementState(String id) =>
      _achievements[id] ?? AchievementState.locked;

  /// Unlocks each achievement in [earned] that isn't unlocked yet, stamped
  /// [now], merges [progress] (achievement ID → entries) into the stored
  /// progress and sets [counts] (achievement ID → value, e.g. a streak).
  /// Unknown IDs are ignored. Returns only the newly
  /// unlocked achievements, in catalog order, so a result dialog never
  /// announces an older unlock again. Persists when anything changed.
  List<AchievementDefinition> recordAchievements({
    required Set<String> earned,
    Map<String, Set<String>> progress = const {},
    Map<String, int> counts = const {},
    required DateTime now,
  }) {
    final next = Map<String, AchievementState>.of(_achievements);
    var changed = false;
    for (final MapEntry(key: id, value: count) in counts.entries) {
      if (AchievementCatalog.byId(id) == null || count < 0) continue;
      final current = next[id] ?? AchievementState.locked;
      if (current.count == count) continue;
      next[id] = current.copyWith(count: count);
      changed = true;
    }
    for (final MapEntry(key: id, value: entries) in progress.entries) {
      if (AchievementCatalog.byId(id) == null) continue;
      final current = next[id] ?? AchievementState.locked;
      final merged = {...current.progress, ...entries};
      if (merged.length == current.progress.length) continue;
      next[id] = current.copyWith(progress: Set.unmodifiable(merged));
      changed = true;
    }
    final unlocked = <AchievementDefinition>[];
    for (final definition in AchievementCatalog.all) {
      if (!earned.contains(definition.id)) continue;
      final current = next[definition.id] ?? AchievementState.locked;
      if (current.unlocked) continue;
      next[definition.id] = current.copyWith(unlocked: true, unlockedAt: now);
      unlocked.add(definition);
      changed = true;
    }
    if (changed) {
      _achievements = Map.unmodifiable(next);
      notifyListeners();
      _persistAsync();
    }
    return unlocked;
  }

  /// Ensures persisted stats have been loaded into memory.
  ///
  /// Safe to call multiple times. When [forceReload] is true, cached in-memory
  /// values are replaced with what's currently in storage.
  Future<void> ensureLoaded({bool forceReload = false}) async {
    if (forceReload) {
      _loaded = false;
      _loadFuture = null;
    }
    if (_loaded) return;
    _loadFuture ??= _loadFromStorage();
    await _loadFuture;
  }

  /// Records a finished game or run in the overview stats.
  ///
  /// Pass `won: null` for endless / score-attack runs that end without a
  /// win or loss. See the class docs for the full rule.
  void recordGameFinished(
    String gameId, {
    required bool? won,
    int? durationSeconds,
    int? score,
  }) {
    _applyFinished(
      GameResult(
        gameId: gameId,
        playedAt: DateTime.now(),
        won: won ?? false,
        hasOutcome: won != null,
        durationSeconds: durationSeconds,
        score: score,
      ),
    );
    notifyListeners();
    _persistAsync();
  }

  void _applyFinished(GameResult result) {
    final decided = result.hasOutcome;
    final won = decided && result.won;
    final streak = !decided
        ? _stats.currentStreak
        : (won ? _stats.currentStreak + 1 : 0);
    _stats = GameStats(
      totalGamesPlayed: _stats.totalGamesPlayed + 1,
      totalGamesWon: _stats.totalGamesWon + (won ? 1 : 0),
      totalGamesDecided: _stats.totalGamesDecided + (decided ? 1 : 0),
      currentStreak: streak,
      bestStreak: streak > _stats.bestStreak ? streak : _stats.bestStreak,
      totalSecondsPlayed:
          _stats.totalSecondsPlayed + (result.durationSeconds ?? 0),
      playsByGame: {
        ..._stats.playsByGame,
        result.gameId: (_stats.playsByGame[result.gameId] ?? 0) + 1,
      },
      recentGames: [result, ..._stats.recentGames].take(10).toList(),
    );
  }

  /// Records a finished win/loss game in the overview stats.
  void recordResult(GameResult result) {
    _applyFinished(result);
    notifyListeners();
    _persistAsync();
  }

  /// Remembers the Video Poker variant and bet for the next session.
  void setVideoPokerPreferences({String? variantName, int? bet}) {
    _videoPokerStats = _videoPokerStats.copyWithPreferences(
      variantName: variantName,
      bet: bet,
    );
    notifyListeners();
    _persistAsync();
  }

  /// Records a completed Video Poker hand. Each hand is one game in the
  /// overview: a win when it pays more than the bet, a loss when it pays
  /// less, and no outcome when it returns exactly the bet.
  void recordVideoPokerHand(VideoPokerHandRecord hand, {int? durationSeconds}) {
    _videoPokerStats = _videoPokerStats.copyWithHand(hand);
    recordGameFinished(
      'video_poker',
      won: hand.payout == hand.bet ? null : hand.payout > hand.bet,
      durationSeconds: durationSeconds,
      score: hand.payout,
    );
  }

  /// Remembers the Cherry Run lines and bet per line for the next session.
  void setCherryRunPreferences({int? lines, int? betPerLine}) {
    _cherryRunStats = _cherryRunStats.copyWithPreferences(
      lines: lines,
      betPerLine: betPerLine,
    );
    notifyListeners();
    _persistAsync();
  }

  /// Records a completed Cherry Run spin. Each spin is one game in the
  /// overview: a win when it pays more than the bet, a loss when it pays
  /// less, and no outcome when it returns exactly the bet.
  void recordCherryRunSpin(CherryRunSpinRecord spin, {int? durationSeconds}) {
    _cherryRunStats = _cherryRunStats.copyWithSpin(spin);
    recordGameFinished(
      'slots_cherry_run',
      won: spin.payout == spin.bet ? null : spin.payout > spin.bet,
      durationSeconds: durationSeconds,
      score: spin.payout,
    );
  }

  /// Remembers the Retro Tech bet level for the next session.
  void setRetroTechPreferences({int? betLevel}) {
    _retroTechStats = _retroTechStats.copyWithPreferences(betLevel: betLevel);
    notifyListeners();
    _persistAsync();
  }

  /// Records a completed Retro Tech spin, its whole cascade. Each spin is
  /// one game in the overview: a win when it pays more than the bet, a loss
  /// when it pays less, and no outcome when it returns exactly the bet.
  void recordRetroTechSpin(RetroTechSpinRecord spin, {int? durationSeconds}) {
    _retroTechStats = _retroTechStats.copyWithSpin(spin);
    recordGameFinished(
      'slots_retro_tech',
      won: spin.payout == spin.bet ? null : spin.payout > spin.bet,
      durationSeconds: durationSeconds,
      score: spin.payout,
    );
  }

  /// Remembers the Blackjack opening bet for the next session.
  void setBlackjackPreferences({int? bet}) {
    _blackjackStats = _blackjackStats.copyWithPreferences(bet: bet);
    notifyListeners();
    _persistAsync();
  }

  /// Records a completed Blackjack round. Each round is one game in the
  /// overview: a win when it pays back more than was staked (doubles, splits
  /// and insurance included), a loss when it pays less, and no outcome when
  /// it returns exactly the stake.
  void recordBlackjackRound(
    BlackjackRoundRecord round, {
    int? durationSeconds,
  }) {
    _blackjackStats = _blackjackStats.copyWithRound(round);
    recordGameFinished(
      'blackjack',
      won: round.payout == round.wagered ? null : round.payout > round.wagered,
      durationSeconds: durationSeconds,
      score: round.payout,
    );
  }

  /// Remembers the Roulette chip value for the next session.
  void setRoulettePreferences({int? chip}) {
    _rouletteStats = _rouletteStats.copyWithPreferences(chip: chip);
    notifyListeners();
    _persistAsync();
  }

  /// Records a completed Roulette spin. Each spin is one game in the
  /// overview: a win when it pays back more than every bet on the table
  /// staked, a loss when it pays less, and no outcome when it returns
  /// exactly the stake.
  void recordRouletteSpin(RouletteSpinRecord spin, {int? durationSeconds}) {
    _rouletteStats = _rouletteStats.copyWithSpin(spin);
    recordGameFinished(
      'roulette',
      won: spin.payout == spin.bet ? null : spin.payout > spin.bet,
      durationSeconds: durationSeconds,
      score: spin.payout,
    );
  }

  /// Remembers the Texas Hold'em table for the next session.
  void setTexasHoldemPreferences({int? opponents, String? difficulty}) {
    _texasHoldemStats = _texasHoldemStats.copyWithPreferences(
      opponents: opponents,
      difficulty: difficulty,
    );
    notifyListeners();
    _persistAsync();
  }

  /// Records a completed Texas Hold'em hand. Each hand the player is dealt
  /// into is one game in the overview: a win when the player ends it with
  /// more chips than they started with, a loss with fewer, and no outcome
  /// when they break even (e.g. folding without having bet).
  void recordTexasHoldemHand(
    TexasHoldemHandRecord hand, {
    int? durationSeconds,
  }) {
    _texasHoldemStats = _texasHoldemStats.copyWithHand(hand);
    recordGameFinished(
      'texas_holdem',
      won: hand.net == 0 ? null : hand.net > 0,
      durationSeconds: durationSeconds,
      score: hand.collected,
    );
  }

  void reset() {
    _stats = const GameStats();
    _achievements = const {};
    _videoPokerStats = _videoPokerStats.copyWithPreferencesOnly();
    _cherryRunStats = _cherryRunStats.copyWithPreferencesOnly();
    _retroTechStats = _retroTechStats.copyWithPreferencesOnly();
    _blackjackStats = _blackjackStats.copyWithPreferencesOnly();
    _rouletteStats = _rouletteStats.copyWithPreferencesOnly();
    _texasHoldemStats = _texasHoldemStats.copyWithPreferencesOnly();
    notifyListeners();
    _persistAsync();
  }

  /// Writes the current stats to storage and waits for it to finish.
  Future<void> saveNow() => _saveToStorage();

  @visibleForTesting
  Future<void> saveNowForTest() => _saveToStorage();

  void _persistAsync() {
    unawaited(_saveToStorage());
  }

  Future<void> _saveToStorage() async {
    try {
      await persistentStorage.setString(storageKey, jsonEncode(_toJson()));
    } catch (e, st) {
      debugPrint('StatsService: failed to save stats: $e\n$st');
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final raw = await persistentStorage.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _stats = _parseGameStats(decoded['gameStats']);
          _achievements = _parseAchievements(decoded['achievements']);
          _videoPokerStats = _parseVideoPokerStats(decoded['videoPokerStats']);
          _cherryRunStats = _parseCherryRunStats(decoded['cherryRunStats']);
          _retroTechStats = _parseRetroTechStats(decoded['retroTechStats']);
          _blackjackStats = _parseBlackjackStats(decoded['blackjackStats']);
          _rouletteStats = _parseRouletteStats(decoded['rouletteStats']);
          _texasHoldemStats = _parseTexasHoldemStats(
            decoded['texasHoldemStats'],
          );
        }
      }
    } catch (e, st) {
      debugPrint('StatsService: failed to load stats: $e\n$st');
      // Keep safe defaults already in memory.
    } finally {
      _loaded = true;
      _loadFuture = null;
      notifyListeners();
    }
  }

  Map<String, dynamic> _toJson() {
    return {
      'version': _schemaVersion,
      'gameStats': _gameStatsToJson(_stats),
      'achievements': _achievementsToJson(_achievements),
      'videoPokerStats': _videoPokerStatsToJson(_videoPokerStats),
      'cherryRunStats': _cherryRunStatsToJson(_cherryRunStats),
      'retroTechStats': _retroTechStatsToJson(_retroTechStats),
      'blackjackStats': _blackjackStatsToJson(_blackjackStats),
      'rouletteStats': _rouletteStatsToJson(_rouletteStats),
      'texasHoldemStats': _texasHoldemStatsToJson(_texasHoldemStats),
    };
  }

  static Map<String, dynamic> _videoPokerStatsToJson(VideoPokerStats stats) {
    return {
      'byVariant': {
        for (final MapEntry(:key, :value) in stats.byVariant.entries)
          key: {
            'hands': value.hands,
            'handsWon': value.handsWon,
            'handsPushed': value.handsPushed,
            'wagered': value.wagered,
            'paid': value.paid,
            'biggestWin': value.biggestWin,
            'handCounts': value.handCounts,
          },
      },
      'preferredVariantName': stats.preferredVariantName,
      'preferredBet': stats.preferredBet,
    };
  }

  /// Negative numbers read as 0, malformed variants and counts are skipped,
  /// wins and pushes can't exceed hands and a bad bet falls back to the
  /// default.
  static VideoPokerStats _parseVideoPokerStats(dynamic raw) {
    if (raw is! Map) return const VideoPokerStats();
    const defaults = VideoPokerStats();
    final byVariant = <String, VideoPokerVariantRecord>{};
    final rawVariants = raw['byVariant'];
    if (rawVariants is Map) {
      for (final MapEntry(:key, :value) in rawVariants.entries) {
        if (key is! String || key.isEmpty || value is! Map) continue;
        final hands = _nonNegative(value['hands']);
        final won = _nonNegative(value['handsWon']).clamp(0, hands);
        final rawCounts = value['handCounts'];
        byVariant[key] = VideoPokerVariantRecord(
          hands: hands,
          handsWon: won,
          handsPushed: _nonNegative(value['handsPushed']).clamp(0, hands - won),
          wagered: _nonNegative(value['wagered']),
          paid: _nonNegative(value['paid']),
          biggestWin: _nonNegative(value['biggestWin']),
          handCounts: Map.unmodifiable({
            if (rawCounts is Map)
              for (final MapEntry(:key, :value) in rawCounts.entries)
                if (key is String && value is int && value > 0) key: value,
          }),
        );
      }
    }
    final bet = raw['preferredBet'];
    final variantName = raw['preferredVariantName'];
    return VideoPokerStats(
      byVariant: Map.unmodifiable(byVariant),
      preferredVariantName: variantName is String ? variantName : null,
      preferredBet: bet is int && bet >= 1 && bet <= 5
          ? bet
          : defaults.preferredBet,
    );
  }

  static Map<String, dynamic> _cherryRunStatsToJson(CherryRunStats stats) {
    return {
      'spins': stats.spins,
      'spinsWon': stats.spinsWon,
      'spinsPushed': stats.spinsPushed,
      'wagered': stats.wagered,
      'paid': stats.paid,
      'biggestWin': stats.biggestWin,
      'winCounts': stats.winCounts,
      'preferredLines': stats.preferredLines,
      'preferredBetPerLine': stats.preferredBetPerLine,
    };
  }

  /// Negative numbers read as 0, malformed win counts are skipped, wins and
  /// pushes can't exceed spins and bad preferences fall back to defaults.
  static CherryRunStats _parseCherryRunStats(dynamic raw) {
    if (raw is! Map) return const CherryRunStats();
    const defaults = CherryRunStats();
    final spins = _nonNegative(raw['spins']);
    final won = _nonNegative(raw['spinsWon']).clamp(0, spins);
    final rawCounts = raw['winCounts'];
    final lines = raw['preferredLines'];
    final betPerLine = raw['preferredBetPerLine'];
    return CherryRunStats(
      spins: spins,
      spinsWon: won,
      spinsPushed: _nonNegative(raw['spinsPushed']).clamp(0, spins - won),
      wagered: _nonNegative(raw['wagered']),
      paid: _nonNegative(raw['paid']),
      biggestWin: _nonNegative(raw['biggestWin']),
      winCounts: Map.unmodifiable({
        if (rawCounts is Map)
          for (final MapEntry(:key, :value) in rawCounts.entries)
            if (key is String && value is int && value > 0) key: value,
      }),
      preferredLines: lines is int && lines >= 1 && lines <= 3
          ? lines
          : defaults.preferredLines,
      preferredBetPerLine:
          betPerLine is int && betPerLine >= 1 && betPerLine <= 5
          ? betPerLine
          : defaults.preferredBetPerLine,
    );
  }

  static Map<String, dynamic> _retroTechStatsToJson(RetroTechStats stats) {
    return {
      'spins': stats.spins,
      'spinsWon': stats.spinsWon,
      'spinsPushed': stats.spinsPushed,
      'wagered': stats.wagered,
      'paid': stats.paid,
      'biggestWin': stats.biggestWin,
      'longestChain': stats.longestChain,
      'clusterCounts': stats.clusterCounts,
      'preferredBetLevel': stats.preferredBetLevel,
    };
  }

  /// Negative numbers read as 0, malformed cluster counts are skipped, wins
  /// and pushes can't exceed spins and a bad bet level falls back to the
  /// default.
  static RetroTechStats _parseRetroTechStats(dynamic raw) {
    if (raw is! Map) return const RetroTechStats();
    const defaults = RetroTechStats();
    final spins = _nonNegative(raw['spins']);
    final won = _nonNegative(raw['spinsWon']).clamp(0, spins);
    final rawCounts = raw['clusterCounts'];
    final betLevel = raw['preferredBetLevel'];
    return RetroTechStats(
      spins: spins,
      spinsWon: won,
      spinsPushed: _nonNegative(raw['spinsPushed']).clamp(0, spins - won),
      wagered: _nonNegative(raw['wagered']),
      paid: _nonNegative(raw['paid']),
      biggestWin: _nonNegative(raw['biggestWin']),
      longestChain: _nonNegative(raw['longestChain']),
      clusterCounts: Map.unmodifiable({
        if (rawCounts is Map)
          for (final MapEntry(:key, :value) in rawCounts.entries)
            if (key is String && value is int && value > 0) key: value,
      }),
      preferredBetLevel: betLevel is int && betLevel >= 1 && betLevel <= 5
          ? betLevel
          : defaults.preferredBetLevel,
    );
  }

  static Map<String, dynamic> _blackjackStatsToJson(BlackjackStats stats) {
    return {
      'rounds': stats.rounds,
      'roundsWon': stats.roundsWon,
      'roundsPushed': stats.roundsPushed,
      'hands': stats.hands,
      'handsWon': stats.handsWon,
      'blackjacks': stats.blackjacks,
      'doubles': stats.doubles,
      'splits': stats.splits,
      'surrenders': stats.surrenders,
      'wagered': stats.wagered,
      'paid': stats.paid,
      'biggestWin': stats.biggestWin,
      'preferredBet': stats.preferredBet,
    };
  }

  /// Negative numbers read as 0, wins and pushes can't exceed rounds, hands
  /// won can't exceed hands, and a bad bet falls back to the default.
  static BlackjackStats _parseBlackjackStats(dynamic raw) {
    if (raw is! Map) return const BlackjackStats();
    const defaults = BlackjackStats();
    final rounds = _nonNegative(raw['rounds']);
    final won = _nonNegative(raw['roundsWon']).clamp(0, rounds);
    final hands = _nonNegative(raw['hands']);
    final bet = raw['preferredBet'];
    return BlackjackStats(
      rounds: rounds,
      roundsWon: won,
      roundsPushed: _nonNegative(raw['roundsPushed']).clamp(0, rounds - won),
      hands: hands,
      handsWon: _nonNegative(raw['handsWon']).clamp(0, hands),
      blackjacks: _nonNegative(raw['blackjacks']),
      doubles: _nonNegative(raw['doubles']),
      splits: _nonNegative(raw['splits']),
      surrenders: _nonNegative(raw['surrenders']),
      wagered: _nonNegative(raw['wagered']),
      paid: _nonNegative(raw['paid']),
      biggestWin: _nonNegative(raw['biggestWin']),
      preferredBet: bet is int && bet >= 10 && bet <= 1000 && bet % 10 == 0
          ? bet
          : defaults.preferredBet,
    );
  }

  static Map<String, dynamic> _rouletteStatsToJson(RouletteStats stats) {
    return {
      'spins': stats.spins,
      'spinsWon': stats.spinsWon,
      'spinsPushed': stats.spinsPushed,
      'wagered': stats.wagered,
      'paid': stats.paid,
      'biggestWin': stats.biggestWin,
      'straightWins': stats.straightWins,
      'zeros': stats.zeros,
      'preferredChip': stats.preferredChip,
    };
  }

  /// Negative numbers read as 0, wins and pushes can't exceed spins, nor
  /// straight-up wins and zeros, and a chip that isn't on the table falls
  /// back to the default.
  static RouletteStats _parseRouletteStats(dynamic raw) {
    if (raw is! Map) return const RouletteStats();
    const defaults = RouletteStats();
    final spins = _nonNegative(raw['spins']);
    final won = _nonNegative(raw['spinsWon']).clamp(0, spins);
    final chip = raw['preferredChip'];
    return RouletteStats(
      spins: spins,
      spinsWon: won,
      spinsPushed: _nonNegative(raw['spinsPushed']).clamp(0, spins - won),
      wagered: _nonNegative(raw['wagered']),
      paid: _nonNegative(raw['paid']),
      biggestWin: _nonNegative(raw['biggestWin']),
      straightWins: _nonNegative(raw['straightWins']).clamp(0, spins),
      zeros: _nonNegative(raw['zeros']).clamp(0, spins),
      preferredChip: const [1, 5, 25, 100, 500].contains(chip)
          ? chip as int
          : defaults.preferredChip,
    );
  }

  static Map<String, dynamic> _texasHoldemStatsToJson(TexasHoldemStats stats) {
    return {
      'hands': stats.hands,
      'handsWon': stats.handsWon,
      'handsFolded': stats.handsFolded,
      'showdowns': stats.showdowns,
      'showdownsWon': stats.showdownsWon,
      'knockouts': stats.knockouts,
      'wagered': stats.wagered,
      'collected': stats.collected,
      'biggestPot': stats.biggestPot,
      'bestShowdownCategory': stats.bestShowdownCategory,
      'preferredOpponents': stats.preferredOpponents,
      'preferredDifficulty': stats.preferredDifficulty,
    };
  }

  /// Negative numbers read as 0, wins, folds and showdowns can't exceed
  /// hands (nor showdowns won the showdowns), an unknown hand category
  /// reads as none, and bad preferences fall back to the defaults.
  static TexasHoldemStats _parseTexasHoldemStats(dynamic raw) {
    if (raw is! Map) return const TexasHoldemStats();
    const defaults = TexasHoldemStats();
    final hands = _nonNegative(raw['hands']);
    final showdowns = _nonNegative(raw['showdowns']).clamp(0, hands);
    final category = raw['bestShowdownCategory'];
    final opponents = raw['preferredOpponents'];
    final difficulty = raw['preferredDifficulty'];
    return TexasHoldemStats(
      hands: hands,
      handsWon: _nonNegative(raw['handsWon']).clamp(0, hands),
      handsFolded: _nonNegative(raw['handsFolded']).clamp(0, hands),
      showdowns: showdowns,
      showdownsWon: _nonNegative(raw['showdownsWon']).clamp(0, showdowns),
      knockouts: _nonNegative(raw['knockouts']),
      wagered: _nonNegative(raw['wagered']),
      collected: _nonNegative(raw['collected']),
      biggestPot: _nonNegative(raw['biggestPot']),
      bestShowdownCategory: category is int && category >= 0 && category <= 8
          ? category
          : -1,
      preferredOpponents: opponents is int && opponents >= 1 && opponents <= 5
          ? opponents
          : defaults.preferredOpponents,
      preferredDifficulty: const ['easy', 'normal', 'hard'].contains(difficulty)
          ? difficulty as String
          : defaults.preferredDifficulty,
    );
  }

  static int _nonNegative(dynamic value) {
    final n = _asInt(value);
    return n < 0 ? 0 : n;
  }

  static Map<String, dynamic> _achievementsToJson(
    Map<String, AchievementState> achievements,
  ) {
    return {
      for (final MapEntry(:key, :value) in achievements.entries)
        key: {
          'unlocked': value.unlocked,
          if (value.unlockedAt case final at?)
            'unlockedAt': at.toUtc().toIso8601String(),
          if (value.progress.isNotEmpty) 'progress': value.progress.toList(),
          if (value.count > 0) 'count': value.count,
        },
    };
  }

  /// Tolerates missing, legacy and malformed data: bad entries are skipped,
  /// a bad or missing date leaves an unlock undated, progress keeps only
  /// distinct non-empty strings and a bad count reads as 0. Unknown IDs are kept so that data from a
  /// newer version survives, but are never shown.
  static Map<String, AchievementState> _parseAchievements(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, AchievementState>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (key is! String || key.isEmpty || value is! Map) continue;
      final rawAt = value['unlockedAt'];
      final at = rawAt is String ? DateTime.tryParse(rawAt)?.toLocal() : null;
      final unlocked = value['unlocked'] == true || at != null;
      final rawProgress = value['progress'];
      final progress = <String>{
        if (rawProgress is List)
          for (final entry in rawProgress)
            if (entry is String && entry.isNotEmpty) entry,
      };
      final rawCount = value['count'];
      final count = rawCount is int && rawCount > 0 ? rawCount : 0;
      if (!unlocked && progress.isEmpty && count == 0) continue;
      result[key] = AchievementState(
        unlocked: unlocked,
        unlockedAt: unlocked ? at : null,
        progress: Set.unmodifiable(progress),
        count: count,
      );
    }
    return Map.unmodifiable(result);
  }

  static Map<String, dynamic> _gameStatsToJson(GameStats stats) {
    return {
      'totalGamesPlayed': stats.totalGamesPlayed,
      'totalGamesWon': stats.totalGamesWon,
      'totalGamesDecided': stats.totalGamesDecided,
      'currentStreak': stats.currentStreak,
      'bestStreak': stats.bestStreak,
      'totalSecondsPlayed': stats.totalSecondsPlayed,
      'favoriteGameId': stats.favoriteGameId,
      'playsByGame': stats.playsByGame,
      'recentGames': stats.recentGames.map(_gameResultToJson).toList(),
    };
  }

  static Map<String, dynamic> _gameResultToJson(GameResult result) {
    return {
      'gameId': result.gameId,
      'playedAt': result.playedAt.toIso8601String(),
      'won': result.won,
      'hasOutcome': result.hasOutcome,
      'durationSeconds': result.durationSeconds,
      'score': result.score,
      'metadata': result.metadata,
    };
  }

  static GameStats _parseGameStats(dynamic raw) {
    final map = raw is Map ? raw.cast<Object?, Object?>() : const {};
    final recentRaw = map['recentGames'];
    final recent = recentRaw is List
        ? recentRaw.map(_parseGameResult).whereType<GameResult>().toList()
        : const <GameResult>[];

    final playsRaw = map['playsByGame'];
    final plays = <String, int>{};
    if (playsRaw is Map) {
      for (final entry in playsRaw.entries) {
        final count = _asInt(entry.value);
        if (count > 0) plays[entry.key.toString()] = count;
      }
    } else {
      // Saved before per-game play counts existed: seed them from the
      // recent-games list so the favourite reflects what was really played.
      for (final result in recent) {
        plays[result.gameId] = (plays[result.gameId] ?? 0) + 1;
      }
    }

    final played = _asInt(map['totalGamesPlayed']);
    return GameStats(
      totalGamesPlayed: played,
      totalGamesWon: _asInt(map['totalGamesWon']),
      // Absent in saves from before endless runs were counted, when every
      // played game was a win or a loss.
      totalGamesDecided: map.containsKey('totalGamesDecided')
          ? _asInt(map['totalGamesDecided'])
          : played,
      currentStreak: _asInt(map['currentStreak']),
      bestStreak: _asInt(map['bestStreak']),
      totalSecondsPlayed: _asInt(map['totalSecondsPlayed']),
      playsByGame: plays,
      recentGames: recent,
    );
  }

  static GameResult? _parseGameResult(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();

    final gameId = _asStringOrNull(map['gameId']);
    if (gameId == null || gameId.isEmpty) return null;

    final playedAt =
        _parseDateTime(map['playedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final metadataRaw = map['metadata'];
    final metadata = metadataRaw is Map
        ? metadataRaw.map((k, v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};

    return GameResult(
      gameId: gameId,
      playedAt: playedAt,
      won: _asBool(map['won']),
      hasOutcome: _asBool(map['hasOutcome'], true),
      durationSeconds: _asNullableInt(map['durationSeconds']),
      score: _asNullableInt(map['score']),
      metadata: metadata,
    );
  }

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    return _asInt(value);
  }

  static bool _asBool(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    return fallback;
  }

  static String? _asStringOrNull(dynamic value) {
    if (value is String) return value;
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

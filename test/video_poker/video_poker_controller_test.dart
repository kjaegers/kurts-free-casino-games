import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';
import 'package:kurts_free_casino_games/core/services/stats_service.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_achievements.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_game.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/logic/video_poker_variant.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/video_poker_save_service.dart';
import 'package:kurts_free_casino_games/features/games/video_poker/video_poker_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'video_poker_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsService stats;
  late MemoryPersistentStorage storage;
  late CreditsService credits;
  late ScriptedShuffler shuffler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = StatsService.instance;
    await stats.ensureLoaded(forceReload: true);
    stats.reset();
    await stats.saveNowForTest();
    storage = MemoryPersistentStorage();
    credits = CreditsService(storage: storage);
    shuffler = ScriptedShuffler();
  });

  Future<VideoPokerScreenController> open({
    VideoPokerVariant variant = VideoPokerVariant.jacksOrBetter,
    int bet = 5,
  }) async {
    stats.setVideoPokerPreferences(variantName: variant.name, bet: bet);
    final controller = VideoPokerScreenController(
      stats: stats,
      credits: credits,
      saveService: VideoPokerSaveService(storage: storage),
      shuffleDeck: shuffler.call,
      tonePlayer: SilentTonePlayer(),
    );
    await controller.initialize();
    return controller;
  }

  void holdAll(VideoPokerScreenController c) {
    for (var i = 0; i < 5; i++) {
      c.toggleHold(i);
    }
  }

  test('starts with the remembered variant and bet', () async {
    final c = await open(variant: VideoPokerVariant.deucesWild, bet: 3);
    expect(c.variant, VideoPokerVariant.deucesWild);
    expect(c.bet, 3);
    expect(c.game.phase, VideoPokerPhase.betting);
    expect(c.balance, CreditsService.startingBalance);
    c.dispose();
  });

  test('deal takes the bet and draw pays the winnings', () async {
    shuffler.queue('JC JD JH 5S 9C 2D 3H');
    final c = await open(bet: 2);
    expect(c.deal(), isTrue);
    expect(c.balance, 998);
    expect(c.deal(), isFalse, reason: 'one hand at a time');
    c.toggleHold(0);
    c.toggleHold(1);
    c.toggleHold(2);
    expect(c.draw(), isTrue);
    expect(c.game.result, VideoPokerHand.threeOfAKind);
    expect(c.game.payout, 6);
    expect(c.balance, 1004);
    c.dispose();
  });

  test('records each hand once, with honest outcomes', () async {
    shuffler
      ..queue('JC JD 2H 5S 9C 3D 4H 6C')
      ..queue('JC QD KH 5S 9C 3D 4H 6C 7D 8S');
    final c = await open(bet: 1);
    c.deal();
    c.toggleHold(0);
    c.toggleHold(1);
    c.draw(); // Jacks: returns the 1-coin bet.
    c.deal();
    holdAll(c);
    c.draw(); // Nothing.
    final vp = stats.videoPokerStats;
    expect(vp.hands, 2);
    expect(vp.handsWon, 0);
    expect(vp.recordFor('jacksOrBetter').handsPushed, 1);
    expect(vp.wagered, 2);
    expect(vp.paid, 1);
    expect(vp.net, -1);
    expect(stats.stats.totalGamesPlayed, 2);
    expect(stats.stats.totalGamesWon, 0);
    expect(stats.stats.totalGamesDecided, 1, reason: 'a push has no outcome');
    expect(c.draw(), isFalse);
    expect(stats.videoPokerStats.hands, 2);
    c.dispose();
  });

  test('bet one wraps 5 to 1; bet max bets 5 and deals', () async {
    final c = await open(bet: 4);
    c.betOne();
    expect(c.bet, 5);
    c.betOne();
    expect(c.bet, 1);
    expect(stats.videoPokerStats.preferredBet, 1);
    expect(c.betMax(), isTrue);
    expect(c.bet, 5);
    expect(c.game.isHolding, isTrue);
    expect(c.balance, 995);
    expect(c.betOne(), isFalse, reason: 'bet is fixed until the draw');
    c.dispose();
  });

  test(
    'cannot bet more than the balance; a broke player refills free',
    () async {
      credits.reset();
      credits.debit(997);
      final c = await open(bet: 5);
      expect(c.canDeal, isFalse);
      expect(c.betTooHigh, isTrue);
      expect(c.refillCredits(), isFalse, reason: 'not broke yet');
      expect(c.betMax(), isTrue, reason: 'bet max bets what is left');
      expect(c.bet, 3);
      expect(c.balance, 0);
      holdAll(c);
      c.draw();
      expect(c.isBroke, isTrue);
      expect(c.canDeal, isFalse);
      expect(c.refillCredits(), isTrue);
      expect(c.balance, CreditsService.startingBalance);
      expect(c.canDeal, isTrue);
      c.dispose();
    },
  );

  test(
    'a dealt hand is saved and resumes exactly, without a new bet',
    () async {
      shuffler.queue('9S 9D 9H 9C 4C 2D 3D');
      final first = await open(bet: 5);
      first.deal();
      first.toggleHold(0);
      first.dispose();
      await pumpEventQueue();
      expect(storage.values[VideoPokerSaveService.storageKey], isNotNull);

      final second = await open(bet: 1);
      expect(second.game.isHolding, isTrue);
      expect(second.bet, 5);
      expect(second.game.held, [true, false, false, false, false]);
      expect(second.balance, 995);
      expect(second.canChangeVariant, isFalse);
      expect(second.startSession(VideoPokerVariant.deucesWild), isFalse);
      for (var i = 1; i < 4; i++) {
        second.toggleHold(i);
      }
      second.draw();
      expect(second.game.result, VideoPokerHand.fourOfAKind);
      expect(second.balance, 995 + 125);
      await pumpEventQueue();
      expect(storage.values[VideoPokerSaveService.storageKey], isNull);
      expect(shuffler.dealt, 1, reason: 'resuming never reshuffles');
      second.dispose();
    },
  );

  test('a corrupt save starts a fresh session', () async {
    storage.values[VideoPokerSaveService.storageKey] = '{"version":1,"bet":';
    final c = await open();
    expect(c.game.phase, VideoPokerPhase.betting);
    c.dispose();
  });

  test('switching variants between hands is remembered', () async {
    final c = await open();
    expect(c.startSession(VideoPokerVariant.jokerPoker), isTrue);
    expect(c.variant, VideoPokerVariant.jokerPoker);
    expect(stats.videoPokerStats.preferredVariantName, 'jokerPoker');
    shuffler.queue('KC JK 2H 5S 9C');
    c.deal();
    expect(c.game.hand.where((card) => card.isJoker), hasLength(1));
    c.dispose();
  });

  test('achievements unlock once and are announced once', () async {
    shuffler
      ..queue('7C 7D 7H 7S 2C')
      ..queue('7C 7D 7H 7S 2C');
    final c = await open();
    c.deal();
    holdAll(c);
    c.draw();
    expect(c.takeNewAchievements().map((a) => a.id), [
      VideoPokerAchievementIds.fourOfAKind,
    ]);
    expect(c.takeNewAchievements(), isEmpty);
    expect(
      stats.achievementState(VideoPokerAchievementIds.everyVariant).progress,
      {'jacksOrBetter'},
    );
    c.deal();
    holdAll(c);
    c.draw();
    expect(c.takeNewAchievements(), isEmpty);
    c.dispose();
  });

  test('the message names the dealt and paid hands', () async {
    shuffler.queue('KC KD 2H 5S 9C');
    final c = await open(variant: VideoPokerVariant.jokerPoker);
    expect(c.message, contains('DEAL'));
    c.deal();
    expect(c.message, startsWith('Kings or Better!'));
    holdAll(c);
    c.draw();
    expect(c.message, 'Kings or Better: pays 5');
    c.dispose();
  });
}

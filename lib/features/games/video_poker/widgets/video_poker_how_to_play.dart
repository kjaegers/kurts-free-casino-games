import '../../../../core/widgets/kfg_how_to_play_dialog.dart';

/// Video Poker's How to Play content, shown with [showKfgHowToPlayDialog].
/// The returns quoted here are checked by
/// `tools/video_poker/return_check.dart`.
const List<KfgHowToPlaySection> videoPokerHowToPlaySections = [
  KfgHowToPlaySection(
    title: 'OBJECTIVE',
    body:
        'Make the best five-card poker hand you can. Each hand is one deal '
        'and one draw, paid from the paytable on screen.',
  ),
  KfgHowToPlaySection(
    title: 'EACH HAND',
    body:
        '1. Bet 1 to 5 coins (one credit each) with BET ONE, then press '
        'DEAL. BET MAX bets 5 and deals at once.\n'
        '2. Tap the cards you want to keep so they show HELD.\n'
        '3. Press DRAW. Every card not held is replaced from the same deck, '
        'and the final hand is paid.',
  ),
  KfgHowToPlaySection(
    title: 'PAYOUTS',
    body:
        'The paytable shows what each hand pays for every bet; your bet\'s '
        'column is lit. Winnings include your bet, so a hand that pays 1 '
        'for 1 gives your stake back. Only the best hand is paid. A natural '
        'Royal Flush pays 250 per coin, or 4,000 for a 5-coin bet, so '
        'betting 5 coins gives the best return.',
  ),
  KfgHowToPlaySection(
    title: 'VARIANTS',
    body:
        'Joker Poker: 53 cards with one joker, which is wild. A pair of '
        'Kings or Aces is the lowest paying hand. Five of a Kind pays 200 '
        'per coin and a Wild Royal (made with the joker) 100. Returns '
        '100.65%.\n\n'
        'Jacks or Better: the classic 52-card game. A pair of Jacks or '
        'better is the lowest paying hand. Returns 99.54%.\n\n'
        'Deuces Wild: 52 cards, all four 2s are wild. Three of a Kind is '
        'the lowest paying hand. Four Deuces pays 200 per coin and a Wild '
        'Royal 25. Returns 100.76%.\n\n'
        'The returns are the long-run average for perfect play at 5 coins; '
        'real sessions swing up and down. Choose a variant when you open '
        'the game or with VARIANT between hands.',
  ),
  KfgHowToPlaySection(
    title: 'WILD CARDS',
    body:
        'A wild card counts as whatever card makes your hand best. A '
        'Natural Royal has no wild cards; with one it is a Wild Royal.',
  ),
  KfgHowToPlaySection(
    title: 'FAIR PLAY',
    body:
        'Every hand is dealt from a freshly shuffled deck. Your balance, '
        'your bet and past hands never change the cards. There is no hidden '
        'house edge beyond the paytable.',
  ),
  KfgHowToPlaySection(
    title: 'CREDITS',
    body:
        'Credits are play money shared by every game, shown at the top of '
        'the screen. They can never be bought or cashed out. If you run '
        'out, tap FREE REFILL for 1,000 more, any time. You can also reset '
        'them in Settings.',
  ),
  KfgHowToPlaySection(
    title: 'CONTROLS',
    body:
        'Tap a card to hold or release it. Keyboard: 1–5 hold cards, Space '
        'or Enter deals and draws, B bets one, M bets max, V picks a '
        'variant.',
  ),
  KfgHowToPlaySection(
    title: 'SAVING',
    body:
        'A dealt hand is saved straight away. Leave any time and you\'ll '
        'come back to the same cards and the same draw, never a new deal.',
  ),
];

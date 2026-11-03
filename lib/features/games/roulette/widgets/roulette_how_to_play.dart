import '../../../../core/widgets/kfg_how_to_play_dialog.dart';

/// Roulette's How to Play content, shown with [showKfgHowToPlayDialog].
/// The return quoted here is checked by `tools/roulette/return_check.dart`
/// (also run as a test).
const List<KfgHowToPlaySection> rouletteHowToPlaySections = [
  KfgHowToPlaySection(
    title: 'OBJECTIVE',
    body:
        'Bet on where the ball will land on a single-zero wheel of 37 '
        'pockets: 0 (green) and the numbers 1 to 36, half red and half '
        'black. Every bet that covers the winning number is paid.',
  ),
  KfgHowToPlaySection(
    title: 'EACH SPIN',
    body:
        '1. Pick a chip: 1, 5, 25, 100 or 500 credits.\n'
        '2. Tap the table to put it down. Tap again to add another chip; '
        'UNDO takes back the last chip and CLEAR takes them all.\n'
        '3. Press SPIN. Your whole bet is taken, the wheel turns for 4 '
        'seconds and the ball drops into a pocket. Press SKIP to see where '
        'it lands straight away.\n'
        'Your chips stay on the table afterwards, so SPIN bets the same '
        'again. Change them any time the wheel is still.',
  ),
  KfgHowToPlaySection(
    title: 'PLACING CHIPS',
    body:
        'Tap the middle of a number to bet on it alone. Tap the line '
        'between two numbers for a split, or the point where four meet for '
        'a corner. Tap the outer edge of a row (beside the 1, 4, 7… numbers) '
        'for a street of three, or where that edge meets a line between '
        'rows for a six line. Along the 0, the same taps give the 0 splits, '
        'the trios (0-1-2, 0-2-3) and the first four (0-1-2-3).\n\n'
        'The status line names every bet as you place it. The boxes around '
        'the numbers are the column bets ("2 to 1"), the dozens and the '
        'even-money bets.',
  ),
  KfgHowToPlaySection(
    title: 'PAYOUTS',
    body:
        'Straight up (1 number): 35 to 1\n'
        'Split (2 numbers): 17 to 1\n'
        'Street or trio (3 numbers): 11 to 1\n'
        'Corner or first four (4 numbers): 8 to 1\n'
        'Six line (6 numbers): 5 to 1\n'
        'Column or dozen (12 numbers): 2 to 1\n'
        'Red, Black, Odd, Even, 1–18, 19–36: 1 to 1\n\n'
        'Winnings come with your stake back. When the ball lands on 0, '
        'every bet that doesn\'t include 0 loses, the outside bets too.',
  ),
  KfgHowToPlaySection(
    title: 'THE ODDS',
    body:
        'Every pocket is equally likely, and every bet on the table has the '
        'same long-run return: 36 credits back for every 37 bet, or 97.30%. '
        'The 0 is the house\'s edge (2.70%). Real sessions swing up and '
        'down.\n\n'
        'Each spin is independent: the recent numbers shown beside the wheel '
        'are there for interest only and never make a number more or less '
        'likely to come up.',
  ),
  KfgHowToPlaySection(
    title: 'TABLE LIMITS',
    body:
        'Up to 1,000 credits on any one bet, and no more in total than your '
        'balance.',
  ),
  KfgHowToPlaySection(
    title: 'FAIR PLAY',
    body:
        'Where the ball lands is decided when you press SPIN, with every '
        'pocket equally likely. Your balance, your bets and past spins '
        'never change it.',
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
        'Keyboard: 1 to 5 pick a chip, U or Backspace undoes, C clears, '
        'Space or Enter spins (and skips the spin).',
  ),
  KfgHowToPlaySection(
    title: 'SAVING',
    body:
        'Your chip is remembered. If you leave while the ball is rolling, '
        'that spin is paid in full; it is never lost or spun again.',
  ),
];

import '../../../../core/widgets/kfg_how_to_play_dialog.dart';

/// Cherry Run's How to Play content, shown with [showKfgHowToPlayDialog].
/// The return and odds quoted here are checked by
/// `tools/slots_cherry_run/return_check.dart` (also run as a test).
const List<KfgHowToPlaySection> cherryRunHowToPlaySections = [
  KfgHowToPlaySection(
    title: 'OBJECTIVE',
    body:
        'Spin three reels and line up matching symbols on the lines you '
        'play. Each paying line is paid from the paytable on screen.',
  ),
  KfgHowToPlaySection(
    title: 'EACH SPIN',
    body:
        '1. Choose how many lines to play with LINES (1 to 3) and how many '
        'credits to bet on each with BET ONE (1 to 5). Your total bet is '
        'lines × bet per line.\n'
        '2. Press SPIN. The reels turn for 2 seconds, then stop one at a '
        'time, left to right, half a second to 2 seconds apart; press STOP '
        'to stop them straight away. MAX BET bets as much as it can, up to 5 on all '
        '3 lines, and spins.',
  ),
  KfgHowToPlaySection(
    title: 'LINES',
    body:
        'Line 1 is the middle row, line 2 the top row and line 3 the bottom '
        'row. The numbers beside the reels light up for the lines you play; '
        'symbols on a line you didn\'t play never pay.',
  ),
  KfgHowToPlaySection(
    title: 'PAYOUTS',
    body:
        'Lines are read left to right. Three 7s pay 1,000 per credit bet on '
        'the line; three Triple Bars 100, Double Bars 50, Bars 25, Bells 20, '
        'Cherries 20, Plums 15 and Lemons 12. Any mix of three bars pays 5.\n\n'
        'Cherries pay from the left reel: a Cherry on reel 1 pays 2, two '
        'Cherries on reels 1 and 2 pay 5. Only the best win on each line is '
        'paid, and winnings include the credit you bet on that line. Every '
        'paying line is added together.',
  ),
  KfgHowToPlaySection(
    title: 'THE REELS AND THE ODDS',
    body:
        'Each reel has 28 stops: one 7, two Triple Bars, three Double Bars, '
        'four Bars, four Bells, five Plums, five Lemons and four Cherries. '
        'Every stop is equally likely and each reel stops on its own, so '
        'what you see on the reels is the whole story: no hidden stops, no '
        'near misses steered your way.\n\n'
        'About 1 line in 5 pays something. Three 7s come up about once in '
        '21,952 lines. The long-run return is 96.26% of every credit bet, '
        'the same for every bet and number of lines; real sessions swing up '
        'and down.',
  ),
  KfgHowToPlaySection(
    title: 'FAIR PLAY',
    body:
        'Where the reels stop is decided when you press SPIN. Your balance, '
        'your bet and past spins never change it. The pauses between reels '
        'stopping are random too, and never depend on what the reels show.',
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
        'Keyboard: Space or Enter spins (and stops the reels), L changes '
        'lines, B bets one more per line, M is max bet.',
  ),
  KfgHowToPlaySection(
    title: 'SAVING',
    body:
        'Your lines and bet are remembered. If you leave while the reels are '
        'turning, that spin is paid in full; it is never lost or spun again.',
  ),
];

import '../../../../core/services/credits_service.dart';
import '../../../../core/widgets/kfg_how_to_play_dialog.dart';
import '../logic/retro_tech_achievements.dart';
import '../logic/retro_tech_cascade.dart';
import '../logic/retro_tech_paytable.dart';
import '../logic/retro_tech_symbols.dart';

/// Retro Tech's How to Play content, shown with [showKfgHowToPlayDialog].
/// The return and odds quoted here are checked by
/// `tools/slots_retro_tech/return_check.dart` (a shorter run is a test).
final List<KfgHowToPlaySection> retroTechHowToPlaySections = [
  const KfgHowToPlaySection(
    title: 'OBJECTIVE',
    body:
        'Spin to fill the 5 × 5 grid with retro tech and make clusters of '
        '$retroTechMinCluster or more matching symbols. Every cluster pays '
        'from the paytable on screen, then cascades away to make room for '
        'more.',
  ),
  const KfgHowToPlaySection(
    title: 'EACH SPIN',
    body:
        '1. Choose your bet with BET ONE: 10, 20, 30, 40 or 50 credits. MAX '
        'BET bets 50 (or as much as you can cover) and spins.\n'
        '2. Press SPIN. Symbols drop into all five columns.\n'
        '3. Press STOP at any time to skip to the end of the spin; it ends '
        'exactly where it was going to and pays the same.',
  ),
  const KfgHowToPlaySection(
    title: 'CLUSTERS AND CASCADES',
    body:
        'A cluster is $retroTechMinCluster or more of the same symbol joined '
        'side to side or top to bottom (diagonals don\'t count). Every '
        'cluster on the grid pays, then its symbols vanish. The symbols '
        'above fall into the gaps and new ones drop in from the top. If '
        'that makes new clusters they pay too, and the grid cascades again, '
        'until no cluster is left. One spin can chain any number of '
        'cascades, all for the one bet. (A spin stops after '
        '$retroTechMaxCascades paying cascades; the longest chain in 20 '
        'million test spins was 10.)',
  ),
  KfgHowToPlaySection(
    title: 'PAYOUTS',
    body:
        'The paytable shows what a cluster pays at your current bet, by '
        'symbol and size, from ${retroTechTiers.first.label} up to '
        '${retroTechTiers.last.label}. Bigger clusters and rarer symbols '
        'pay more: $retroTechMinCluster Microchips pay '
        '${_timesBet(RetroTechSymbol.chip, 0)}× your bet, '
        '$retroTechMinCluster Arcade Tokens '
        '${_timesBet(RetroTechSymbol.token, 0)}× and '
        '${retroTechTiers.last.label} Arcade Tokens '
        '${_timesBet(RetroTechSymbol.token, retroTechTiers.length - 1)}×. '
        'Every cluster in every cascade is added together; a win '
        'includes the bet.',
  ),
  KfgHowToPlaySection(
    title: 'THE SYMBOLS AND THE ODDS',
    body:
        'Every symbol that drops in is drawn on its own, whatever is '
        'already on the grid. Out of every $retroTechTotalWeight, on '
        'average: ${[for (final s in RetroTechSymbol.values) '${s.weight} ${s.label}s'].join(', ')}. '
        'Nothing is weighted behind the scenes: no near misses steered your '
        'way.\n\n'
        'About 1 spin in 3 pays something and 1 in 4 pays more than the '
        'bet. About 1 spin in 14 cascades at least twice. The long-run '
        'return is about $retroTechReturnPercent% of every credit bet, the '
        'same at every bet (estimated over 20 million simulated spins); '
        'real sessions swing up and down.',
  ),
  const KfgHowToPlaySection(
    title: 'FAIR PLAY',
    body:
        'Every symbol of a spin, cascades included, is drawn when you press '
        'SPIN. The falling and cascading only show you what was drawn. Your '
        'balance, your bet and past spins never change it.',
  ),
  const KfgHowToPlaySection(
    title: 'ACHIEVEMENTS',
    body:
        'Win with Arcade Tokens or Pixel Runners, chain '
        '$retroTechChainReactionCascades or more cascades in one spin, '
        'make a cluster of $retroTechMegaClusterSize or more, and win with '
        'every symbol at least once.',
  ),
  const KfgHowToPlaySection(
    title: 'CREDITS',
    body:
        'Credits are play money shared by every game, shown at the top of '
        'the screen. They can never be bought or cashed out. If you run '
        'out, tap FREE REFILL for 1,000 more, any time. You can also reset '
        'them in Settings.',
  ),
  const KfgHowToPlaySection(
    title: 'CONTROLS',
    body:
        'Keyboard: Space or Enter spins (and stops the cascade), B bets '
        'one more level, M is max bet.',
  ),
  const KfgHowToPlaySection(
    title: 'SAVING',
    body:
        'Your bet is remembered. If you leave while a spin is playing out, '
        'it is paid in full; it is never lost or spun again.',
  ),
];

/// What a cluster pays as a multiple of the bet (whole numbers only).
String _timesBet(RetroTechSymbol symbol, int tier) =>
    formatCredits(retroTechPaytable[symbol]![tier] ~/ retroTechCreditsPerLevel);

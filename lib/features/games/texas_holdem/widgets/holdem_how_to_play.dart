import '../../../../core/widgets/kfg_how_to_play_dialog.dart';

/// Texas Hold'em's How to Play content, shown with [showKfgHowToPlayDialog].
const List<KfgHowToPlaySection> texasHoldemHowToPlaySections = [
  KfgHowToPlaySection(
    title: 'OBJECTIVE',
    body:
        'Win chips from the computer opponents. Each hand you either make '
        'everyone else fold, or reach the showdown with the best five-card '
        'poker hand made from your two cards and the five shared cards.',
  ),
  KfgHowToPlaySection(
    title: 'EACH HAND',
    body:
        '1. The two players left of the dealer button (D) post the blinds: '
        '5 and 10. Heads-up, the dealer posts the small blind.\n'
        '2. Everyone gets two face-down cards, then bets, starting left of '
        'the big blind.\n'
        '3. The flop (three shared cards), the turn (one) and the river '
        '(one) follow, each with a round of betting starting left of the '
        'button.\n'
        '4. Players still in after the river show their cards. The best '
        'hand wins the pot; equal hands split it.',
  ),
  KfgHowToPlaySection(
    title: 'YOUR OPTIONS',
    body:
        'FOLD: give up the hand (only when there is a bet to call).\n'
        'CHECK: pass when nobody has bet.\n'
        'CALL: match the current bet.\n'
        'BET / RAISE: put in more. Pick the amount with LESS and MORE (one '
        'big blind at a time), ½ POT, POT or ALL-IN.',
  ),
  KfgHowToPlaySection(
    title: 'BETTING RULES',
    body:
        'No limit: you can bet everything in front of you at any time. A '
        'bet or raise must be at least the big blind and at least as big as '
        'the last raise, unless it is all-in. An all-in too small to be a '
        'full raise doesn\'t let players who already acted raise again. A '
        'player all-in for less can only win what they matched from each '
        'opponent; the rest forms side pots. Chips nobody matched go back. '
        'In a split pot an odd chip goes to the first winner left of the '
        'button.',
  ),
  KfgHowToPlaySection(
    title: 'HAND RANKINGS',
    body:
        'From best to worst: Straight Flush (A-K-Q-J-10 of a suit is a '
        'Royal Flush), Four of a Kind, Full House, Flush, Straight, Three '
        'of a Kind, Two Pair, Pair, High Card. Aces are high, or low in '
        'A-2-3-4-5. Suits never break ties; kickers (the other cards of the '
        'best five) do.',
  ),
  KfgHowToPlaySection(
    title: 'OPPONENTS',
    body:
        'Choose 1 to 5 opponents with OPPONENTS. Each sits down with 1,000 '
        'chips; one who loses them all is replaced by a new player before '
        'the next hand. Each has a playing style (tight or loose, cautious '
        'or aggressive).\n'
        'DIFFICULTY sets how well they play. EASY: they call too much and '
        'rarely bluff. NORMAL: they bet strong hands and bluff now and '
        'then. HARD: they judge their chances more accurately, respect big '
        'bets and bluff more. Changing either seats a new table.',
  ),
  KfgHowToPlaySection(
    title: 'FAIR PLAY',
    body:
        'The deck is shuffled once, before each deal, and every card comes '
        'off it in order. Opponents see only their own cards, the shared '
        'cards and the betting, never yours or the deck, and play by the '
        'same rules as you. They estimate their chances by dealing out '
        'random hands for the cards they can\'t see. Your balance and past '
        'hands never change the cards. There is no rake: every chip in a '
        'pot goes to a player.',
  ),
  KfgHowToPlaySection(
    title: 'CREDITS',
    body:
        'Your chips are your credits, the play money shared by every game. '
        'They can never be bought or cashed out. Each hand you bring as '
        'many as the deepest opponent stack (or all you have, if less); '
        'what\'s left at the end of the hand goes straight back. If you '
        'run out, tap FREE REFILL for 1,000 more, any time between hands. '
        'You can also reset them in Settings.',
  ),
  KfgHowToPlaySection(
    title: 'CONTROLS',
    body:
        'Tap the buttons under the table. Keyboard: Space or Enter deals; '
        'on your turn F folds, C checks or calls, R bets or raises, the '
        'arrow keys (or - and +) change the amount, H picks half the pot, '
        'P the pot and A all-in.',
  ),
  KfgHowToPlaySection(
    title: 'SAVING',
    body:
        'The table is saved after every action. Leave mid-hand and you\'ll '
        'come back to the same cards, never a new deal. The opponents keep '
        'their chips between visits.',
  ),
];

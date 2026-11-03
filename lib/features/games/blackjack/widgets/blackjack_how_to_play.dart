import '../../../../core/widgets/kfg_how_to_play_dialog.dart';
import '../logic/blackjack_game.dart';

/// Blackjack's How to Play content, shown with [showKfgHowToPlayDialog].
/// The return quoted here is checked by `tools/blackjack/return_check.dart`.
const List<KfgHowToPlaySection> blackjackHowToPlaySections = [
  KfgHowToPlaySection(
    title: 'OBJECTIVE',
    body:
        'Beat the dealer by finishing closer to 21 without going over. '
        'Cards 2–10 count their number, Jacks, Queens and Kings count 10, '
        'and an Ace counts 1 or 11, whichever helps. A hand with an Ace '
        'counted as 11 is "soft".',
  ),
  KfgHowToPlaySection(
    title: 'EACH ROUND',
    body:
        '1. Build your bet with the chips (10 to 1,000, in steps of 10), '
        'then press DEAL. CLEAR sets it back to 10. Your bet stays for the '
        'next round.\n'
        '2. You and the dealer get two cards each; one of the dealer\'s is '
        'face down.\n'
        '3. Play your hand, then the dealer turns the hidden card and plays '
        'by the house rules below.',
  ),
  KfgHowToPlaySection(
    title: 'YOUR OPTIONS',
    body:
        'HIT: take another card. Go over 21 and you bust and lose.\n'
        'STAND: keep what you have.\n'
        'DOUBLE: on your first two cards, double your bet and take exactly '
        'one more card.\n'
        'SPLIT: with two cards of the same rank, add an equal bet and play '
        'them as two hands. You can split up to four hands and double after '
        'a split. Split Aces get one card each and can\'t be split again, '
        'and 21 after a split counts as 21, not blackjack.\n'
        'SURRENDER: on your first two cards, give up the hand and get half '
        'your bet back.\n'
        'INSURANCE: when the dealer shows an Ace, you can bet half your bet '
        'that the dealer has blackjack.',
  ),
  KfgHowToPlaySection(
    title: 'HOUSE RULES',
    body:
        'Six decks, shuffled together into one shoe. The dealer must hit '
        'below 17 and stands on every 17, soft 17 included. With an Ace or '
        'a ten-value card showing, the dealer checks for blackjack before '
        'you play, so you never lose more than your bet to a dealer '
        'blackjack. A fresh shoe is shuffled before a round once fewer than '
        '78 cards (a quarter of the shoe) are left.',
  ),
  KfgHowToPlaySection(
    title: 'PAYOUTS',
    body:
        'Blackjack (an Ace and a ten-value card as your first two cards) '
        'pays 3:2: a 10 bet wins 15. A win pays 1:1. A tie is a push and '
        'your bet comes back. Insurance pays 2:1. Surrender returns half '
        'your bet.',
  ),
  KfgHowToPlaySection(
    title: 'RETURN',
    body:
        'With perfect basic strategy these rules return about '
        '$blackjackReturnPercent% of what you bet over the long run (a '
        'house edge of about 0.35%). Guessing or always taking insurance '
        'returns less. Real sessions swing up and down.',
  ),
  KfgHowToPlaySection(
    title: 'FAIR PLAY',
    body:
        'Every card comes from the shoe in the order it was shuffled. The '
        'dealer has no choices: it follows the house rules above. Your '
        'balance, your bet and past rounds never change the cards.',
  ),
  KfgHowToPlaySection(
    title: 'CREDITS',
    body:
        'Credits are play money shared by every game, shown at the top of '
        'the screen. They can never be bought or cashed out. Doubling, '
        'splitting and insurance each need enough credits to cover them. '
        'If you run out, tap FREE REFILL for 1,000 more, any time. You can '
        'also reset them in Settings.',
  ),
  KfgHowToPlaySection(
    title: 'CONTROLS',
    body:
        'Tap the buttons under the table. Keyboard: 1–4 add a 10, 50, 100 '
        'or 500 chip, C clears the bet, Space or Enter deals. In play, H '
        'hits, S stands, D doubles, P splits and R surrenders; I takes '
        'insurance and N declines it.',
  ),
  KfgHowToPlaySection(
    title: 'SAVING',
    body:
        'A round in play is saved after every move. Leave any time and '
        'you\'ll come back to the same cards and the same shoe, never a '
        'new deal.',
  ),
];

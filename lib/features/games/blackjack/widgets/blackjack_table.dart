import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/cards/animated_playing_card.dart';
import '../../../../core/cards/playing_card.dart';
import '../../../../core/services/credits_service.dart';
import '../logic/blackjack_game.dart';
import '../logic/blackjack_hand.dart';

/// The felt: the dealer's cards on top, the player's hand (or split hands
/// side by side) below. Sizes its cards to whatever space it is given.
class BlackjackTable extends StatelessWidget {
  const BlackjackTable({
    super.key,
    required this.game,
    required this.roundToken,
  });

  final BlackjackGame game;

  /// Changes every deal, so each round's cards slide in once.
  final int roundToken;

  static const double _labelHeight = 20;
  static const double _tagHeight = 20;
  static const double _gap = 8;

  /// Between the dealer and the player.
  static const double _tableGap = 20;

  /// A hand's label, tag and panel padding around its cards.
  static const double _handChrome = _labelHeight + 4 + _tagHeight + 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final handCount = max(1, game.hands.length);
        final handWidth = (width - _gap * (handCount - 1)) / handCount;
        // Both rows of cards share the height left after the labels.
        final cardHeight =
            (height - _labelHeight - _tableGap - _handChrome) / 2;
        final cardWidth = [
          cardHeight / 1.4,
          handWidth / 1.5,
          width / 3.6,
        ].reduce(min);
        // The table sits in the middle of the space it is given.
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDealer(cardWidth, width),
              const SizedBox(height: _tableGap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (game.hands.isEmpty)
                    _EmptyHand(cardWidth: cardWidth, bet: game.bet),
                  for (var i = 0; i < game.hands.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    SizedBox(
                      width: handWidth,
                      child: _HandPanel(
                        index: i,
                        game: game,
                        cardWidth: cardWidth,
                        roundToken: roundToken,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDealer(double cardWidth, double width) {
    final dealer = game.dealer;
    final String total;
    if (dealer.isEmpty) {
      total = '';
    } else if (game.holeCardRevealed) {
      total = '${game.dealerTotal}';
    } else {
      total = 'shows ${game.dealerVisibleTotal}';
    }
    final semantics = dealer.isEmpty
        ? 'Dealer: no cards yet'
        : 'Dealer: ${_cardList(dealer)}. '
              '${game.holeCardRevealed ? 'Total ${game.dealerTotal}' : 'Showing ${game.dealerVisibleTotal}'}'
              '${game.isComplete && game.dealerBust ? ', bust' : ''}.';
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _labelHeight,
            child: _Label(
              title: 'DEALER',
              detail: game.isComplete && game.dealerBust
                  ? '$total · BUST'
                  : total,
              color: KfgColors.secondary,
            ),
          ),
          if (dealer.isEmpty)
            SizedBox(height: cardWidth * 1.4)
          else
            _CardFan(
              cards: dealer,
              cardWidth: cardWidth,
              maxWidth: width,
              roundToken: roundToken,
            ),
        ],
      ),
    );
  }
}

String _cardList(List<PlayingCard> cards) => [
  for (final c in cards) c.faceUp ? c.faceUpLabel : 'a face-down card',
].join(', ');

class _HandPanel extends StatelessWidget {
  const _HandPanel({
    required this.index,
    required this.game,
    required this.cardWidth,
    required this.roundToken,
  });

  final int index;
  final BlackjackGame game;
  final double cardWidth;
  final int roundToken;

  @override
  Widget build(BuildContext context) {
    final hand = game.hands[index];
    final active =
        game.phase == BlackjackPhase.playerTurn && game.activeIndex == index;
    final outcome = game.isComplete ? game.outcomeOf(hand) : null;
    final multi = game.hands.length > 1;
    final title = multi ? 'HAND ${index + 1}' : 'YOU';
    final total = hand.cards.length < 2 && multi
        ? ''
        : '${hand.isSoft && !game.isComplete && !hand.isDone ? 'soft ' : ''}'
              '${hand.total}';
    final tag = _tag(hand, outcome);
    final label = StringBuffer(
      '${multi ? 'Hand ${index + 1} of ${game.hands.length}' : 'Your hand'}: '
      '${_cardList(hand.cards)}. Total ${hand.total}. '
      'Bet ${formatCredits(hand.bet)}${hand.doubled ? ', doubled' : ''}.',
    );
    if (active) label.write(' Your turn.');
    if (tag != null) label.write(' ${tag.$1}.');

    return Semantics(
      container: true,
      label: label.toString(),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? KfgColors.primary : Colors.transparent,
            width: 1.5,
          ),
          color: active ? KfgColors.primary.withValues(alpha: 0.06) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: BlackjackTable._labelHeight,
                child: _Label(
                  title: title,
                  detail: total,
                  color: active ? KfgColors.primary : KfgColors.textSecondary,
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => _CardFan(
                  cards: hand.cards,
                  cardWidth: min(cardWidth, constraints.maxWidth),
                  maxWidth: constraints.maxWidth,
                  roundToken: roundToken,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: BlackjackTable._tagHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: tag == null
                      ? Text(
                          'BET ${formatCredits(hand.bet)}'
                          '${hand.doubled ? ' ×2' : ''}',
                          style: const TextStyle(
                            color: KfgColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        )
                      : _OutcomeTag(text: tag.$1, color: tag.$2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The tag under a finished hand, or null to show its bet.
  (String, Color)? _tag(BlackjackHand hand, BlackjackOutcome? outcome) {
    if (outcome == null) {
      if (hand.isBust) return ('BUST', KfgColors.error);
      return null;
    }
    final pays = game.payoutOf(hand);
    return switch (outcome) {
      BlackjackOutcome.blackjack => (
        'BLACKJACK +${formatCredits(pays)}',
        KfgColors.warning,
      ),
      BlackjackOutcome.win => (
        'WIN +${formatCredits(pays)}',
        KfgColors.highlight,
      ),
      BlackjackOutcome.push => ('PUSH', KfgColors.textSecondary),
      BlackjackOutcome.lose => ('LOSE', KfgColors.error),
      BlackjackOutcome.bust => ('BUST', KfgColors.error),
      BlackjackOutcome.surrender => (
        'SURRENDER +${formatCredits(pays)}',
        KfgColors.textSecondary,
      ),
    };
  }
}

/// Before the first deal: an outline where the hand will go.
class _EmptyHand extends StatelessWidget {
  const _EmptyHand({required this.cardWidth, required this.bet});

  final double cardWidth;
  final int bet;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: BlackjackTable._labelHeight,
          child: _Label(
            title: 'YOU',
            detail: '',
            color: KfgColors.textSecondary,
          ),
        ),
        AnimatedPlayingCard(
          width: cardWidth,
          height: cardWidth * 1.4,
          card: null,
          selected: false,
          highlighted: false,
          emptyHint: null,
        ),
        const SizedBox(height: 4 + BlackjackTable._tagHeight),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.title,
    required this.detail,
    required this.color,
  });

  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            if (detail.isNotEmpty)
              TextSpan(
                text: '  ${detail.toUpperCase()}',
                style: const TextStyle(
                  color: KfgColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OutcomeTag extends StatelessWidget {
  const _OutcomeTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Cards overlapped left to right, spreading as far as [maxWidth] allows.
class _CardFan extends StatelessWidget {
  const _CardFan({
    required this.cards,
    required this.cardWidth,
    required this.maxWidth,
    required this.roundToken,
  });

  final List<PlayingCard> cards;
  final double cardWidth;
  final double maxWidth;
  final int roundToken;

  @override
  Widget build(BuildContext context) {
    final cardHeight = cardWidth * 1.4;
    final n = cards.length;
    final step = n < 2
        ? 0.0
        : min(cardWidth * 0.55, (maxWidth - cardWidth) / (n - 1));
    return SizedBox(
      width: cardWidth + step * (n - 1),
      height: cardHeight,
      child: Stack(
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: step * i,
              top: 0,
              child: AnimatedPlayingCard(
                width: cardWidth,
                height: cardHeight,
                card: cards[i],
                selected: false,
                highlighted: false,
                emptyHint: null,
                showStatusBadges: false,
                // Ids repeat in a six-deck shoe, but never within one
                // position of one round, so a new card animates once.
                animationCue: CardAnimationCue(
                  token: roundToken,
                  beginOffset: const Offset(0, -0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/kfg_theme.dart';
import '../../../../core/cards/animated_playing_card.dart';
import '../../../../core/cards/playing_card.dart';
import '../../../../core/services/credits_service.dart';
import '../logic/holdem_evaluator.dart';
import '../logic/holdem_hand.dart';
import '../logic/holdem_table.dart';

/// The table: a neon oval with the opponents around the rim, the board and
/// pot in the middle and the player's seat at the bottom. Sizes everything
/// to the space it is given.
class HoldemTableView extends StatelessWidget {
  const HoldemTableView({
    super.key,
    required this.table,
    required this.handToken,
    required this.nextStake,
  });

  final HoldemTable table;

  /// Changes every deal, so each hand's cards slide in once.
  final int handToken;

  /// The player's chips shown between hands.
  final int nextStake;

  /// Opponent seats' angles around the oval, clockwise from the player at
  /// the bottom (0°), by number of opponents. Side seats sit clearly above
  /// or below the board rather than level with it.
  static const Map<int, List<double>> _angles = {
    1: [180],
    2: [128, 232],
    3: [52, 180, 308],
    4: [52, 140, 220, 308],
    5: [52, 128, 180, 232, 308],
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final wide = w > h * 1.15;
        final seatW = (wide ? w * 0.16 : w * 0.23).clamp(64.0, 150.0);
        final seatH = min(seatW * 0.95, h * 0.24);
        final playerW = min(seatW * 1.4, w * 0.45);
        final playerH = min(seatH * 1.25, h * 0.32);

        // The rim the opponent seats sit on, clear of the player's seat.
        final rx = w / 2 - seatW / 2 - 2;
        final top = seatH / 2 + 2;
        final bottom = h - playerH / 2 - 2;
        final cx = w / 2;
        final cy = (top + bottom) / 2;
        final ry = (bottom - top) / 2;
        final center = Offset(cx, cy);

        Offset rim(double degrees) {
          final a = degrees * pi / 180;
          return Offset(cx - rx * sin(a), cy + ry * cos(a));
        }

        final hand = table.hand;
        final angles = _angles[table.opponents.length]!;
        final highlights = _winningCards(hand);
        // The board fits the oval, and the gap between any seats level
        // with it (five cards and their spacing are 5.5 card widths; the pot
        // label adds about 30 px).
        var boardCardW = min(
          min((rx * 1.6) / 5.5, (ry * 0.8) / 1.4 / 1.6),
          seatW * 0.6,
        );
        for (final angle in angles) {
          final seat = rim(angle);
          final boardHalfH = (boardCardW * 1.4 + 30) / 2;
          if ((seat.dy - cy).abs() < seatH / 2 + boardHalfH + 2) {
            final halfGap = (seat.dx - cx).abs() - seatW / 2 - 4;
            boardCardW = min(boardCardW, max(14.0, halfGap * 2 / 5.5));
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FeltPainter(
                  center: center,
                  rx: rx * 0.84,
                  ry: ry * 0.8,
                ),
              ),
            ),
            _place(
              center,
              _Board(
                hand: hand,
                cardWidth: boardCardW,
                handToken: handToken,
                highlights: highlights,
              ),
            ),
            for (var i = 0; i < table.opponents.length; i++)
              _place(
                rim(angles[i]),
                SizedBox(
                  width: seatW,
                  height: seatH,
                  child: _OpponentSeat(
                    table: table,
                    seat: i + 1,
                    handToken: handToken,
                    highlights: highlights,
                  ),
                ),
              ),
            _place(
              Offset(cx, bottom),
              SizedBox(
                width: playerW,
                height: playerH,
                child: _PlayerSeat(
                  table: table,
                  nextStake: nextStake,
                  handToken: handToken,
                  highlights: highlights,
                ),
              ),
            ),
            // Bets on each seat's edge (drawn over the seats), swept into the
            // pot at the end.
            if (hand != null && hand.isInPlay)
              for (var seat = 0; seat < hand.seatCount; seat++)
                if (hand.seats[seat].streetBet > 0)
                  _place(
                    seat == 0
                        ? Offset(cx, bottom - playerH / 2 - 2)
                        : _besideSeat(
                            rim(angles[seat - 1]),
                            center,
                            seatW,
                            seatH,
                          ),
                    _BetChip(amount: hand.seats[seat].streetBet),
                  ),
          ],
        );
      },
    );
  }

  /// On the border of a [w]×[h] seat centred on [seat], facing [to]: where
  /// that line leaves the seat's box. Seats never overlap the board, so a
  /// chip there never covers it.
  static Offset _besideSeat(Offset seat, Offset to, double w, double h) {
    final d = to - seat;
    if (d.distance == 0) return to;
    final u = d / d.distance;
    final exit = min(
      u.dx.abs() < 1e-6 ? double.infinity : (w / 2) / u.dx.abs(),
      u.dy.abs() < 1e-6 ? double.infinity : (h / 2) / u.dy.abs(),
    );
    final distance = min(exit + 2, d.distance);
    return seat + u * distance;
  }

  /// Centres [child] on [at].
  static Widget _place(Offset at, Widget child) {
    return Positioned(
      left: at.dx,
      top: at.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );
  }

  /// The ids of the cards making the main pot's winning hand at a showdown.
  static Set<String> _winningCards(HoldemHand? hand) {
    if (hand == null || !hand.isComplete || !hand.showdown) return const {};
    return {
      for (final w in hand.pots.first.winners)
        for (final c in holdemBestFive([...hand.seats[w].hole, ...hand.board]))
          c.id,
    };
  }
}

class _FeltPainter extends CustomPainter {
  const _FeltPainter({
    required this.center,
    required this.rx,
    required this.ry,
  });

  final Offset center;
  final double rx;
  final double ry;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
    canvas.drawOval(
      oval,
      Paint()
        ..shader = RadialGradient(
          colors: [
            KfgColors.surfaceVariant,
            KfgColors.surface,
            KfgColors.background,
          ],
          stops: const [0, 0.75, 1],
        ).createShader(oval),
    );
    // A soft glow under a crisp neon rim, and a faint inner line.
    canvas.drawOval(
      oval,
      Paint()
        ..color = KfgColors.primary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = KfgColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawOval(
      oval.deflate(min(rx, ry) * 0.12),
      Paint()
        ..color = KfgColors.secondary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FeltPainter old) =>
      old.center != center || old.rx != rx || old.ry != ry;
}

/// The pot and the five community card places.
class _Board extends StatelessWidget {
  const _Board({
    required this.hand,
    required this.cardWidth,
    required this.handToken,
    required this.highlights,
  });

  final HoldemHand? hand;
  final double cardWidth;
  final int handToken;
  final Set<String> highlights;

  @override
  Widget build(BuildContext context) {
    final board = hand?.board ?? const <PlayingCard>[];
    final pot = hand?.pot ?? 0;
    final label = board.isEmpty
        ? 'No community cards yet'
        : 'Board: ${board.map((c) => c.faceUpLabel).join(', ')}';
    return Semantics(
      container: true,
      label: 'Pot ${formatCredits(pot)}. $label.',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: KfgColors.background.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: KfgColors.warning.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              'POT ${formatCredits(pot)}',
              style: const TextStyle(
                color: KfgColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: cardWidth * 0.15),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: cardWidth * 0.05),
                  child: AnimatedPlayingCard(
                    width: cardWidth,
                    height: cardWidth * 1.4,
                    card: i < board.length ? board[i] : null,
                    selected: false,
                    highlighted:
                        i < board.length && highlights.contains(board[i].id),
                    emptyHint: null,
                    showStatusBadges: false,
                    animationCue: CardAnimationCue(
                      token: handToken,
                      beginOffset: const Offset(0, -0.4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BetChip extends StatelessWidget {
  const _BetChip({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: KfgColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: KfgColors.highlight.withValues(alpha: 0.8)),
      ),
      child: Text(
        formatCredits(amount),
        style: const TextStyle(
          color: KfgColors.highlight,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// The tag under a seat: its last move this round or how the hand ended.
(String, Color)? _seatTag(HoldemHand? hand, int seat) {
  if (hand == null) return null;
  final s = hand.seats[seat];
  if (hand.isComplete) {
    final won = hand.winnings[seat] - s.committed;
    if (hand.pots.any((p) => p.winners.contains(seat))) {
      return ('WIN +${formatCredits(max(0, won))}', KfgColors.warning);
    }
    if (s.folded) return ('FOLD', KfgColors.textMuted);
    if (s.stack == 0) return ('OUT', KfgColors.error);
    return null;
  }
  if (s.folded) return ('FOLD', KfgColors.textMuted);
  if (s.isAllIn) return ('ALL-IN', KfgColors.secondary);
  final move = s.lastMove;
  if (move == null) return null;
  final amount = formatCredits(s.streetBet);
  return switch (move) {
    HoldemMove.smallBlind => ('SB', KfgColors.textSecondary),
    HoldemMove.bigBlind => ('BB', KfgColors.textSecondary),
    HoldemMove.check => ('CHECK', KfgColors.textSecondary),
    HoldemMove.call => ('CALL', KfgColors.primary),
    HoldemMove.bet => ('BET $amount', KfgColors.highlight),
    HoldemMove.raise => ('RAISE $amount', KfgColors.highlight),
    HoldemMove.allIn => ('ALL-IN', KfgColors.secondary),
    HoldemMove.fold => ('FOLD', KfgColors.textMuted),
  };
}

String _moveWords(HoldemHand? hand, int seat) {
  final tag = _seatTag(hand, seat);
  return tag == null ? '' : ' ${tag.$1.toLowerCase()}.';
}

/// The neon box every seat is drawn in.
class _SeatFrame extends StatelessWidget {
  const _SeatFrame({
    required this.active,
    required this.dimmed,
    required this.won,
    required this.child,
  });

  final bool active;
  final bool dimmed;
  final bool won;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = won
        ? KfgColors.warning
        : active
        ? KfgColors.primary
        : KfgColors.cardBorder;
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: KfgColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: active || won ? 1.8 : 1),
          boxShadow: [
            if (active || won)
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: child,
      ),
    );
  }
}

class _DealerButton extends StatelessWidget {
  const _DealerButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KfgColors.textPrimary,
        border: Border.all(color: KfgColors.primary, width: 1.5),
      ),
      child: const Text(
        'D',
        style: TextStyle(
          color: KfgColors.background,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SeatTag extends StatelessWidget {
  const _SeatTag({required this.tag});

  final (String, Color)? tag;

  @override
  Widget build(BuildContext context) {
    final t = tag;
    if (t == null) return const SizedBox.shrink();
    return Text(
      t.$1,
      maxLines: 1,
      style: TextStyle(
        color: t.$2,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _OpponentSeat extends StatelessWidget {
  const _OpponentSeat({
    required this.table,
    required this.seat,
    required this.handToken,
    required this.highlights,
  });

  final HoldemTable table;
  final int seat;
  final int handToken;
  final Set<String> highlights;

  @override
  Widget build(BuildContext context) {
    final opponent = table.opponents[seat - 1];
    final hand = table.hand;
    final s = hand?.seats[seat];
    final stack = s?.stack ?? opponent.stack;
    final active = hand != null && hand.toAct == seat;
    final revealed = hand != null && hand.isRevealed(seat);
    final won =
        hand != null &&
        hand.isComplete &&
        hand.pots.any((p) => p.winners.contains(seat));
    final showCards = s != null && !s.folded;
    final tag = _seatTag(hand, seat);
    final buttonHere = hand != null && hand.button == seat;

    final label = StringBuffer(
      '${opponent.name}: ${formatCredits(stack)} chips.',
    );
    if (buttonHere) label.write(' Dealer.');
    if (s != null && s.streetBet > 0) {
      label.write(' Bet ${formatCredits(s.streetBet)}.');
    }
    if (revealed) {
      label.write(
        ' Shows ${s!.hole.map((c) => c.faceUpLabel).join(' and ')}: '
        '${holdemHandName(hand.scoreOf(seat))}.',
      );
    }
    label.write(_moveWords(hand, seat));
    if (active) label.write(' To act.');

    return Semantics(
      container: true,
      label: label.toString(),
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _SeatFrame(
              active: active,
              dimmed: s?.folded ?? false,
              won: won,
              child: LayoutBuilder(
                builder: (context, box) {
                  final cardW = box.maxWidth * 0.36;
                  return Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          opponent.name.toUpperCase(),
                          style: TextStyle(
                            color: active
                                ? KfgColors.primary
                                : KfgColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      // The cards take whatever height the two text rows
                      // leave.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, space) {
                            final w = min(cardW, space.maxHeight / 1.4);
                            if (!showCards || w <= 0) {
                              return const SizedBox.expand();
                            }
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final c in s.hole)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    child: AnimatedPlayingCard(
                                      width: w,
                                      height: w * 1.4,
                                      card: c.copyWith(faceUp: revealed),
                                      selected: false,
                                      highlighted: highlights.contains(c.id),
                                      emptyHint: null,
                                      showStatusBadges: false,
                                      animationCue: CardAnimationCue(
                                        token: handToken,
                                        beginOffset: const Offset(0, 0.4),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: tag == null
                            ? Text(
                                formatCredits(stack),
                                style: const TextStyle(
                                  color: KfgColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${formatCredits(stack)} · ',
                                    style: const TextStyle(
                                      color: KfgColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  _SeatTag(tag: tag),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (buttonHere)
            const Positioned(right: -6, top: -6, child: _DealerButton()),
        ],
      ),
    );
  }
}

class _PlayerSeat extends StatelessWidget {
  const _PlayerSeat({
    required this.table,
    required this.nextStake,
    required this.handToken,
    required this.highlights,
  });

  final HoldemTable table;
  final int nextStake;
  final int handToken;
  final Set<String> highlights;

  @override
  Widget build(BuildContext context) {
    final hand = table.hand;
    final s = hand?.seats[0];
    final inHand = hand != null && hand.isInPlay;
    final stack = inHand ? s!.stack : nextStake;
    final active = hand != null && hand.toAct == 0;
    final won =
        hand != null &&
        hand.isComplete &&
        hand.pots.any((p) => p.winners.contains(0));
    final tag = _seatTag(hand, 0);
    final buttonHere = hand != null && hand.button == 0;
    final cards = s?.hole ?? const <PlayingCard>[];
    final made = inHand && !s!.folded && hand.board.length >= 3
        ? holdemHandName(hand.scoreOf(0))
        : null;

    final label = StringBuffer('You: ${formatCredits(stack)} chips.');
    if (buttonHere) label.write(' Dealer.');
    if (cards.isNotEmpty) {
      label.write(
        ' Your cards: ${cards.map((c) => c.faceUpLabel).join(' and ')}.',
      );
    }
    if (made != null) label.write(' $made.');
    label.write(_moveWords(hand, 0));
    if (active) label.write(' Your turn.');

    return Semantics(
      container: true,
      label: label.toString(),
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _SeatFrame(
              active: active,
              dimmed: s?.folded ?? false,
              won: won,
              child: LayoutBuilder(
                builder: (context, box) {
                  final cardW = min(
                    box.maxWidth * 0.3,
                    (box.maxHeight - 2) / 1.4,
                  );
                  return Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: active
                                        ? KfgColors.primary
                                        : KfgColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatCredits(stack),
                                  style: const TextStyle(
                                    color: KfgColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (tag != null)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _SeatTag(tag: tag),
                                ),
                              if (made != null)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    made.toUpperCase(),
                                    style: const TextStyle(
                                      color: KfgColors.textMuted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      for (var i = 0; i < 2; i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: AnimatedPlayingCard(
                            width: cardW,
                            height: cardW * 1.4,
                            card: i < cards.length
                                ? cards[i].copyWith(faceUp: true)
                                : null,
                            selected: false,
                            highlighted:
                                i < cards.length &&
                                highlights.contains(cards[i].id),
                            emptyHint: null,
                            showStatusBadges: false,
                            animationCue: CardAnimationCue(
                              token: handToken,
                              beginOffset: const Offset(0, 0.4),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (buttonHere)
            const Positioned(left: -6, top: -6, child: _DealerButton()),
        ],
      ),
    );
  }
}

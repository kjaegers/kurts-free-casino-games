import 'package:flutter/material.dart';

import '../animation/kfg_web_animation_speed.dart';
import 'playing_card.dart';
import 'playing_card_widget.dart';

class CardAnimationCue {
  const CardAnimationCue({required this.token, required this.beginOffset});

  final int token;
  final Offset beginOffset;
}

class AnimatedPlayingCard extends StatelessWidget {
  const AnimatedPlayingCard({
    super.key,
    required this.width,
    required this.height,
    required this.card,
    required this.selected,
    required this.highlighted,
    required this.emptyHint,
    this.animationCue,
    this.semanticLabel,
    this.semanticHint,
    this.isInteractive = false,
    this.faceRedColor,
    this.faceBlackColor,
    this.showStatusBadges = true,
  });

  final double width;
  final double height;
  final PlayingCard? card;
  final bool selected;
  final bool highlighted;
  final String? emptyHint;
  final CardAnimationCue? animationCue;
  final String? semanticLabel;
  final String? semanticHint;
  final bool isInteractive;
  final Color? faceRedColor;
  final Color? faceBlackColor;

  /// See [PlayingCardWidget.showStatusBadges].
  final bool showStatusBadges;

  @override
  Widget build(BuildContext context) {
    final core = _buildFlipAnimatedCard();

    if (card == null || animationCue == null) {
      return core;
    }

    final cue = animationCue!;
    return TweenAnimationBuilder<Offset>(
      key: ValueKey<String>('${card!.id}:${cue.token}'),
      tween: Tween<Offset>(begin: cue.beginOffset, end: Offset.zero),
      duration: kfgAnimDuration(const Duration(milliseconds: 220)),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) {
        final opacity = (1 - (offset.distance * 0.35)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(offset.dx * width, offset.dy * height),
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: core,
    );
  }

  Widget _buildFlipAnimatedCard() {
    Widget buildCardFace() {
      return SizedBox(
        width: width,
        height: height,
        child: PlayingCardWidget(
          width: width,
          height: height,
          card: card,
          selected: selected,
          highlighted: highlighted,
          emptyHint: emptyHint,
          semanticLabel: semanticLabel,
          semanticHint: semanticHint,
          isInteractive: isInteractive,
          faceRedColor: faceRedColor,
          faceBlackColor: faceBlackColor,
          showStatusBadges: showStatusBadges,
        ),
      );
    }

    final front = buildCardFace();

    if (card == null) {
      return front;
    }

    return SizedBox(
      width: width,
      height: height,
      child: AnimatedSwitcher(
        duration: kfgAnimDuration(const Duration(milliseconds: 150)),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              ...<Widget?>[currentChild].whereType<Widget>(),
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<String>('${card!.id}:${card!.faceUp ? 'up' : 'down'}'),
          child: buildCardFace(),
        ),
      ),
    );
  }
}

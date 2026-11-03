import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/kfg_theme.dart';
import '../animation/kfg_web_animation_speed.dart';
import 'playing_card.dart';

class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    super.key,
    required this.width,
    required this.height,
    this.card,
    this.selected = false,
    this.highlighted = false,
    this.emptyHint,
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
  final String? semanticLabel;
  final String? semanticHint;
  final bool isInteractive;
  final Color? faceRedColor;
  final Color? faceBlackColor;

  /// Shows the SEL / DROP badges for [selected] / [highlighted]. Turn off
  /// when the game labels the state itself (e.g. a HELD tag), keeping the
  /// glowing border.
  final bool showStatusBadges;

  /// Card face background. The rank and suit colours below keep at least
  /// 4.5:1 contrast against it.
  static const Color faceBackground = Color(0xFFE7F9FF);
  static const Color defaultRed = Color(0xFFB00020);
  static const Color defaultBlack = Color(0xFF111111);

  /// Ink for a joker's face (also ≥4.5:1 against [faceBackground]).
  static const Color jokerColor = Color(0xFF6A1B9A);

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? KfgColors.primary
        : highlighted
        ? KfgColors.secondary
        : KfgColors.cardBorder;
    final borderWidth = selected || highlighted ? 2.0 : 1.0;
    final resolvedSemantics = semanticLabel ?? _defaultSemanticLabel();

    return Semantics(
      label: resolvedSemantics,
      hint: semanticHint,
      button: isInteractive,
      selected: selected,
      enabled: isInteractive,
      child: AnimatedContainer(
        duration: kfgAnimDuration(const Duration(milliseconds: 120)),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _backgroundColor(),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: selected || highlighted
              ? [
                  BoxShadow(
                    color: (selected ? KfgColors.primary : KfgColors.secondary)
                        .withValues(alpha: 0.30),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (card == null) {
      return Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KfgColors.surfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (emptyHint != null)
            Center(
              child: Text(
                emptyHint!,
                style: const TextStyle(
                  color: KfgColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      );
    }

    if (!card!.faceUp) {
      return Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF031A2D),
                    Color(0xFF0B3558),
                    Color(0xFF102840),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: KfgColors.primary.withValues(alpha: 0.6),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _CardBackPainter())),
          const Center(
            child: Icon(Icons.auto_awesome, color: KfgColors.primary, size: 20),
          ),
        ],
      );
    }

    final cornerFontSize = (width * 0.22).clamp(9.0, 20.0).toDouble();
    final centerFontSize = (width * 0.62).clamp(18.0, 56.0).toDouble();
    if (card!.isJoker) return _buildJokerFace(cornerFontSize, centerFontSize);

    final symbol = _suitSymbol(card!.suit);
    final color = _faceColor(card!);
    final cornerStyle = TextStyle(
      color: color,
      fontSize: cornerFontSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: faceBackground),
          ),
        ),
        Center(
          child: Text(
            symbol,
            style: TextStyle(
              color: color.withValues(alpha: 0.32),
              fontSize: centerFontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _buildCornerLabel(
          text: '${card!.rank.label}$symbol',
          style: cornerStyle,
          top: 4,
          left: 5,
        ),
        _buildCornerLabel(
          text: '${card!.rank.label}$symbol',
          style: cornerStyle,
          bottom: 4,
          right: 5,
          rotate180: true,
        ),
        ..._statusBadges(),
      ],
    );
  }

  Widget _buildJokerFace(double cornerFontSize, double centerFontSize) {
    final cornerStyle = TextStyle(
      color: jokerColor,
      fontSize: cornerFontSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: faceBackground),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.1,
              vertical: height * 0.18,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: jokerColor, size: centerFontSize),
                  Text(
                    'JOKER',
                    maxLines: 1,
                    style: TextStyle(
                      color: jokerColor,
                      fontSize: cornerFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildCornerLabel(text: 'JKR', style: cornerStyle, top: 4, left: 5),
        _buildCornerLabel(
          text: 'JKR',
          style: cornerStyle,
          bottom: 4,
          right: 5,
          rotate180: true,
        ),
        ..._statusBadges(),
      ],
    );
  }

  List<Widget> _statusBadges() {
    if (!showStatusBadges) return const [];
    return [
      if (selected)
        _StatusBadge(
          alignment: Alignment.topRight,
          label: width >= 48 ? 'SEL' : 'S',
          icon: Icons.check_circle,
          background: const Color(0xFF0D2A43),
          foreground: const Color(0xFFE7F9FF),
          maxWidth: width - 8,
        ),
      if (highlighted)
        _StatusBadge(
          alignment: Alignment.bottomCenter,
          label: width >= 48 ? 'DROP' : 'D',
          icon: Icons.touch_app,
          background: const Color(0xFF5A1036),
          foreground: const Color(0xFFFFF4F9),
          maxWidth: width - 8,
        ),
    ];
  }

  Widget _buildCornerLabel({
    required String text,
    required TextStyle style,
    double? top,
    double? left,
    double? bottom,
    double? right,
    bool rotate180 = false,
  }) {
    final cornerChild = SizedBox(
      width: width * 0.44,
      height: width * 0.30,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: style,
        ),
      ),
    );

    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: rotate180
          ? Transform.rotate(angle: math.pi, child: cornerChild)
          : cornerChild,
    );
  }

  Color _backgroundColor() {
    if (card == null) return Colors.transparent;
    return card!.faceUp ? faceBackground : const Color(0xFF0A233A);
  }

  Color _faceColor(PlayingCard card) {
    if (card.color == CardColor.red) {
      return faceRedColor ?? defaultRed;
    }
    return faceBlackColor ?? defaultBlack;
  }

  String _defaultSemanticLabel() {
    final currentCard = card;
    if (currentCard == null) {
      if (emptyHint == null || emptyHint!.isEmpty) {
        return 'Empty card slot';
      }
      return 'Empty slot, hint $emptyHint';
    }

    if (!currentCard.faceUp) {
      return 'Face-down card';
    }

    return currentCard.faceUpLabel;
  }

  static String _suitSymbol(CardSuit suit) {
    return switch (suit) {
      CardSuit.hearts => '♥',
      CardSuit.diamonds => '♦',
      CardSuit.clubs => '♣',
      CardSuit.spades => '♠',
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.alignment,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.maxWidth,
  });

  final Alignment alignment;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRect(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth.clamp(16, 240)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: foreground.withValues(alpha: 0.9)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 10, color: foreground),
                      const SizedBox(width: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..strokeWidth = 1;

    const step = 8.0;
    for (double y = -size.height; y < size.height * 2; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter oldDelegate) => false;
}

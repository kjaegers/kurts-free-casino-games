import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/kfg_theme.dart';
import '../../../core/animation/kfg_web_animation_speed.dart';
import '../../../core/cards/animated_playing_card.dart';
import '../../../core/layout/kfg_scaled_game_layout.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/widgets/kfg_credits_badge.dart';
import '../../../core/widgets/kfg_how_to_play_dialog.dart';
import '../../../core/widgets/kfg_sound_toggle_button.dart';
import 'logic/video_poker_game.dart';
import 'logic/video_poker_variant.dart';
import 'video_poker_save_service.dart';
import 'video_poker_screen_controller.dart';
import 'widgets/video_poker_controls.dart';
import 'widgets/video_poker_how_to_play.dart';
import 'widgets/video_poker_paytable.dart';
import 'widgets/video_poker_variant_dialog.dart';

class VideoPokerScreen extends StatefulWidget {
  const VideoPokerScreen({
    super.key,
    this.saveService,
    this.credits,
    this.shuffleDeck,
  });

  @visibleForTesting
  final VideoPokerSaveService? saveService;

  @visibleForTesting
  final CreditsService? credits;

  /// Replaces the fair shuffle, so widget tests can deal known cards.
  @visibleForTesting
  final VideoPokerDeckShuffler? shuffleDeck;

  @override
  State<VideoPokerScreen> createState() => _VideoPokerScreenState();
}

class _VideoPokerScreenState extends State<VideoPokerScreen>
    with WidgetsBindingObserver {
  late final VideoPokerScreenController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'Video Poker machine');
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPokerScreenController(
      saveService: widget.saveService,
      credits: widget.credits,
      shuffleDeck: widget.shuffleDeck,
    );
    unawaited(_initialize());
  }

  /// A session starts with the variant picker, unless a dealt hand is
  /// waiting to be finished.
  Future<void> _initialize() async {
    await _controller.initialize();
    if (!mounted || _controller.game.isHolding) return;
    await _chooseVariant();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller.resume();
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _dealOrDraw() {
    if (_dialogOpen) return;
    final drawing = _controller.game.isHolding;
    if (_controller.dealOrDraw() && drawing) _announceAchievements();
  }

  void _betOne() {
    if (_dialogOpen) return;
    _controller.betOne();
  }

  void _betMax() {
    if (_dialogOpen) return;
    _controller.betMax();
  }

  void _toggleHold(int index) {
    if (_dialogOpen) return;
    _controller.toggleHold(index);
  }

  void _refill() {
    if (_dialogOpen) return;
    _controller.refillCredits();
  }

  Future<void> _chooseVariant() async {
    if (_dialogOpen || !_controller.canChangeVariant) return;
    _dialogOpen = true;
    final choice = await showDialog<VideoPokerVariant>(
      context: context,
      builder: (_) => VideoPokerVariantDialog(current: _controller.variant),
    );
    _dialogOpen = false;
    if (choice != null && mounted) _controller.startSession(choice);
  }

  Future<void> _showHowToPlay() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await showKfgHowToPlayDialog(
      context,
      sections: videoPokerHowToPlaySections,
    );
    _dialogOpen = false;
  }

  /// Achievements are rare, so a brief note is enough; it never interrupts
  /// the next hand.
  void _announceAchievements() {
    final unlocked = _controller.takeNewAchievements();
    if (unlocked.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')}',
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
    ];
    return {
      for (var i = 0; i < videoPokerHandSize; i++) ...{
        SingleActivator(digits[i], includeRepeats: false): () => _toggleHold(i),
        SingleActivator(numpad[i], includeRepeats: false): () => _toggleHold(i),
      },
      const SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
          _dealOrDraw,
      const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
          _dealOrDraw,
      const SingleActivator(LogicalKeyboardKey.keyB, includeRepeats: false):
          _betOne,
      const SingleActivator(LogicalKeyboardKey.keyM, includeRepeats: false):
          _betMax,
      const SingleActivator(
        LogicalKeyboardKey.keyV,
        includeRepeats: false,
      ): () =>
          unawaited(_chooseVariant()),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KfgColors.background,
      appBar: AppBar(
        toolbarHeight: 44,
        // Scales down rather than truncating beside the credits badge.
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('VIDEO POKER'),
        ),
        actions: <Widget>[
          KfgCreditsBadge(credits: widget.credits),
          const KfgSoundToggleButton(),
          IconButton(
            tooltip: 'How to Play',
            icon: const Icon(Icons.help_outline),
            onPressed: _showHowToPlay,
          ),
        ],
      ),
      // Key events bubble up from the focused node, so the shortcuts must
      // sit above the autofocused Focus to ever receive them.
      body: CallbackShortcuts(
        bindings: _shortcuts,
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: KfgScaledGameLayout(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            builder: (context, frame) => ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _controller.isInitialized
                  ? _buildBody(frame)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(KfgScaledGameFrame frame) {
    final wide = frame.contentWidth > frame.contentHeight * 1.2;
    final game = _controller.game;
    final paytable = VideoPokerPaytable(
      variant: game.variant,
      bet: game.bet,
      hand: game.currentHand,
      paid: game.isComplete,
    );

    if (wide) {
      final cardWidth = _cardWidth(
        // The card column's share of the row (flex 11 of 20, after the gap).
        width: (frame.contentWidth - 10) * 11 / 20,
        height: frame.contentHeight - 190,
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 9, child: paytable),
          const SizedBox(width: 10),
          Expanded(
            flex: 11,
            child: Column(
              children: [
                _buildStatusBar(),
                const Spacer(),
                _buildCards(cardWidth),
                _buildMessageLine(),
                const Spacer(),
                _buildControls(),
                const SizedBox(height: 6),
                _buildMainButton(),
              ],
            ),
          ),
        ],
      );
    }

    final compact = frame.contentHeight < 560;
    final gap = compact ? 4.0 : 6.0;
    final cardWidth = _cardWidth(
      width: frame.contentWidth,
      height: frame.contentHeight * 0.32,
    );
    return Column(
      children: [
        _buildStatusBar(compact: compact),
        SizedBox(height: gap),
        Expanded(child: paytable),
        SizedBox(height: gap),
        _buildCards(cardWidth),
        _buildMessageLine(compact: compact),
        _buildControls(),
        SizedBox(height: gap),
        _buildMainButton(compact: compact),
      ],
    );
  }

  /// The widest card that fits five across [width] with the HELD tag under
  /// it in [height].
  static double _cardWidth({required double width, required double height}) {
    const gap = 6.0;
    final byWidth = (width - gap * (videoPokerHandSize - 1)) / 5;
    final byHeight = (height - _heldTagHeight) / 1.4;
    return byWidth < byHeight ? byWidth : byHeight;
  }

  static const double _heldTagHeight = 22;

  Widget _buildStatusBar({bool compact = false}) {
    final game = _controller.game;
    final win = game.isComplete ? game.payout : 0;
    return Semantics(
      container: true,
      label:
          '${game.variant.label}. Bet ${game.bet} '
          '${game.bet == 1 ? 'coin' : 'coins'}. '
          '${game.isComplete ? 'Won ${formatCredits(win)}.' : ''}',
      excludeSemantics: true,
      child: SizedBox(
        height: compact ? 32 : 36,
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  game.variant.label.toUpperCase(),
                  style: const TextStyle(
                    color: KfgColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _StatusChip(
              label: 'BET',
              value: '${game.bet}',
              color: KfgColors.primary,
            ),
            const SizedBox(width: 6),
            _StatusChip(
              label: 'WIN',
              value: formatCredits(win),
              color: win > 0 ? KfgColors.warning : KfgColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCards(double cardWidth) {
    final game = _controller.game;
    final cardHeight = cardWidth * 1.4;
    final drawn = game.drawn;
    final canHold = _controller.canToggleHold;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < videoPokerHandSize; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          _buildCard(
            index: i,
            width: cardWidth,
            height: cardHeight,
            animate: game.isHolding || drawn[i],
            onTap: canHold ? () => _toggleHold(i) : null,
          ),
        ],
      ],
    );
  }

  Widget _buildCard({
    required int index,
    required double width,
    required double height,
    required bool animate,
    required VoidCallback? onTap,
  }) {
    final game = _controller.game;
    final card = game.hand.isEmpty ? null : game.hand[index];
    final held = game.hand.isNotEmpty && game.held[index];
    final label = card == null
        ? 'Card ${index + 1}: not dealt'
        : 'Card ${index + 1}: ${card.faceUpLabel}${held ? ', held' : ''}';
    return Semantics(
      button: onTap != null,
      label: label,
      hint: onTap == null ? null : (held ? 'Tap to release' : 'Tap to hold'),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedPlayingCard(
              width: width,
              height: height,
              card: card,
              selected: held,
              highlighted: false,
              emptyHint: null,
              showStatusBadges: false,
              animationCue: card != null && animate
                  ? CardAnimationCue(
                      token: _controller.dealToken,
                      beginOffset: const Offset(0, -0.25),
                    )
                  : null,
            ),
            SizedBox(
              height: _heldTagHeight,
              width: width,
              child: AnimatedOpacity(
                duration: kfgAnimDurationOf(
                  context,
                  const Duration(milliseconds: 120),
                ),
                opacity: held ? 1 : 0,
                child: const Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'HELD',
                      style: TextStyle(
                        color: KfgColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageLine({bool compact = false}) {
    final game = _controller.game;
    final paid = game.isComplete && game.payout > 0;
    return SizedBox(
      height: compact ? 24 : 30,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Text(
            _controller.message,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: paid ? KfgColors.warning : KfgColors.textSecondary,
              fontWeight: paid ? FontWeight.w900 : FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final c = _controller;
    return VideoPokerControls(
      onVariant: c.canChangeVariant ? () => unawaited(_chooseVariant()) : null,
      onBetOne: c.canChangeBet ? _betOne : null,
      onBetMax: c.canChangeBet && !c.isBroke ? _betMax : null,
    );
  }

  Widget _buildMainButton({bool compact = false}) {
    final c = _controller;
    final game = c.game;
    final refill = c.isBroke && !game.isHolding;
    final String label;
    final VoidCallback? onPressed;
    if (refill) {
      label =
          'FREE REFILL: '
          '${formatCredits(CreditsService.startingBalance)} CREDITS';
      onPressed = _refill;
    } else if (game.isHolding) {
      label = 'DRAW';
      onPressed = c.canDraw ? _dealOrDraw : null;
    } else {
      label = 'DEAL · BET ${game.bet}';
      onPressed = c.canDeal ? _dealOrDraw : null;
    }
    return SizedBox(
      height: compact ? 42 : 48,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: refill ? KfgColors.warning : KfgColors.primary,
          foregroundColor: KfgColors.background,
          disabledBackgroundColor: KfgColors.surfaceVariant,
          disabledForegroundColor: KfgColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      decoration: BoxDecoration(
        color: KfgColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: KfgColors.textMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

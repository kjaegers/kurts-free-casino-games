import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/kfg_theme.dart';
import '../../../core/animation/kfg_web_animation_speed.dart';
import '../../../core/layout/kfg_scaled_game_layout.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/widgets/kfg_credits_badge.dart';
import '../../../core/widgets/kfg_how_to_play_dialog.dart';
import '../../../core/widgets/kfg_sound_toggle_button.dart';
import 'logic/roulette_bets.dart';
import 'logic/roulette_game.dart';
import 'logic/roulette_wheel.dart';
import 'roulette_save_service.dart';
import 'roulette_screen_controller.dart';
import 'widgets/roulette_board.dart';
import 'widgets/roulette_chip.dart';
import 'widgets/roulette_controls.dart';
import 'widgets/roulette_how_to_play.dart';
import 'widgets/roulette_wheel_view.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({
    super.key,
    this.saveService,
    this.credits,
    this.pickPocket,
  });

  @visibleForTesting
  final RouletteSaveService? saveService;

  @visibleForTesting
  final CreditsService? credits;

  /// Replaces the fair pocket picker, so widget tests can land known
  /// numbers.
  @visibleForTesting
  final RoulettePocketPicker? pickPocket;

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with WidgetsBindingObserver {
  late final RouletteScreenController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'Roulette table');
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = RouletteScreenController(
      saveService: widget.saveService,
      credits: widget.credits,
      pickPocket: widget.pickPocket,
      // Read when a spin starts, so it honours the reduce-motion setting
      // of the widget tree.
      reduceMotion: () =>
          !mounted ||
          (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
          kfgReduceMotion,
    )..addListener(_announceAchievements);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_announceAchievements);
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

  void _act(bool Function() action) {
    if (_dialogOpen) return;
    action();
  }

  void _spinOrSkip() => _act(_controller.spinOrSkip);
  void _undo() => _act(_controller.undo);
  void _clear() => _act(_controller.clearBets);
  void _refill() => _act(_controller.refillCredits);
  void _selectChip(int value) => _act(() => _controller.selectChip(value));
  void _placeChip(RouletteBet bet) => _act(() => _controller.placeChip(bet));

  Future<void> _showHowToPlay() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await showKfgHowToPlayDialog(context, sections: rouletteHowToPlaySections);
    _dialogOpen = false;
  }

  /// Achievements are rare, so a brief note is enough; it never interrupts
  /// the next spin.
  void _announceAchievements() {
    final unlocked = _controller.takeNewAchievements();
    if (unlocked.isEmpty || !mounted) return;
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
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, includeRepeats: false);
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
      for (var i = 0; i < rouletteChipValues.length; i++) ...{
        key(digits[i]): () => _selectChip(rouletteChipValues[i]),
        key(numpad[i]): () => _selectChip(rouletteChipValues[i]),
      },
      key(LogicalKeyboardKey.space): _spinOrSkip,
      key(LogicalKeyboardKey.enter): _spinOrSkip,
      key(LogicalKeyboardKey.keyU): _undo,
      key(LogicalKeyboardKey.backspace): _undo,
      key(LogicalKeyboardKey.keyC): _clear,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KfgColors.background,
      appBar: AppBar(
        toolbarHeight: 44,
        // Scales down rather than truncating beside the credits badge.
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text('ROULETTE')),
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
    final c = _controller;
    final board = RouletteBoard(
      game: c.game,
      vertical: !wide,
      onBet: c.canChangeBets && !c.isBroke ? _placeChip : null,
    );

    if (wide) {
      final side = (frame.contentWidth * 0.3).clamp(
        0.0,
        frame.contentHeight * 0.8,
      );
      final wheelSize = (frame.contentHeight - 100).clamp(80.0, side);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: side,
            child: Column(
              children: [
                _buildStatusBar(),
                const Spacer(),
                _buildWheel(wheelSize),
                const Spacer(),
                _buildHistory(),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Expanded(child: board),
                _buildMessageLine(),
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
    final wheelSize = (frame.contentHeight * 0.18)
        .clamp(80.0, 220.0)
        .clamp(0.0, frame.contentWidth * 0.42);
    return Column(
      children: [
        SizedBox(
          height: wheelSize,
          child: Row(
            children: [
              _buildWheel(wheelSize),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRules(),
                    _buildStatusBar(compact: compact),
                    _buildHistory(),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        Expanded(child: board),
        _buildMessageLine(compact: compact),
        _buildControls(),
        SizedBox(height: gap),
        _buildMainButton(compact: compact),
      ],
    );
  }

  Widget _buildWheel(double size) {
    final c = _controller;
    return RouletteWheelView(
      pocket: c.game.pocket,
      spinning: c.isSpinning,
      spinToken: c.spinToken,
      duration: c.spinDurationNow,
      size: size,
    );
  }

  Widget _buildRules() {
    return const SizedBox(
      height: 16,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'SINGLE ZERO · RETURN 97.3%',
          style: TextStyle(
            color: KfgColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar({bool compact = false}) {
    final game = _controller.game;
    final win = game.payout;
    return Semantics(
      container: true,
      label:
          'Total bet ${formatCredits(game.totalBet)}. '
          '${game.isComplete ? 'Won ${formatCredits(win)}.' : ''}',
      excludeSemantics: true,
      child: SizedBox(
        height: compact ? 32 : 36,
        child: Row(
          children: [
            Expanded(
              child: _StatusChip(
                label: 'TOTAL BET',
                value: formatCredits(game.totalBet),
                color: KfgColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatusChip(
                label: 'WIN',
                value: formatCredits(win),
                color: win > 0 ? KfgColors.warning : KfgColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The latest numbers, newest first.
  Widget _buildHistory() {
    final history = _controller.history;
    return Semantics(
      container: true,
      label: history.isEmpty
          ? 'No numbers yet'
          : 'Latest numbers, newest first: '
                '${history.map(roulettePocketLabel).join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            const Text(
              'LAST',
              style: TextStyle(
                color: KfgColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Row(
                    children: [
                      for (final number in history) ...[
                        RouletteNumberBadge(number: number),
                        const SizedBox(width: 3),
                      ],
                    ],
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
    final won = game.payout > game.totalBet;
    return SizedBox(
      height: compact ? 28 : 34,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Text(
            _controller.message,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: won ? KfgColors.warning : KfgColors.textSecondary,
              fontWeight: won ? FontWeight.w900 : FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final c = _controller;
    return RouletteControls(
      chip: c.chip,
      onSelectChip: c.isInitialized ? _selectChip : null,
      onUndo: c.canUndo ? _undo : null,
      onClear: c.canUndo ? _clear : null,
    );
  }

  Widget _buildMainButton({bool compact = false}) {
    final c = _controller;
    final refill = c.isBroke && !c.isSpinning;
    final String label;
    final VoidCallback? onPressed;
    if (refill) {
      label =
          'FREE REFILL: '
          '${formatCredits(CreditsService.startingBalance)} CREDITS';
      onPressed = _refill;
    } else if (c.isSpinning) {
      label = 'SKIP';
      onPressed = c.canSkip ? _spinOrSkip : null;
    } else if (c.totalBet == 0) {
      label = 'SPIN';
      onPressed = null;
    } else {
      label = 'SPIN · BET ${formatCredits(c.totalBet)}';
      onPressed = c.canSpin ? _spinOrSkip : null;
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
      decoration: BoxDecoration(
        color: KfgColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

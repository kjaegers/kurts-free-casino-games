import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/kfg_theme.dart';
import '../../../core/layout/kfg_scaled_game_layout.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/widgets/kfg_credits_badge.dart';
import '../../../core/widgets/kfg_how_to_play_dialog.dart';
import '../../../core/widgets/kfg_sound_toggle_button.dart';
import 'logic/retro_tech_paytable.dart';
import 'logic/retro_tech_symbols.dart';
import 'slots_retro_tech_save_service.dart';
import 'slots_retro_tech_screen_controller.dart';
import 'widgets/retro_tech_controls.dart';
import 'widgets/retro_tech_grid.dart';
import 'widgets/retro_tech_how_to_play.dart';
import 'widgets/retro_tech_paytable.dart';

class SlotsRetroTechScreen extends StatefulWidget {
  const SlotsRetroTechScreen({
    super.key,
    this.saveService,
    this.credits,
    this.draw,
  });

  @visibleForTesting
  final RetroTechSaveService? saveService;

  @visibleForTesting
  final CreditsService? credits;

  /// Replaces the fair symbol draw, so widget tests can land known grids.
  @visibleForTesting
  final RetroTechSymbolDraw? draw;

  @override
  State<SlotsRetroTechScreen> createState() => _SlotsRetroTechScreenState();
}

class _SlotsRetroTechScreenState extends State<SlotsRetroTechScreen>
    with WidgetsBindingObserver {
  late final RetroTechScreenController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'Retro Tech machine');
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = RetroTechScreenController(
      saveService: widget.saveService,
      credits: widget.credits,
      draw: widget.draw,
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

  void _spinOrStop() {
    if (_dialogOpen) return;
    _controller.spinOrStop();
  }

  void _betOne() {
    if (_dialogOpen) return;
    _controller.betOne();
  }

  void _maxBet() {
    if (_dialogOpen) return;
    _controller.maxBet();
  }

  void _refill() {
    if (_dialogOpen) return;
    _controller.refillCredits();
  }

  Future<void> _showHowToPlay() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await showKfgHowToPlayDialog(context, sections: retroTechHowToPlaySections);
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

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
        _spinOrStop,
    const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
        _spinOrStop,
    const SingleActivator(LogicalKeyboardKey.keyB, includeRepeats: false):
        _betOne,
    const SingleActivator(LogicalKeyboardKey.keyM, includeRepeats: false):
        _maxBet,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KfgColors.background,
      appBar: AppBar(
        toolbarHeight: 44,
        // Scales down rather than truncating beside the credits badge.
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('SLOTS: RETRO TECH'),
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
    final paytable = RetroTechPaytable(
      betLevel: _controller.betLevel,
      paid: _paidEntries(),
    );

    if (wide) {
      // Paytable | grid at full height | the machine's readouts and buttons.
      final cellSize = RetroTechGridView.cellSizeFor(
        width: frame.contentWidth * 0.46,
        height: frame.contentHeight,
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: paytable),
          const SizedBox(width: 10),
          Center(child: _buildGrid(cellSize)),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildStatusBar(),
                const Spacer(),
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
    final cellSize = RetroTechGridView.cellSizeFor(
      width: frame.contentWidth,
      height: frame.contentHeight * (compact ? 0.42 : 0.46),
    );
    return Column(
      children: [
        _buildStatusBar(compact: compact),
        SizedBox(height: gap),
        Expanded(child: paytable),
        SizedBox(height: gap + 2),
        _buildGrid(cellSize),
        _buildMessageLine(compact: compact),
        _buildControls(),
        SizedBox(height: gap),
        _buildMainButton(compact: compact),
      ],
    );
  }

  /// The paytable entries to light: the clusters lit right now while a
  /// spin plays out, or every cluster the finished spin paid.
  Set<(RetroTechSymbol, int)> _paidEntries() {
    final game = _controller.game;
    final clusters = game.isSpinning
        ? _controller.litClusters
        : game.isComplete
        ? [for (final step in game.result!.steps) ...step.clusters]
        : const [];
    return {
      for (final c in clusters)
        if (retroTechTierOf(c.size) case final tier?) (c.symbol, tier),
    };
  }

  Widget _buildStatusBar({bool compact = false}) {
    final c = _controller;
    final win = c.runningWin;
    final result = c.game.result;
    final cascades = c.isSpinning
        ? c.gridIndex + (c.litClusters.isEmpty ? 0 : 1)
        : c.game.isComplete
        ? result!.cascades
        : 0;
    return Semantics(
      container: true,
      label:
          'Bet ${formatCredits(c.totalBet)}. '
          '${c.game.isComplete ? 'Won ${formatCredits(win)} '
                    'in $cascades ${cascades == 1 ? 'cascade' : 'cascades'}.' : ''}',
      excludeSemantics: true,
      child: SizedBox(
        height: compact ? 32 : 36,
        child: Row(
          children: [
            Expanded(
              child: _StatusChip(
                label: 'BET',
                value: formatCredits(c.totalBet),
                color: KfgColors.secondary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatusChip(
                label: 'CASCADES',
                value: '$cascades',
                color: cascades > 1 ? KfgColors.highlight : KfgColors.primary,
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

  Widget _buildGrid(double cellSize) {
    final c = _controller;
    return RetroTechGridView(
      game: c.game,
      gridIndex: c.gridIndex,
      beat: c.beat,
      beatToken: c.beatToken,
      beatDuration: c.beatDuration,
      litClusters: c.litClusters,
      cellSize: cellSize,
    );
  }

  Widget _buildMessageLine({bool compact = false}) {
    final c = _controller;
    final lit = c.isSpinning ? c.litClusters.isNotEmpty : c.game.payout > 0;
    return SizedBox(
      height: compact ? 24 : 30,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Text(
            c.message,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: lit ? KfgColors.warning : KfgColors.textSecondary,
              fontWeight: lit ? FontWeight.w900 : FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final c = _controller;
    return RetroTechControls(
      onBetOne: c.canChangeBet ? _betOne : null,
      onMaxBet: c.canChangeBet && !c.isBroke ? _maxBet : null,
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
      label = 'STOP';
      onPressed = c.canStop ? _spinOrStop : null;
    } else {
      label = 'SPIN · BET ${formatCredits(c.totalBet)}';
      onPressed = c.canSpin ? _spinOrStop : null;
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

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/kfg_theme.dart';
import '../../../core/layout/kfg_scaled_game_layout.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/widgets/kfg_credits_badge.dart';
import '../../../core/widgets/kfg_difficulty_dialog.dart';
import '../../../core/widgets/kfg_how_to_play_dialog.dart';
import '../../../core/widgets/kfg_sound_toggle_button.dart';
import 'logic/holdem_ai.dart';
import 'logic/holdem_table.dart';
import 'texas_holdem_save_service.dart';
import 'texas_holdem_screen_controller.dart';
import 'widgets/holdem_controls.dart';
import 'widgets/holdem_how_to_play.dart';
import 'widgets/holdem_table_view.dart';

class TexasHoldemScreen extends StatefulWidget {
  const TexasHoldemScreen({
    super.key,
    this.saveService,
    this.credits,
    this.shuffleDeck,
    this.decideOpponent,
    this.random,
    this.opponentDelay,
  });

  @visibleForTesting
  final TexasHoldemSaveService? saveService;

  @visibleForTesting
  final CreditsService? credits;

  /// Replaces the fair shuffle, so widget tests can deal known cards.
  @visibleForTesting
  final HoldemDeckShuffler? shuffleDeck;

  /// Replaces the computer opponents' play in widget tests.
  @visibleForTesting
  final HoldemOpponentDecider? decideOpponent;

  /// Seeds the opponents' choices in widget tests.
  @visibleForTesting
  final Random? random;

  @visibleForTesting
  final Duration? opponentDelay;

  @override
  State<TexasHoldemScreen> createState() => _TexasHoldemScreenState();
}

class _TexasHoldemScreenState extends State<TexasHoldemScreen>
    with WidgetsBindingObserver {
  late final TexasHoldemScreenController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: "Texas Hold'em table");
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TexasHoldemScreenController(
      saveService: widget.saveService,
      credits: widget.credits,
      shuffleDeck: widget.shuffleDeck,
      decideOpponent: widget.decideOpponent,
      random: widget.random,
      opponentDelay:
          widget.opponentDelay ??
          TexasHoldemScreenController.defaultOpponentDelay,
    );
    // Hands can end on an opponent's move, so achievements are announced
    // whenever the controller reports them, not only after a tap.
    _controller.addListener(_announceAchievements);
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

  void _deal() => _act(_controller.deal);
  void _fold() => _act(_controller.fold);
  void _checkOrCall() => _act(_controller.checkOrCall);
  void _raise() => _act(_controller.raise);
  void _refill() => _act(_controller.refillCredits);
  void _lower() => _act(() => _controller.stepRaise(-1));
  void _increase() => _act(() => _controller.stepRaise(1));
  void _preset(HoldemRaisePreset preset) =>
      _act(() => _controller.presetRaise(preset));

  /// Runs [show] as the only dialog, pausing the opponents while it's open.
  Future<T?> _withDialog<T>(Future<T?> Function() show) async {
    if (_dialogOpen) return null;
    _dialogOpen = true;
    _controller.pause();
    try {
      return await show();
    } finally {
      _dialogOpen = false;
      if (mounted) _controller.resume();
    }
  }

  Future<void> _showHowToPlay() => _withDialog(
    () =>
        showKfgHowToPlayDialog(context, sections: texasHoldemHowToPlaySections),
  );

  Future<void> _chooseOpponents() async {
    if (!_controller.canChangeTable) return;
    final current = _controller.table.opponents.length;
    final count = await _withDialog(
      () => showDialog<int>(
        context: context,
        builder: (_) => KfgDifficultyDialog<int>(
          title: 'OPPONENTS',
          options: [
            for (var n = holdemMinOpponents; n <= holdemMaxOpponents; n++)
              KfgDifficultyOption(
                label: n == 1 ? '1 opponent' : '$n opponents',
                subtitle:
                    '${n == 1 ? 'Heads-up: just you and one player' : '${n + 1} players at the table'}'
                    '${n == current ? ' (current)' : ''}',
                color: const [
                  KfgColors.highlight,
                  KfgColors.primary,
                  KfgColors.primary,
                  KfgColors.warning,
                  KfgColors.secondary,
                ][n - 1],
                value: n,
              ),
          ],
        ),
      ),
    );
    if (count != null) _controller.newTable(opponents: count);
  }

  Future<void> _chooseDifficulty() async {
    if (!_controller.canChangeTable) return;
    final current = _controller.table.difficulty;
    final level = await _withDialog(
      () => showDialog<HoldemDifficulty>(
        context: context,
        builder: (_) => KfgDifficultyDialog<HoldemDifficulty>(
          options: [
            for (final (d, color) in const [
              (HoldemDifficulty.easy, KfgColors.success),
              (HoldemDifficulty.normal, KfgColors.primary),
              (HoldemDifficulty.hard, KfgColors.warning),
            ])
              KfgDifficultyOption(
                label: d.label,
                subtitle: '${d.subtitle}${d == current ? ' (current)' : ''}',
                color: color,
                value: d,
              ),
          ],
        ),
      ),
    );
    if (level != null) _controller.newTable(difficulty: level);
  }

  /// Achievements are rare, so a brief note is enough; it never interrupts
  /// the next hand.
  void _announceAchievements() {
    if (!mounted) return;
    final hand = _controller.hand;
    if (hand == null || !hand.isComplete) return;
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
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, includeRepeats: false);
    return {
      key(LogicalKeyboardKey.space): _deal,
      key(LogicalKeyboardKey.enter): _deal,
      key(LogicalKeyboardKey.keyF): _fold,
      key(LogicalKeyboardKey.keyC): _checkOrCall,
      key(LogicalKeyboardKey.keyR): _raise,
      key(LogicalKeyboardKey.keyH): () => _preset(HoldemRaisePreset.halfPot),
      key(LogicalKeyboardKey.keyP): () => _preset(HoldemRaisePreset.pot),
      key(LogicalKeyboardKey.keyA): () => _preset(HoldemRaisePreset.allIn),
      key(LogicalKeyboardKey.arrowDown): _lower,
      key(LogicalKeyboardKey.arrowLeft): _lower,
      key(LogicalKeyboardKey.minus): _lower,
      key(LogicalKeyboardKey.numpadSubtract): _lower,
      key(LogicalKeyboardKey.arrowUp): _increase,
      key(LogicalKeyboardKey.arrowRight): _increase,
      key(LogicalKeyboardKey.equal): _increase,
      key(LogicalKeyboardKey.numpadAdd): _increase,
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
          child: Text("TEXAS HOLD'EM"),
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
    final table = HoldemTableView(
      table: _controller.table,
      handToken: _controller.handToken,
      nextStake: _controller.nextStake,
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: table),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildStatusBar(),
                const Spacer(),
                _buildMessageLine(),
                const Spacer(),
                _buildControls(),
                const SizedBox(height: 6),
                _buildMainButtons(),
              ],
            ),
          ),
        ],
      );
    }

    final compact = frame.contentHeight < 560;
    final gap = compact ? 4.0 : 6.0;
    return Column(
      children: [
        _buildStatusBar(compact: compact),
        SizedBox(height: gap),
        Expanded(child: table),
        SizedBox(height: gap),
        _buildMessageLine(compact: compact),
        _buildControls(),
        SizedBox(height: gap),
        _buildMainButtons(compact: compact),
      ],
    );
  }

  Widget _buildStatusBar({bool compact = false}) {
    final table = _controller.table;
    final hand = _controller.hand;
    final inPlay = hand != null && hand.isInPlay;
    final stack = inPlay ? hand.seats[0].stack : _controller.nextStake;
    return Semantics(
      container: true,
      label:
          'No-limit, blinds $holdemSmallBlind and $holdemBigBlind. '
          '${table.difficulty.label} difficulty, '
          '${table.opponents.length} opponents. '
          'Your stack ${formatCredits(stack)}.',
      excludeSemantics: true,
      child: SizedBox(
        height: compact ? 32 : 36,
        child: Row(
          children: [
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'NO-LIMIT · NO RAKE',
                  style: TextStyle(
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
              label: 'LEVEL',
              value: table.difficulty.label.toUpperCase(),
              color: KfgColors.secondary,
            ),
            const SizedBox(width: 6),
            const _StatusChip(
              label: 'BLINDS',
              value: '$holdemSmallBlind/$holdemBigBlind',
              color: KfgColors.textSecondary,
            ),
            const SizedBox(width: 6),
            _StatusChip(
              label: 'STACK',
              value: formatCredits(stack),
              color: KfgColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageLine({bool compact = false}) {
    final hand = _controller.hand;
    final won =
        hand != null &&
        hand.isComplete &&
        hand.winnings[0] > hand.seats[0].committed;
    return SizedBox(
      height: compact ? 30 : 34,
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
    if (c.isInPlay) {
      final raise = c.canRaise;
      return HoldemControls(
        actions: [
          HoldemAction(
            label: 'Less',
            icon: Icons.remove,
            tooltip: 'Bet one big blind less (←)',
            onTap: c.canLowerRaise ? _lower : null,
          ),
          HoldemAction(
            label: '½ Pot',
            icon: Icons.pie_chart_outline,
            tooltip: 'Bet half the pot (H)',
            onTap: raise ? () => _preset(HoldemRaisePreset.halfPot) : null,
          ),
          HoldemAction(
            label: 'Pot',
            icon: Icons.circle_outlined,
            tooltip: 'Bet the size of the pot (P)',
            onTap: raise ? () => _preset(HoldemRaisePreset.pot) : null,
          ),
          HoldemAction(
            label: 'All-in',
            icon: Icons.keyboard_double_arrow_up,
            tooltip: 'Bet everything in front of you (A)',
            onTap: raise ? () => _preset(HoldemRaisePreset.allIn) : null,
          ),
          HoldemAction(
            label: 'More',
            icon: Icons.add,
            tooltip: 'Bet one big blind more (→)',
            onTap: c.canIncreaseRaise ? _increase : null,
          ),
        ],
      );
    }
    final change = c.canChangeTable;
    return HoldemControls(
      actions: [
        HoldemAction(
          label: 'Opponents · ${c.table.opponents.length}',
          icon: Icons.groups,
          tooltip: 'Choose how many opponents (seats a new table)',
          onTap: change ? _chooseOpponents : null,
        ),
        HoldemAction(
          label: 'Difficulty · ${c.table.difficulty.label}',
          icon: Icons.tune,
          tooltip: 'Choose how well the opponents play (seats a new table)',
          onTap: change ? _chooseDifficulty : null,
        ),
      ],
    );
  }

  Widget _buildMainButtons({bool compact = false}) {
    final c = _controller;
    final height = compact ? 42.0 : 48.0;
    if (c.isInPlay) {
      final call = c.toCall;
      final String raiseLabel;
      if (!c.canRaise) {
        raiseLabel = 'RAISE';
      } else if (c.raiseIsAllIn) {
        raiseLabel = 'ALL-IN ${formatCredits(c.raiseTo)}';
      } else if (c.raiseIsOpening) {
        raiseLabel = 'BET ${formatCredits(c.raiseTo)}';
      } else {
        raiseLabel = 'RAISE TO ${formatCredits(c.raiseTo)}';
      }
      return _ButtonRow(
        height: height,
        buttons: [
          _MainButton(
            label: 'FOLD',
            color: KfgColors.secondary,
            onPressed: c.canFold ? _fold : null,
          ),
          _MainButton(
            label: !c.isPlayerTurn || call == 0
                ? 'CHECK'
                : 'CALL ${formatCredits(call)}',
            color: KfgColors.primary,
            onPressed: c.canCheckOrCall ? _checkOrCall : null,
          ),
          _MainButton(
            label: raiseLabel,
            color: KfgColors.highlight,
            onPressed: c.canRaise ? _raise : null,
          ),
        ],
      );
    }
    return _ButtonRow(
      height: height,
      buttons: [
        c.isBroke
            ? _MainButton(
                label:
                    'FREE REFILL: '
                    '${formatCredits(CreditsService.startingBalance)} CREDITS',
                color: KfgColors.warning,
                onPressed: _refill,
              )
            : _MainButton(
                label: 'DEAL · STACK ${formatCredits(c.nextStake)}',
                color: KfgColors.primary,
                onPressed: c.canDeal ? _deal : null,
              ),
      ],
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({required this.height, required this.buttons});

  final double height;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  const _MainButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: KfgColors.background,
        disabledBackgroundColor: KfgColors.surfaceVariant,
        disabledForegroundColor: KfgColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      constraints: const BoxConstraints(minWidth: 48),
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

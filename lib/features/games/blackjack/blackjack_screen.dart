import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/kfg_theme.dart';
import '../../../core/layout/kfg_scaled_game_layout.dart';
import '../../../core/services/credits_service.dart';
import '../../../core/widgets/kfg_credits_badge.dart';
import '../../../core/widgets/kfg_how_to_play_dialog.dart';
import '../../../core/widgets/kfg_sound_toggle_button.dart';
import 'blackjack_save_service.dart';
import 'blackjack_screen_controller.dart';
import 'logic/blackjack_game.dart';
import 'widgets/blackjack_controls.dart';
import 'widgets/blackjack_how_to_play.dart';
import 'widgets/blackjack_table.dart';

class BlackjackScreen extends StatefulWidget {
  const BlackjackScreen({
    super.key,
    this.saveService,
    this.credits,
    this.shuffleShoe,
  });

  @visibleForTesting
  final BlackjackSaveService? saveService;

  @visibleForTesting
  final CreditsService? credits;

  /// Replaces the fair shuffle, so widget tests can deal known cards.
  @visibleForTesting
  final BlackjackShoeShuffler? shuffleShoe;

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen>
    with WidgetsBindingObserver {
  late final BlackjackScreenController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'Blackjack table');
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = BlackjackScreenController(
      saveService: widget.saveService,
      credits: widget.credits,
      shuffleShoe: widget.shuffleShoe,
    );
    unawaited(_controller.initialize());
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

  /// Runs [action] unless a dialog is open, announcing any achievement the
  /// round it finished unlocked.
  void _act(bool Function() action) {
    if (_dialogOpen) return;
    if (action() && _controller.game.isComplete) _announceAchievements();
  }

  void _deal() => _act(_controller.deal);
  void _hit() => _act(_controller.hit);
  void _stand() => _act(_controller.stand);
  void _double() => _act(_controller.doubleDown);
  void _split() => _act(_controller.split);
  void _surrender() => _act(_controller.surrender);
  void _takeInsurance() => _act(_controller.takeInsurance);
  void _declineInsurance() => _act(_controller.declineInsurance);
  void _clearBet() => _act(_controller.clearBet);
  void _refill() => _act(_controller.refillCredits);
  void _addChip(int chip) => _act(() => _controller.addChip(chip));

  Future<void> _showHowToPlay() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await showKfgHowToPlayDialog(context, sections: blackjackHowToPlaySections);
    _dialogOpen = false;
  }

  /// Achievements are rare, so a brief note is enough; it never interrupts
  /// the next round.
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
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, includeRepeats: false);
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
    ];
    const chips = BlackjackScreenController.chips;
    return {
      for (var i = 0; i < chips.length; i++) ...{
        key(digits[i]): () => _addChip(chips[i]),
        key(numpad[i]): () => _addChip(chips[i]),
      },
      key(LogicalKeyboardKey.keyC): _clearBet,
      key(LogicalKeyboardKey.space): _deal,
      key(LogicalKeyboardKey.enter): _deal,
      key(LogicalKeyboardKey.keyH): _hit,
      key(LogicalKeyboardKey.keyS): _stand,
      key(LogicalKeyboardKey.keyD): _double,
      key(LogicalKeyboardKey.keyP): _split,
      key(LogicalKeyboardKey.keyR): _surrender,
      key(LogicalKeyboardKey.keyI): _takeInsurance,
      key(LogicalKeyboardKey.keyN): _declineInsurance,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KfgColors.background,
      appBar: AppBar(
        toolbarHeight: 44,
        // Scales down rather than truncating beside the credits badge.
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text('BLACKJACK')),
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
    final table = BlackjackTable(
      game: _controller.game,
      roundToken: _controller.roundToken,
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
                _buildRules(),
                const SizedBox(height: 6),
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
        _buildRules(),
        SizedBox(height: gap),
        Expanded(child: table),
        _buildMessageLine(compact: compact),
        _buildControls(),
        SizedBox(height: gap),
        _buildMainButtons(compact: compact),
      ],
    );
  }

  Widget _buildStatusBar({bool compact = false}) {
    final game = _controller.game;
    final staked = game.isInPlay || game.isComplete
        ? game.totalWagered
        : game.bet;
    final win = game.isComplete ? game.payout : 0;
    return Semantics(
      container: true,
      label:
          'Bet ${formatCredits(staked)}. '
          '${game.isComplete ? 'Paid ${formatCredits(win)}. ' : ''}'
          '${game.shoe.length} cards left in the shoe.',
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
                  'BLACKJACK PAYS 3:2',
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
              label: 'SHOE',
              value: game.shoe.isEmpty ? '—' : '${game.shoe.length}',
              color: KfgColors.textSecondary,
            ),
            const SizedBox(width: 6),
            _StatusChip(
              label: 'BET',
              value: formatCredits(staked),
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

  Widget _buildRules() {
    return const SizedBox(
      height: 16,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'DEALER STANDS ON ALL 17s · INSURANCE PAYS 2:1',
          style: TextStyle(
            color: KfgColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageLine({bool compact = false}) {
    final game = _controller.game;
    final won = game.isComplete && game.payout > game.totalWagered;
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
    if (c.game.isInPlay) {
      return BlackjackControls(
        actions: [
          BlackjackAction(
            label: 'Double',
            icon: Icons.exposure_plus_2,
            tooltip: 'Double your bet and take one card (D)',
            onTap: c.canDouble ? _double : null,
          ),
          BlackjackAction(
            label: 'Split',
            icon: Icons.call_split,
            tooltip: 'Split a pair into two hands (P)',
            onTap: c.canSplit ? _split : null,
          ),
          BlackjackAction(
            label: 'Surrender',
            icon: Icons.flag_outlined,
            tooltip: 'Give up the hand for half your bet back (R)',
            onTap: c.canSurrender ? _surrender : null,
          ),
        ],
      );
    }
    const chips = BlackjackScreenController.chips;
    final canRaise = c.canRaiseBet && !c.isBroke;
    return BlackjackControls(
      actions: [
        for (var i = 0; i < chips.length; i++)
          BlackjackAction(
            label: '+${chips[i]}',
            icon: Icons.toll,
            tooltip: 'Add a ${chips[i]} chip to your bet (${i + 1})',
            onTap: canRaise ? () => _addChip(chips[i]) : null,
          ),
        BlackjackAction(
          label: 'Clear',
          icon: Icons.restart_alt,
          tooltip: 'Set the bet back to $blackjackMinBet (C)',
          onTap: c.canChangeBet && c.bet > blackjackMinBet ? _clearBet : null,
        ),
      ],
    );
  }

  Widget _buildMainButtons({bool compact = false}) {
    final c = _controller;
    final game = c.game;
    final height = compact ? 42.0 : 48.0;
    if (game.phase == BlackjackPhase.insurance) {
      return _ButtonRow(
        height: height,
        buttons: [
          _MainButton(
            label: 'INSURANCE · ${formatCredits(game.insuranceCost)}',
            color: KfgColors.secondary,
            onPressed: c.canTakeInsurance ? _takeInsurance : null,
          ),
          _MainButton(
            label: 'NO INSURANCE',
            color: KfgColors.primary,
            onPressed: c.canDecideInsurance ? _declineInsurance : null,
          ),
        ],
      );
    }
    if (game.phase == BlackjackPhase.playerTurn) {
      return _ButtonRow(
        height: height,
        buttons: [
          _MainButton(
            label: 'HIT',
            color: KfgColors.highlight,
            onPressed: c.canHit ? _hit : null,
          ),
          _MainButton(
            label: 'STAND',
            color: KfgColors.primary,
            onPressed: c.canStand ? _stand : null,
          ),
        ],
      );
    }
    final refill = c.isBroke;
    return _ButtonRow(
      height: height,
      buttons: [
        refill
            ? _MainButton(
                label:
                    'FREE REFILL: '
                    '${formatCredits(CreditsService.startingBalance)} CREDITS',
                color: KfgColors.warning,
                onPressed: _refill,
              )
            : _MainButton(
                label: 'DEAL · BET ${formatCredits(game.bet)}',
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

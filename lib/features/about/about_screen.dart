import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/kfg_theme.dart';
import '../../core/widgets/kfg_neon_card.dart';
import '../../core/widgets/kfg_section_header.dart';

/// About screen — explains the project and its philosophy.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Rewritten by build_and_distribute.ps1 to match `version:` in pubspec.yaml.
  static const String _version = '1.0.0+20';
  static final Uri _patreonUri = Uri.parse(
    'https://www.patreon.com/kurtjaegers',
  );

  /// Flutter's licenses page: every package's license, plus the bundled
  /// fonts registered by `KfgLicenses`. Fully offline.
  static void _openLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: "Kurt's Free Casino Games",
      applicationVersion: 'v$_version',
      applicationIcon: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.videogame_asset, color: KfgColors.primary, size: 40),
      ),
    );
  }

  static Future<void> _openPatreon(BuildContext context) async {
    final launched = await launchUrl(
      _patreonUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open Patreon link.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(),
          const SizedBox(height: 20),

          // ── Version ────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.videogame_asset,
                  color: KfgColors.primary,
                  size: 56,
                ),
                const SizedBox(height: 8),
                const Text(
                  "KURT'S FREE CASINO GAMES",
                  style: TextStyle(
                    color: KfgColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                // One line that scales down on narrow screens / Large Text.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'by Kurt Jaegers (',
                        style: TextStyle(
                          color: KfgColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openPatreon(context),
                        child: const Text(
                          'Patreon',
                          style: TextStyle(
                            color: KfgColors.secondary,
                            fontSize: 12,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        ')',
                        style: TextStyle(
                          color: KfgColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v$_version',
                  style: const TextStyle(
                    color: KfgColors.textMuted,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Philosophy ─────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Philosophy'),
          const SizedBox(height: 10),
          const KfgNeonCard(
            child: Text(
              "Kurt's Free Casino Games is an offline collection of free casino "
              'games played purely for fun — without ads, tracking, '
              'or microtransactions getting in the way.\n\n'
              'Chips have no cash value and can never be bought, sold or won as '
              'prizes. Every game is completely free to play in full, the odds '
              'are honest, and no accounts are required.',
              style: TextStyle(color: KfgColors.textSecondary, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),

          // ── Promises ───────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Our Promises'),
          const SizedBox(height: 10),
          ..._promises.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PromiseRow(icon: p.$1, text: p.$2, color: p.$3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PromiseRow(
              icon: Icons.favorite,
              text: "Support Kurt's Free Casino Games on Patreon.",
              color: KfgColors.secondary,
              onTap: () => _openPatreon(context),
            ),
          ),
          const SizedBox(height: 20),

          // ── Tech note ──────────────────────────────────────────────────
          const KfgSectionHeader(title: 'Built With'),
          const SizedBox(height: 10),
          const KfgNeonCard(
            child: Text(
              'Built with Flutter & Dart.\n'
              'No third-party analytics, crash-reporting, or ad SDKs included.\n\n'
              'Text uses the Roboto font (Apache-2.0) and symbols from the Noto '
              'fonts (SIL Open Font License 1.1), bundled with the app.',
              style: TextStyle(color: KfgColors.textMuted, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),

          // ── License ────────────────────────────────────────────────────
          const KfgSectionHeader(title: 'License'),
          const SizedBox(height: 10),
          const KfgNeonCard(
            child: Text(
              "Copyright (C) 2026 Kurt Jaegers.\n\n"
              "Kurt's Free Casino Games is free software: you can redistribute "
              'it and/or modify it under the terms of the GNU General Public '
              'License, version 3 or (at your option) any later version. It '
              'comes with ABSOLUTELY NO WARRANTY. The full license text is '
              "included under Open-source licenses, listed as Kurt's Free "
              'Casino Games.',
              style: TextStyle(color: KfgColors.textMuted, height: 1.5),
            ),
          ),
          const SizedBox(height: 8),
          _PromiseRow(
            icon: Icons.description_outlined,
            text: 'Open-source licenses — this app, fonts and libraries.',
            color: KfgColors.primary,
            onTap: () => _openLicenses(context),
          ),
        ],
      ),
    );
  }
}

// (icon, text, color)
const List<(IconData, String, Color)> _promises = [
  (
    Icons.wifi_off,
    'Fully offline — no internet connection required.',
    KfgColors.primary,
  ),
  (Icons.money_off, 'Zero ads — not one. Not ever.', KfgColors.highlight),
  (
    Icons.visibility_off,
    'No tracking — your gameplay data stays on your device.',
    KfgColors.secondary,
  ),
  (
    Icons.attach_money,
    'No real money — chips are free, never sold and worth nothing.',
    KfgColors.warning,
  ),
  (
    Icons.lock_open,
    'No accounts required — just open and play.',
    KfgColors.primary,
  ),
];

class _PageTitle extends StatelessWidget {
  // ignore: unused_element
  const _PageTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'ABOUT',
      style: TextStyle(
        color: KfgColors.primary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 3,
      ),
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.icon,
    required this.text,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KfgNeonCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: KfgColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

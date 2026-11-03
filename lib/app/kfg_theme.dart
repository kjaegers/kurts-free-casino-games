import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// All raw color values used across the app.
abstract final class KfgColors {
  // ── Backgrounds ────────────────────────────────────────────────────────
  static const Color background = Color(0xFF050510);
  static const Color surface = Color(0xFF0D0D2B);
  static const Color surfaceVariant = Color(0xFF12122E);

  // ── Neon accents ───────────────────────────────────────────────────────
  /// Cyan — primary accent.
  static const Color primary = Color(0xFF00E5FF);

  /// Magenta/purple — secondary accent.
  static const Color secondary = Color(0xFFE040FB);

  /// Neon green — highlight, used sparingly.
  static const Color highlight = Color(0xFF39FF14);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE0F7FA);
  static const Color textSecondary = Color(0xFF80DEEA);

  /// Small labels and hints. Meets WCAG AA (≥4.5:1) on [background],
  /// [surface] and [surfaceVariant].
  static const Color textMuted = Color(0xFF7A8C99);

  // ── Structure ──────────────────────────────────────────────────────────
  static const Color cardBorder = Color(0xFF1A3A5C);
  static const Color divider = Color(0xFF1A1A3E);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFFD740);
  static const Color success = Color(0xFF39FF14);
}

/// Fonts bundled in `assets/fonts/` so text renders identically offline.
///
/// The theme applies these app-wide. Text painted outside the widget tree
/// (e.g. with a [TextPainter]) doesn't inherit the theme and must set
/// [family] and [fallback] itself.
abstract final class KfgFonts {
  static const String family = 'Roboto';

  /// Symbol fonts consulted for glyphs Roboto lacks (card suits, ✓ ✗ ✕ ⌫,
  /// arrows). The emoji subset is web-only: native platforms keep their own
  /// colour emoji font, while web would otherwise download one at runtime.
  static const List<String> fallback = [
    'KfgSymbols',
    'KfgArrows',
    if (kIsWeb) 'KfgEmoji',
  ];
}

/// App-wide [ThemeData] for Kurt's Free Casino Games.
abstract final class KfgTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: KfgFonts.family,
      fontFamilyFallback: KfgFonts.fallback,
      scaffoldBackgroundColor: KfgColors.background,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: KfgColors.primary,
        onPrimary: Color(0xFF003040),
        secondary: KfgColors.secondary,
        onSecondary: Color(0xFF1A0030),
        tertiary: KfgColors.highlight,
        onTertiary: Color(0xFF001A00),
        surface: KfgColors.surface,
        onSurface: KfgColors.textPrimary,
        surfaceContainerHighest: KfgColors.surfaceVariant,
        error: KfgColors.error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: KfgColors.background,
        foregroundColor: KfgColors.primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: KfgFonts.family,
          fontFamilyFallback: KfgFonts.fallback,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: KfgColors.primary,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: KfgColors.primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KfgColors.surface,
        indicatorColor: Color(0xFF003A4D),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: KfgColors.primary, size: 24);
          }
          return const IconThemeData(color: KfgColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: KfgFonts.family,
              fontFamilyFallback: KfgFonts.fallback,
              color: KfgColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            );
          }
          return const TextStyle(
            fontFamily: KfgFonts.family,
            fontFamilyFallback: KfgFonts.fallback,
            color: KfgColors.textMuted,
            fontSize: 11,
          );
        }),
        height: 64,
      ),
      cardTheme: const CardThemeData(
        color: KfgColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: KfgColors.cardBorder),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: KfgColors.surfaceVariant,
        selectedColor: Color(0xFF003A4D),
        labelStyle: TextStyle(
          fontFamily: KfgFonts.family,
          fontFamilyFallback: KfgFonts.fallback,
          color: KfgColors.textSecondary,
          fontSize: 12,
        ),
        side: BorderSide(color: KfgColors.cardBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: KfgColors.divider,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KfgColors.primary;
          return KfgColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF003A4D);
          }
          return KfgColors.surfaceVariant;
        }),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: KfgColors.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
        displayMedium: TextStyle(
          color: KfgColors.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        headlineLarge: TextStyle(
          color: KfgColors.textPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        headlineMedium: TextStyle(
          color: KfgColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: KfgColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(color: KfgColors.textSecondary),
        bodyLarge: TextStyle(color: KfgColors.textPrimary),
        bodyMedium: TextStyle(color: KfgColors.textSecondary),
        bodySmall: TextStyle(color: KfgColors.textMuted),
        labelLarge: TextStyle(
          color: KfgColors.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

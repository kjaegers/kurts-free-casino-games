import 'package:flutter/widgets.dart';

/// Centralized text scaling policy for Kurt's Free Casino Games.
///
/// Accessibility tradeoff:
///
/// Kurt's Free Casino Games prioritizes stable, high-contrast, proportional game UI
/// over fully unconstrained OS font scaling. Dense boards and touch controls
/// are designed to remain visible and playable across devices.
abstract final class KfgTextScale {
  static const double globalMinScale = 0.9;
  static const double globalMaxScale = 1.1;

  static const double gameMinScale = 0.9;
  static const double gameMaxScale = 1.0;

  /// Extra multiplier applied on non-game routes when Settings > Large Text
  /// is on. Game routes are left alone: their boards and controls are sized
  /// to fit the screen and would overflow with larger text.
  static const double largeTextFactor = 1.2;

  static bool isGameRoute(String? routeName) {
    return routeName?.startsWith('/game/') ?? false;
  }

  static Widget clampGlobal({
    required BuildContext context,
    required Widget child,
  }) {
    return _clamp(
      context: context,
      child: child,
      minScale: globalMinScale,
      maxScale: globalMaxScale,
    );
  }

  static Widget clampForRoute({
    required BuildContext context,
    required Widget child,
    required String? routeName,
    bool largeText = false,
  }) {
    if (isGameRoute(routeName)) {
      return _clamp(
        context: context,
        child: child,
        minScale: gameMinScale,
        maxScale: gameMaxScale,
      );
    }

    return _clamp(
      context: context,
      child: child,
      minScale: globalMinScale,
      maxScale: globalMaxScale,
      factor: largeText ? largeTextFactor : 1.0,
    );
  }

  static Widget _clamp({
    required BuildContext context,
    required Widget child,
    required double minScale,
    required double maxScale,
    double factor = 1.0,
  }) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) {
      return child;
    }

    final currentScale = media.textScaler.scale(1.0);
    final clampedScale =
        currentScale.clamp(minScale, maxScale).toDouble() * factor;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
      child: child,
    );
  }
}

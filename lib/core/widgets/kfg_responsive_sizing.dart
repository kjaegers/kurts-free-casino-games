import 'dart:math' as math;

/// Shared numeric helpers for responsive game layouts.
abstract final class KfgResponsiveSizing {
  static double clamp(
    double value, {
    required double min,
    required double max,
  }) {
    return value.clamp(min, max).toDouble();
  }

  static double min2(double a, double b) => math.min(a, b);

  static double max2(double a, double b) => math.max(a, b);
}

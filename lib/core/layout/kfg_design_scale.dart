import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Proportional design-scale data for a specific available layout area.
class KfgDesignScaleData {
  const KfgDesignScaleData({
    required this.availableWidth,
    required this.availableHeight,
    required this.referenceWidth,
    required this.referenceHeight,
    required this.scaleX,
    required this.scaleY,
    required this.scale,
    required this.textScale,
    required this.spacingScale,
  });

  final double availableWidth;
  final double availableHeight;

  final double referenceWidth;
  final double referenceHeight;

  final double scaleX;
  final double scaleY;
  final double scale;
  final double textScale;
  final double spacingScale;

  double w(double value) => value * scaleX;

  double h(double value) => value * scaleY;

  double r(double value) => value * scale;

  double sp(double value) => value * textScale;

  double clampFont(double value, {required double min, required double max}) {
    return sp(value).clamp(min, max).toDouble();
  }
}

class KfgDesignScaleScope extends InheritedWidget {
  const KfgDesignScaleScope({
    super.key,
    required this.data,
    required super.child,
  });

  final KfgDesignScaleData data;

  static KfgDesignScaleData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<KfgDesignScaleScope>();
    if (scope != null) {
      return scope.data;
    }

    return KfgDesignScale.scaleForMediaQuery(context);
  }

  @override
  bool updateShouldNotify(KfgDesignScaleScope oldWidget) {
    return data.availableWidth != oldWidget.data.availableWidth ||
        data.availableHeight != oldWidget.data.availableHeight ||
        data.scale != oldWidget.data.scale ||
        data.textScale != oldWidget.data.textScale;
  }
}

/// App-wide design scaling based on a fixed portrait reference frame.
abstract final class KfgDesignScale {
  /// Chosen reference: 393x852 logical pixels.
  ///
  /// This aligns with common Flutter logical dimensions for modern Android
  /// FHD+ class phones (roughly 1080x2340 at DPR ~2.75, e.g. S23 FE class).
  static const double referenceWidth = 393;
  static const double referenceHeight = 852;

  static KfgDesignScaleData scaleForMediaQuery(
    BuildContext context, {
    bool useSafeArea = true,
  }) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final safeVerticalPadding = useSafeArea
        ? media.padding.top + media.padding.bottom
        : 0.0;
    final height = (media.size.height - safeVerticalPadding)
        .clamp(0.0, double.infinity)
        .toDouble();

    return _fromSize(width: width, height: height);
  }

  static KfgDesignScaleData scaleForConstraints(
    BoxConstraints constraints, {
    EdgeInsets safePadding = EdgeInsets.zero,
  }) {
    final width = (constraints.maxWidth - safePadding.horizontal)
        .clamp(0.0, double.infinity)
        .toDouble();
    final height = (constraints.maxHeight - safePadding.vertical)
        .clamp(0.0, double.infinity)
        .toDouble();

    return _fromSize(width: width, height: height);
  }

  static KfgDesignScaleData _fromSize({
    required double width,
    required double height,
  }) {
    final scaleX = width / referenceWidth;
    final scaleY = height / referenceHeight;
    final scale = math.min(scaleX, scaleY);

    return KfgDesignScaleData(
      availableWidth: width,
      availableHeight: height,
      referenceWidth: referenceWidth,
      referenceHeight: referenceHeight,
      scaleX: scaleX,
      scaleY: scaleY,
      scale: scale,
      textScale: scale.clamp(0.92, 1.10).toDouble(),
      spacingScale: scale.clamp(0.85, 1.20).toDouble(),
    );
  }
}

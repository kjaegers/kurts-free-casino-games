import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kfg_design_scale.dart';
import 'kfg_viewport.dart';

class KfgScaledGameFrame {
  const KfgScaledGameFrame({
    required this.contentWidth,
    required this.contentHeight,
    required this.viewport,
  });

  final double contentWidth;
  final double contentHeight;
  final KfgViewportData viewport;

  KfgDesignScaleData get scale => viewport.designScale;
}

class KfgScaledGameLayout extends StatelessWidget {
  const KfgScaledGameLayout({
    super.key,
    required this.builder,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.topSafeArea = false,
    this.showDebugOverlay,
    this.safeAreaApplied = true,
    this.appReservedTop = 0,
    this.appReservedBottom = 0,
  });

  final EdgeInsets padding;
  final bool topSafeArea;
  final Widget Function(BuildContext context, KfgScaledGameFrame frame) builder;
  final bool? showDebugOverlay;
  final bool safeAreaApplied;
  final double appReservedTop;
  final double appReservedBottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: topSafeArea,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = KfgViewportData.fromLayout(
            context: context,
            constraints: constraints,
            contentPadding: padding,
            safeAreaApplied: safeAreaApplied,
            appReservedTop: appReservedTop,
            appReservedBottom: appReservedBottom,
          );

          final frame = KfgScaledGameFrame(
            contentWidth: viewport.usableWidth,
            contentHeight: viewport.usableHeight,
            viewport: viewport,
          );

          final child = Padding(
            padding: padding,
            child: builder(context, frame),
          );
          final shouldShowOverlay =
              showDebugOverlay ??
              (kDebugMode && KfgViewportDebug.enabledByEnvironment);

          if (!shouldShowOverlay) {
            return child;
          }

          return Stack(
            children: [
              child,
              KfgViewportDebugOverlay(data: viewport),
            ],
          );
        },
      ),
    );
  }
}

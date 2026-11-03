import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'kfg_design_scale.dart';

@immutable
class KfgViewportData {
  const KfgViewportData({
    required this.screenSize,
    required this.layoutSize,
    required this.safePaddingTop,
    required this.safePaddingBottom,
    required this.safePaddingLeft,
    required this.safePaddingRight,
    required this.viewPaddingBottom,
    required this.viewInsetsBottom,
    required this.bottomSystemInset,
    required this.appReservedTop,
    required this.appReservedBottom,
    required this.contentPadding,
    required this.usableWidth,
    required this.usableHeight,
    required this.designScale,
    required this.isConstrainedHeight,
    required this.isSmallPhonePortrait,
    required this.safeAreaApplied,
  });

  final Size screenSize;
  final Size layoutSize;

  final double safePaddingTop;
  final double safePaddingBottom;
  final double safePaddingLeft;
  final double safePaddingRight;

  final double viewPaddingBottom;
  final double viewInsetsBottom;
  final double bottomSystemInset;

  final double appReservedTop;
  final double appReservedBottom;
  final EdgeInsets contentPadding;

  final double usableWidth;
  final double usableHeight;

  final KfgDesignScaleData designScale;

  final bool isConstrainedHeight;
  final bool isSmallPhonePortrait;
  final bool safeAreaApplied;

  static KfgViewportData fromLayout({
    required BuildContext context,
    required BoxConstraints constraints,
    required EdgeInsets contentPadding,
    bool safeAreaApplied = true,
    double appReservedTop = 0,
    double appReservedBottom = 0,
  }) {
    final media = MediaQuery.of(context);
    final layoutWidth = constraints.maxWidth;
    final layoutHeight = constraints.maxHeight;

    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;
    final safeLeft = media.padding.left;
    final safeRight = media.padding.right;

    final viewPaddingBottom = media.viewPadding.bottom;
    final viewInsetsBottom = media.viewInsets.bottom;
    final bottomSystemInset = math.max(viewPaddingBottom, safeBottom);

    final usableWidth = (layoutWidth - contentPadding.horizontal)
        .clamp(0.0, double.infinity)
        .toDouble();

    final usableHeight =
        (layoutHeight -
                contentPadding.vertical -
                appReservedTop -
                appReservedBottom)
            .clamp(0.0, double.infinity)
            .toDouble();

    final designScale = KfgDesignScale.scaleForConstraints(
      BoxConstraints.tightFor(width: usableWidth, height: usableHeight),
    );

    final constrainedHeight =
        usableHeight < KfgDesignScale.referenceHeight * 0.82;
    final smallPortrait =
        media.orientation == Orientation.portrait &&
        media.size.width <= 420 &&
        media.size.height <= 920;

    return KfgViewportData(
      screenSize: media.size,
      layoutSize: Size(layoutWidth, layoutHeight),
      safePaddingTop: safeTop,
      safePaddingBottom: safeBottom,
      safePaddingLeft: safeLeft,
      safePaddingRight: safeRight,
      viewPaddingBottom: viewPaddingBottom,
      viewInsetsBottom: viewInsetsBottom,
      bottomSystemInset: bottomSystemInset,
      appReservedTop: appReservedTop,
      appReservedBottom: appReservedBottom,
      contentPadding: contentPadding,
      usableWidth: usableWidth,
      usableHeight: usableHeight,
      designScale: designScale,
      isConstrainedHeight: constrainedHeight,
      isSmallPhonePortrait: smallPortrait,
      safeAreaApplied: safeAreaApplied,
    );
  }
}

abstract final class KfgViewportDebug {
  static const bool enabledByEnvironment = bool.fromEnvironment(
    'KFG_VIEWPORT_DEBUG',
    defaultValue: false,
  );
}

class KfgViewportDebugOverlay extends StatelessWidget {
  const KfgViewportDebugOverlay({super.key, required this.data});

  final KfgViewportData data;

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 10,
      height: 1.15,
      fontWeight: FontWeight.w600,
    );

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.cyanAccent.withValues(alpha: 0.85),
            ),
          ),
          child: DefaultTextStyle(
            style: textStyle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('KFG VIEWPORT DEBUG'),
                Text(
                  'screen: ${data.screenSize.width.toStringAsFixed(1)} x ${data.screenSize.height.toStringAsFixed(1)}',
                ),
                Text(
                  'layout: ${data.layoutSize.width.toStringAsFixed(1)} x ${data.layoutSize.height.toStringAsFixed(1)}',
                ),
                Text(
                  'usable: ${data.usableWidth.toStringAsFixed(1)} x ${data.usableHeight.toStringAsFixed(1)}',
                ),
                Text(
                  'safe top/btm: ${data.safePaddingTop.toStringAsFixed(1)} / ${data.safePaddingBottom.toStringAsFixed(1)}',
                ),
                Text(
                  'viewPad btm: ${data.viewPaddingBottom.toStringAsFixed(1)}',
                ),
                Text(
                  'viewInset btm: ${data.viewInsetsBottom.toStringAsFixed(1)}',
                ),
                Text(
                  'system btm: ${data.bottomSystemInset.toStringAsFixed(1)}',
                ),
                Text(
                  'reserved top/btm: ${data.appReservedTop.toStringAsFixed(1)} / ${data.appReservedBottom.toStringAsFixed(1)}',
                ),
                Text(
                  'scale x/y: ${data.designScale.scaleX.toStringAsFixed(3)} / ${data.designScale.scaleY.toStringAsFixed(3)}',
                ),
                Text('scale: ${data.designScale.scale.toStringAsFixed(3)}'),
                Text('safeArea applied: ${data.safeAreaApplied}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

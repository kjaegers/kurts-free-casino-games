import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/animation/kfg_web_animation_speed.dart';
import '../core/layout/kfg_design_scale.dart';
import '../core/widgets/kfg_settings_scope.dart';
import '../core/widgets/kfg_text_scale.dart';
import 'kfg_router.dart';
import 'kfg_theme.dart';

/// Root widget of Kurt's Free Casino Games.
class KfgApp extends StatelessWidget {
  const KfgApp({super.key});

  static const double _phoneAspectRatio =
      KfgDesignScale.referenceWidth / KfgDesignScale.referenceHeight;

  static bool get _usePhoneContainer {
    return kIsWeb || defaultTargetPlatform == TargetPlatform.windows;
  }

  Widget _buildScaledContent(BuildContext context, Widget content) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleData = KfgDesignScale.scaleForConstraints(constraints);

        return KfgSettingsScope(
          child: Builder(
            // Applies the Animations setting over the device's
            // reduce-motion flag, rebuilding when the setting changes.
            builder: (context) {
              KfgSettingsScope.of(context);
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: kfgReduceMotion),
                child: KfgDesignScaleScope(
                  data: scaleData,
                  // Clamped below the override: the MediaQuery it adds
                  // copies its context's data, and from above it would put
                  // the device's disableAnimations back.
                  child: Builder(
                    builder: (context) => KfgTextScale.clampGlobal(
                      context: context,
                      child: content,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Kurt's Free Casino Games",
      debugShowCheckedModeBanner: false,
      theme: KfgTheme.dark,
      initialRoute: KfgRoutes.home,
      onGenerateRoute: KfgRouter.onGenerateRoute,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();

        if (_usePhoneContainer) {
          return ColoredBox(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _phoneAspectRatio,
                child: ClipRect(child: _buildScaledContent(context, content)),
              ),
            ),
          );
        }

        return _buildScaledContent(context, content);
      },
    );
  }
}

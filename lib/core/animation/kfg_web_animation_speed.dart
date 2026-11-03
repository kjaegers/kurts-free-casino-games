import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart'
    show BuildContext, MediaQuery, WidgetsBinding;

import '../services/settings_service.dart';

/// How much longer purely-cosmetic animation durations run on Flutter Web.
///
/// Web rendering — even in a release/CanvasKit build — doesn't consistently
/// hit the frame rate native Android does, especially for boards with many
/// simultaneously-animating tiles or shadow/gradient-heavy widgets. Short
/// animations tuned for ~60fps native rendering (100-300ms) end up looking
/// like an abrupt jump on web, because too few frames get painted inside
/// that window for the motion to read as motion.
///
/// [kfgAnimDuration] stretches such a duration on web only; every other
/// platform gets the original value back unchanged.
const double kfgWebAnimationSpeedFactor = 1.8;

/// Overrides the platform's reduce-motion setting in tests.
@visibleForTesting
bool? debugKfgReduceMotionOverride;

/// Whether animations are off: the player's Animations setting, or when
/// that follows the device, whether the OS / browser asks to reduce motion
/// (the flag that backs `MediaQuery.disableAnimations`). `KfgApp` puts the
/// result into `MediaQuery.disableAnimations` for the whole app.
bool get kfgReduceMotion {
  final override = debugKfgReduceMotionOverride;
  if (override != null) return override;
  return switch (SettingsService.instance.settings.animations) {
    AnimationsSetting.on => false,
    AnimationsSetting.off => true,
    AnimationsSetting.followDevice =>
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations,
  };
}

/// Adjusts a purely-cosmetic animation [duration] for the platform.
///
/// Returns [Duration.zero] when the player has asked to reduce motion, so
/// the change happens instantly. Otherwise stretches it on web so it stays
/// legible, and returns it unchanged on every other platform.
///
/// Only use this for the visual flourish around an already-decided game
/// state change (a slide, flip, pop, or fade) — never for gameplay-timing
/// values like spawn rates, physics ticks, or countdowns, since those must
/// run at the same real-world pace on every platform.
///
/// This reads the platform setting directly so it works without a
/// [BuildContext]. Inside widgets, prefer [kfgAnimDurationOf], which also
/// honours a `MediaQuery.disableAnimations` override in the widget tree.
Duration kfgAnimDuration(Duration duration) {
  if (kfgReduceMotion) return Duration.zero;
  if (!kIsWeb) return duration;
  return duration * kfgWebAnimationSpeedFactor;
}

/// [kfgAnimDuration], also honouring `MediaQuery.disableAnimations` from
/// [context].
Duration kfgAnimDurationOf(BuildContext context, Duration duration) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
    return Duration.zero;
  }
  return kfgAnimDuration(duration);
}

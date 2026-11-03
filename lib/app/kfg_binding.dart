import 'package:flutter/widgets.dart';

import '../core/animation/kfg_web_animation_speed.dart';

/// The app's binding: the Flutter default, except that the framework's own
/// reduce-motion flag follows the player's Animations setting.
///
/// Every [AnimationController] (ours and the ones inside implicit animations)
/// runs at 5% of its duration while `SemanticsBinding.disableAnimations` is
/// true, and by default that flag is the OS / browser setting alone. Browsers
/// on Windows report reduce motion whenever Windows' "Animation effects" is
/// off, so without this override Settings > Animations > On still left every
/// animation as a jump.
class KfgBinding extends WidgetsFlutterBinding {
  @override
  bool get disableAnimations => kfgReduceMotion;
}

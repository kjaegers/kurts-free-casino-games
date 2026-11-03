import 'package:flutter/material.dart';

import '../core/widgets/kfg_settings_scope.dart';
import '../features/games/blackjack/blackjack_screen.dart';
import '../features/games/roulette/roulette_screen.dart';
import '../features/games/slots_cherry_run/slots_cherry_run_screen.dart';
import '../features/games/slots_retro_tech/slots_retro_tech_screen.dart';
import '../features/games/texas_holdem/texas_holdem_screen.dart';
import '../features/games/video_poker/video_poker_screen.dart';
import '../core/widgets/kfg_text_scale.dart';
import '../core/widgets/kfg_app_scaffold.dart';

/// Named route path constants.
///
/// These strings must match the [routeName] values in [GameRegistry].
abstract final class KfgRoutes {
  static const String home = '/';

  static const String videoPoker = '/game/video-poker';
  static const String slotsCherryRun = '/game/slots-cherry-run';
  static const String slotsRetroTech = '/game/slots-retro-tech';
  static const String blackjack = '/game/blackjack';
  static const String roulette = '/game/roulette';
  static const String texasHoldem = '/game/texas-holdem';
}

/// Generates routes for the entire app.
abstract final class KfgRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (context) {
          final page = builder(context);
          return KfgTextScale.clampForRoute(
            context: context,
            routeName: settings.name,
            largeText: KfgSettingsScope.of(context).largeText,
            child: page,
          );
        },
      );
    }
    return MaterialPageRoute(
      settings: settings,
      builder: (_) =>
          const Scaffold(body: Center(child: Text('Page not found'))),
    );
  }

  static final Map<String, WidgetBuilder> _routes = {
    KfgRoutes.home: (_) => const KfgAppScaffold(),
    KfgRoutes.videoPoker: (_) => const VideoPokerScreen(),
    KfgRoutes.slotsCherryRun: (_) => const SlotsCherryRunScreen(),
    KfgRoutes.slotsRetroTech: (_) => const SlotsRetroTechScreen(),
    KfgRoutes.blackjack: (_) => const BlackjackScreen(),
    KfgRoutes.roulette: (_) => const RouletteScreen(),
    KfgRoutes.texasHoldem: (_) => const TexasHoldemScreen(),
  };
}

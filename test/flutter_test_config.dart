import 'dart:async';

import 'package:kurts_free_casino_games/core/audio/kfg_tone_player.dart';

/// Runs before every test file in this directory.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // There is no audio plugin under `flutter test`; sounds are checked by
  // overriding KfgTonePlayer.playFrequency instead.
  KfgTonePlayer.debugSkipPlatformAudio = true;
  await testMain();
}

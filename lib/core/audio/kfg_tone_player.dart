import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';
import 'kfg_tone_generator.dart';

/// Plays short, synthesized pure-tone sound effects — e.g. one distinct
/// tone per button in a Simon-style game. No audio assets are bundled;
/// each frequency's WAV bytes are generated once (see
/// [generateToneWavBytes]) and cached for reuse.
///
/// Respects [SettingsService]'s app-wide "Sound Effects" toggle, and never
/// lets a playback failure (missing codec, denied audio focus, no
/// platform audio channel at all — e.g. in a widget test) propagate: a
/// sound effect is never worth crashing a game over.
class KfgTonePlayer {
  KfgTonePlayer({
    this.toneDuration = const Duration(milliseconds: 180),
    this.amplitude = 0.5,
  });

  final Duration toneDuration;

  /// Peak level from 0 to 1; lower it for frequent, background blips.
  final double amplitude;

  /// Skips the platform audio plugin entirely. Set for the whole test
  /// suite by `test/flutter_test_config.dart`, where no plugin exists;
  /// tests that check sounds override [playFrequency] instead.
  @visibleForTesting
  static bool debugSkipPlatformAudio = false;

  final Map<double, Uint8List> _cache = {};
  AudioPlayer? _player;
  bool _disposed = false;

  Future<void> playFrequency(double frequencyHz) {
    if (_disposed ||
        debugSkipPlatformAudio ||
        !SettingsService.instance.settings.soundEnabled) {
      return Future<void>.value();
    }
    return _guarded(() async {
      final player = _player ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.stop);
      final bytes = _cache.putIfAbsent(
        frequencyHz,
        () => generateToneWavBytes(
          frequencyHz: frequencyHz,
          duration: toneDuration,
          amplitude: amplitude,
        ),
      );
      await player.stop();
      await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    });
  }

  /// Runs [body] in a zone that swallows every error, including ones from
  /// futures the audio plugin starts internally and never hands back (e.g.
  /// its one-time platform setup), which a plain try/catch can't reach. No
  /// platform audio channel, denied permission, unsupported codec — none of
  /// these should ever take the game down with them.
  static Future<void> _guarded(Future<void> Function() body) {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    runZonedGuarded(() => body().then((_) => finish()), (_, _) => finish());
    return done.future;
  }

  /// Plays [frequenciesHz] one after another, starting a new tone every
  /// [gap] (default: [toneDuration], so the notes run together) — e.g. a
  /// C5-E5-G5-C6 arpeggio for a win. Stops early if sound is muted or this
  /// player is disposed part-way through.
  Future<void> playSequence(List<double> frequenciesHz, {Duration? gap}) async {
    final step = gap ?? toneDuration;
    for (var i = 0; i < frequenciesHz.length; i++) {
      if (_disposed || !SettingsService.instance.settings.soundEnabled) return;
      if (i > 0) {
        await _pause(step);
        if (_disposed || !SettingsService.instance.settings.soundEnabled) {
          return;
        }
      }
      await playFrequency(frequenciesHz[i]);
    }
  }

  /// The gap timers of sequences in progress, cancelled by [dispose] so a
  /// disposed player leaves nothing pending.
  final Set<Timer> _gapTimers = {};

  Future<void> _pause(Duration duration) {
    final done = Completer<void>();
    late final Timer timer;
    timer = Timer(duration, () {
      _gapTimers.remove(timer);
      done.complete();
    });
    _gapTimers.add(timer);
    return done.future;
  }

  void dispose() {
    _disposed = true;
    for (final timer in _gapTimers) {
      timer.cancel();
    }
    _gapTimers.clear();
    final player = _player;
    if (player != null) unawaited(_guarded(player.dispose));
  }
}

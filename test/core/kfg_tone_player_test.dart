import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/audio/kfg_tone_player.dart';
import 'package:kurts_free_casino_games/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records tones instead of playing them, but keeps the base class's
/// sequencing, mute and dispose logic.
class _RecordingTonePlayer extends KfgTonePlayer {
  _RecordingTonePlayer()
    : super(toneDuration: const Duration(milliseconds: 10));

  final List<double> played = [];
  void Function()? onPlay;

  @override
  Future<void> playFrequency(double frequencyHz) async {
    played.add(frequencyHz);
    onPlay?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService.instance;
    settings.update(settings.settings.copyWith(soundEnabled: true));
  });

  test('playSequence plays every tone in order', () async {
    final player = _RecordingTonePlayer();
    await player.playSequence([523, 659, 784, 1046]);
    expect(player.played, [523, 659, 784, 1046]);
  });

  test('playSequence plays nothing while muted', () async {
    final settings = SettingsService.instance;
    settings.update(settings.settings.copyWith(soundEnabled: false));
    final player = _RecordingTonePlayer();
    await player.playSequence([523, 659]);
    expect(player.played, isEmpty);
  });

  test('playSequence stops when muted part-way through', () async {
    final player = _RecordingTonePlayer();
    player.onPlay = () {
      final settings = SettingsService.instance;
      settings.update(settings.settings.copyWith(soundEnabled: false));
    };
    await player.playSequence([523, 659, 784]);
    expect(player.played, [523]);
  });

  test('playSequence stops when disposed part-way through', () async {
    final player = _RecordingTonePlayer();
    player.onPlay = player.dispose;
    await player.playSequence([523, 659, 784]);
    expect(player.played, [523]);
  });
}

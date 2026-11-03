import 'package:kurts_free_casino_games/core/audio/kfg_tone_player.dart';
import 'package:kurts_free_casino_games/core/services/persistent_storage.dart';
import 'package:kurts_free_casino_games/features/games/slots_cherry_run/logic/cherry_run_reels.dart';

/// Stops that put [middle] (one symbol per reel) on the middle row: the
/// first stop on each reel showing that symbol.
List<int> stopsFor(List<CherryRunSymbol> middle) => [
  for (var reel = 0; reel < cherryRunReelCount; reel++)
    cherryRunReels[reel].indexOf(middle[reel]),
];

/// Stops where no line pays anything.
final List<int> losingStops = _findLosingStops();

List<int> _findLosingStops() {
  for (var a = 0; a < cherryRunStopCount; a++) {
    for (var b = 0; b < cherryRunStopCount; b++) {
      for (var c = 0; c < cherryRunStopCount; c++) {
        final rows = cherryRunWindow([a, b, c]);
        final pays = rows.any(
          (r) =>
              r[0] == CherryRunSymbol.cherry ||
              (r[0] == r[1] && r[1] == r[2]) ||
              r.every((s) => s.isBar),
        );
        if (!pays) return [a, b, c];
      }
    }
  }
  throw StateError('No losing stops');
}

/// Lands the queued stops in order, then [losingStops] forever.
class ScriptedStops {
  ScriptedStops([List<List<int>> spins = const []]) : _spins = List.of(spins);

  final List<List<int>> _spins;
  List<int>? _current;
  int spins = 0;

  void queue(List<int> stops) => _spins.add(stops);

  int call(int reel) {
    if (reel == 0) {
      spins++;
      _current = _spins.isEmpty ? losingStops : _spins.removeAt(0);
    }
    return _current![reel];
  }
}

class SilentTonePlayer extends KfgTonePlayer {
  SilentTonePlayer();

  @override
  Future<void> playFrequency(double frequencyHz) async {}

  @override
  void dispose() {}
}

class MemoryPersistentStorage implements PersistentStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<Set<String>> getKeys() async => values.keys.toSet();
}

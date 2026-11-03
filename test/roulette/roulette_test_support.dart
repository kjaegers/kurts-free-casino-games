import 'package:kurts_free_casino_games/core/audio/kfg_tone_player.dart';
import 'package:kurts_free_casino_games/core/services/persistent_storage.dart';

/// Lands the queued pockets in order, then [fallback] forever.
class ScriptedPockets {
  ScriptedPockets([List<int> pockets = const [], this.fallback = 36])
    : _pockets = List.of(pockets);

  final List<int> _pockets;
  final int fallback;
  int spins = 0;

  void queue(int pocket) => _pockets.add(pocket);

  int call() {
    spins++;
    return _pockets.isEmpty ? fallback : _pockets.removeAt(0);
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

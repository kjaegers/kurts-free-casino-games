import 'package:kurts_free_casino_games/core/audio/kfg_tone_player.dart';
import 'package:kurts_free_casino_games/core/services/persistent_storage.dart';
import 'package:kurts_free_casino_games/features/games/slots_retro_tech/logic/retro_tech_symbols.dart';

/// One letter per symbol, for writing grids in tests.
const Map<String, RetroTechSymbol> symbolLetters = {
  'T': RetroTechSymbol.token,
  'R': RetroTechSymbol.runner,
  'J': RetroTechSymbol.joystick,
  'M': RetroTechSymbol.monitor,
  'F': RetroTechSymbol.floppy,
  'G': RetroTechSymbol.cartridge,
  'C': RetroTechSymbol.cassette,
  'X': RetroTechSymbol.chip,
};

List<RetroTechSymbol> symbolsOf(String letters) => [
  for (final letter in letters.split('')) symbolLetters[letter]!,
];

/// A grid from five rows of five letters, top to bottom.
RetroTechGrid gridOf(List<String> rows) => [
  for (final row in rows) ...symbolsOf(row),
];

/// A grid with no cluster: neighbouring cells always differ.
const List<String> quietRows = ['TRJMF', 'RJMFG', 'JMFGC', 'MFGCX', 'FGCXT'];

/// Four Microchips in the top-left corner, otherwise quiet.
const List<String> chipCornerRows = [
  'XXJMF',
  'XRMFG',
  'XMFGC',
  'MFGCX',
  'FGCXT',
];

/// The draws that fill [rows] (top to bottom), then drop [refills] (one
/// string per column, in the order drawn) into the gaps cascades leave.
List<List<RetroTechSymbol>> dropsFor(
  List<String> rows, [
  List<String> refills = const ['', '', '', '', ''],
]) => [
  for (var column = 0; column < retroTechColumns; column++)
    [
      for (var row = retroTechRows - 1; row >= 0; row--)
        symbolLetters[rows[row][column]]!,
      ...symbolsOf(refills[column]),
    ],
];

/// Draws the queued spins' symbols in order, then quiet grids forever.
class ScriptedDraws {
  ScriptedDraws([List<List<List<RetroTechSymbol>>> spins = const []])
    : _spins = List.of(spins);

  final List<List<List<RetroTechSymbol>>> _spins;
  List<List<RetroTechSymbol>>? _current;
  final List<int> _used = List.filled(retroTechColumns, 0);
  int spins = 0;

  void queue(List<List<RetroTechSymbol>> drops) => _spins.add(drops);

  RetroTechSymbol call(int column) {
    final current = _current;
    final done =
        current == null ||
        [
          for (var c = 0; c < retroTechColumns; c++)
            _used[c] >= current[c].length,
        ].every((d) => d);
    if (done) {
      spins++;
      _current = _spins.isEmpty ? dropsFor(quietRows) : _spins.removeAt(0);
      _used.fillRange(0, retroTechColumns, 0);
    }
    return _current![column][_used[column]++];
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

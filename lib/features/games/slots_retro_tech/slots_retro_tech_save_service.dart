import 'dart:async';
import 'dart:convert';

import '../../../core/services/persistent_storage.dart';
import 'logic/retro_tech_game.dart';

/// Persists a Retro Tech spin that hasn't been paid yet via
/// [persistentStorage], following the per-game save service pattern.
///
/// A spin is only saved while its cascade is playing out: the bet has
/// already left the credit balance, so if the app closes before it ends,
/// the same spin is paid on return rather than lost or spun again.
class RetroTechSaveService {
  RetroTechSaveService({PersistentStorage? storage})
    : _storage = storage ?? persistentStorage;

  final PersistentStorage _storage;

  static const String storageKey = 'kfcg_slots_retro_tech_save_v1';

  /// The saved spin, or null when there is none or it is malformed.
  Future<RetroTechGame?> load() async {
    try {
      final raw = await _storage.getString(storageKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return RetroTechGame.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RetroTechGame game) =>
      _storage.setString(storageKey, jsonEncode(game.toJson()));

  Future<void> clear() => _storage.remove(storageKey);
}

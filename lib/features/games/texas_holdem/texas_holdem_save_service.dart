import 'dart:async';
import 'dart:convert';

import '../../../core/services/persistent_storage.dart';
import 'logic/holdem_table.dart';

/// Persists the Texas Hold'em table via [persistentStorage], following the
/// per-game save service pattern.
///
/// The table is saved once a hand has been dealt: between hands so the
/// opponents keep their stacks, and after every action while a hand is in
/// play, whose chips have already left the credit balance, so it resumes
/// exactly as dealt rather than being redealt.
class TexasHoldemSaveService {
  TexasHoldemSaveService({PersistentStorage? storage})
    : _storage = storage ?? persistentStorage;

  final PersistentStorage _storage;

  static const String storageKey = 'kfcg_texas_holdem_save_v1';

  /// The saved table, or null when there is none or it is malformed.
  Future<HoldemTable?> load() async {
    try {
      final raw = await _storage.getString(storageKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return HoldemTable.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(HoldemTable table) =>
      _storage.setString(storageKey, jsonEncode(table.toJson()));

  Future<void> clear() => _storage.remove(storageKey);
}

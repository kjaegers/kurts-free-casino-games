import 'dart:async';
import 'dart:convert';

import '../../../core/services/persistent_storage.dart';
import 'logic/blackjack_game.dart';

/// Persists the one Blackjack round in play via [persistentStorage],
/// following the per-game save service pattern.
///
/// Only a round in play is saved: its bets have already left the credit
/// balance, so it must resume exactly as dealt (same cards, same shoe)
/// rather than being redealt.
class BlackjackSaveService {
  BlackjackSaveService({PersistentStorage? storage})
    : _storage = storage ?? persistentStorage;

  final PersistentStorage _storage;

  static const String storageKey = 'kfcg_blackjack_save_v1';

  /// The saved round, or null when there is none or it is malformed.
  Future<BlackjackGame?> load() async {
    try {
      final raw = await _storage.getString(storageKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return BlackjackGame.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(BlackjackGame game) =>
      _storage.setString(storageKey, jsonEncode(game.toJson()));

  Future<void> clear() => _storage.remove(storageKey);
}

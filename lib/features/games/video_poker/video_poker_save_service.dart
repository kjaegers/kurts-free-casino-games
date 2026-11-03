import 'dart:async';
import 'dart:convert';

import '../../../core/services/persistent_storage.dart';
import 'logic/video_poker_game.dart';

/// Persists the one Video Poker hand in progress via [persistentStorage],
/// following the per-game save service pattern.
///
/// Only a dealt hand awaiting its draw is saved: its bet has already left
/// the credit balance, so it must resume exactly as dealt (same cards, same
/// draw order) rather than being redealt.
class VideoPokerSaveService {
  VideoPokerSaveService({PersistentStorage? storage})
    : _storage = storage ?? persistentStorage;

  final PersistentStorage _storage;

  static const String storageKey = 'kfcg_video_poker_save_v1';

  /// The saved hand, or null when there is none or it is malformed.
  Future<VideoPokerGame?> load() async {
    try {
      final raw = await _storage.getString(storageKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return VideoPokerGame.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(VideoPokerGame game) =>
      _storage.setString(storageKey, jsonEncode(game.toJson()));

  Future<void> clear() => _storage.remove(storageKey);
}

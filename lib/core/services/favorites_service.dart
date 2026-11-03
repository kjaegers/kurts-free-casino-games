import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'persistent_storage.dart';

/// Tracks which games the player has marked as favorites.
///
/// Favorites are stored locally as a JSON list of game ids, separately from
/// statistics so that resetting stats never clears a player's favorites.
class FavoritesService extends ChangeNotifier {
  FavoritesService._() {
    // Best-effort eager load. main() also awaits ensureLoaded() at startup.
    unawaited(ensureLoaded());
  }

  static final FavoritesService instance = FavoritesService._();

  @visibleForTesting
  static const String storageKey = 'kfcg_favorites_v1';

  Set<String> _favoriteIds = <String>{};
  bool _loaded = false;
  Future<void>? _loadFuture;

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  bool isFavorite(String gameId) => _favoriteIds.contains(gameId);

  /// Ensures persisted favorites have been loaded into memory.
  ///
  /// When [forceReload] is true, in-memory values are replaced with what's
  /// currently in storage.
  Future<void> ensureLoaded({bool forceReload = false}) async {
    if (forceReload) {
      _loaded = false;
      _loadFuture = null;
    }
    if (_loaded) return;
    _loadFuture ??= _loadFromStorage();
    await _loadFuture;
  }

  void toggle(String gameId) {
    if (!_favoriteIds.remove(gameId)) {
      _favoriteIds.add(gameId);
    }
    notifyListeners();
    unawaited(_saveToStorage());
  }

  @visibleForTesting
  void clearForTest() {
    _favoriteIds = <String>{};
    notifyListeners();
  }

  @visibleForTesting
  Future<void> saveNowForTest() => _saveToStorage();

  Future<void> _saveToStorage() async {
    try {
      final ids = _favoriteIds.toList()..sort();
      await persistentStorage.setString(storageKey, jsonEncode(ids));
    } catch (e, st) {
      debugPrint('FavoritesService: failed to save favorites: $e\n$st');
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final raw = await persistentStorage.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        // Ignore malformed data rather than failing; unknown ids are harmless
        // and simply never match a registered game.
        if (decoded is List) {
          _favoriteIds = decoded.whereType<String>().toSet();
        }
      }
    } catch (e, st) {
      debugPrint('FavoritesService: failed to load favorites: $e\n$st');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }
}

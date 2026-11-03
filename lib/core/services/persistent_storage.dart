import 'persistent_storage_backend.dart'
    if (dart.library.html) 'persistent_storage_backend_web.dart'
    as backend;

/// Minimal key/value string storage used for between-session persistence.
abstract interface class PersistentStorage {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);

  /// Every key currently stored. Used to clear families of keys that share a
  /// prefix (e.g. one Daily Challenge record per date).
  Future<Set<String>> getKeys();
}

final PersistentStorage persistentStorage = backend.createPersistentStorage();

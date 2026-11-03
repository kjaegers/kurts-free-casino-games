// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'persistent_storage.dart';

PersistentStorage createPersistentStorage() => _BrowserLocalStorage();

class _BrowserLocalStorage implements PersistentStorage {
  @override
  Future<String?> getString(String key) async {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {
      // Keep persistence best-effort on browsers that block local storage.
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      html.window.localStorage.remove(key);
    } catch (_) {
      // Keep persistence best-effort on browsers that block local storage.
    }
  }

  @override
  Future<Set<String>> getKeys() async {
    try {
      return html.window.localStorage.keys.toSet();
    } catch (_) {
      return const {};
    }
  }
}

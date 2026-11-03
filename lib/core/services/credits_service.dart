import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'persistent_storage.dart';

/// The player's play-money credit balance, shared by every game.
///
/// Credits are play money only: never bought, never redeemed. Running out is
/// never a wall: [reset] refills the balance to [startingBalance] for free,
/// instantly, whenever the player asks. Games take a bet with [debit] when a
/// round starts and pay winnings with [credit] when it ends, so the balance
/// shown everywhere is always the real one.
class CreditsService extends ChangeNotifier {
  CreditsService({PersistentStorage? storage})
    : _storage = storage ?? persistentStorage;

  static final CreditsService instance = CreditsService();

  static const String storageKey = 'kfcg_credits_v1';

  /// A new player's balance, and what a reset refills to.
  static const int startingBalance = 1000;

  /// Keeps a runaway balance well inside integer range on every platform.
  static const int maxBalance = 999999999999;

  static const int _schemaVersion = 1;

  final PersistentStorage _storage;
  int _balance = startingBalance;
  bool _loaded = false;
  Future<void>? _loadFuture;

  int get balance => _balance;
  bool get isLoaded => _loaded;

  bool canAfford(int amount) => amount >= 0 && amount <= _balance;

  /// Loads the stored balance. Safe to call repeatedly; [forceReload]
  /// replaces the in-memory value with what's in storage.
  Future<void> ensureLoaded({bool forceReload = false}) async {
    if (forceReload) {
      _loaded = false;
      _loadFuture = null;
    }
    if (_loaded) return;
    _loadFuture ??= _load();
    await _loadFuture;
  }

  /// Takes [amount] for a bet. Returns false, changing nothing, when the
  /// balance can't cover it.
  bool debit(int amount) {
    if (amount <= 0 || !canAfford(amount)) return false;
    _balance -= amount;
    _changed();
    return true;
  }

  /// Pays [amount] (winnings, or a returned bet) into the balance.
  void credit(int amount) {
    if (amount <= 0) return;
    _balance = (_balance + amount).clamp(0, maxBalance);
    _changed();
  }

  /// Refills the balance to [startingBalance]. Free, and always available.
  void reset() {
    _balance = startingBalance;
    _changed();
  }

  /// Writes the balance and waits for it to finish.
  Future<void> saveNow() => _save();

  void _changed() {
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await _storage.setString(
        storageKey,
        jsonEncode({'version': _schemaVersion, 'balance': _balance}),
      );
    } catch (e, st) {
      debugPrint('CreditsService: failed to save credits: $e\n$st');
    }
  }

  /// Missing or malformed data gives a new player's balance rather than
  /// zero, so a corrupt save never leaves the player empty-handed.
  Future<void> _load() async {
    try {
      final raw = await _storage.getString(storageKey);
      _balance = parseBalance(raw);
    } catch (e, st) {
      debugPrint('CreditsService: failed to load credits: $e\n$st');
    } finally {
      _loaded = true;
      _loadFuture = null;
      notifyListeners();
    }
  }

  @visibleForTesting
  static int parseBalance(String? raw) {
    if (raw == null || raw.isEmpty) return startingBalance;
    try {
      final decoded = jsonDecode(raw);
      final balance = decoded is Map ? decoded['balance'] : null;
      if (balance is! int || balance < 0) return startingBalance;
      return balance.clamp(0, maxBalance);
    } on FormatException {
      return startingBalance;
    }
  }
}

/// [amount] with thousands separators, e.g. `12,345`.
String formatCredits(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

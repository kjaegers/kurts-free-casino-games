import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/services/credits_service.dart';

import '../video_poker/video_poker_test_support.dart';

void main() {
  group('CreditsService', () {
    test('a new player starts with the starting balance', () async {
      final credits = CreditsService(storage: MemoryPersistentStorage());
      await credits.ensureLoaded();
      expect(credits.balance, CreditsService.startingBalance);
    });

    test('debit refuses what the balance cannot cover', () async {
      final credits = CreditsService(storage: MemoryPersistentStorage());
      await credits.ensureLoaded();
      expect(credits.debit(1001), isFalse);
      expect(credits.debit(0), isFalse);
      expect(credits.debit(-5), isFalse);
      expect(credits.balance, 1000);
      expect(credits.debit(1000), isTrue);
      expect(credits.balance, 0);
      credits.credit(-3);
      expect(credits.balance, 0);
      credits.credit(40);
      expect(credits.balance, 40);
    });

    test('persists the balance and reset refills it', () async {
      final storage = MemoryPersistentStorage();
      final credits = CreditsService(storage: storage);
      await credits.ensureLoaded();
      credits.debit(250);
      await credits.saveNow();

      final reloaded = CreditsService(storage: storage);
      await reloaded.ensureLoaded();
      expect(reloaded.balance, 750);
      reloaded.reset();
      expect(reloaded.balance, CreditsService.startingBalance);
    });

    test('the key is namespaced apart from Kurt\'s Free Games', () {
      expect(CreditsService.storageKey, startsWith('kfcg_'));
    });

    test('malformed data gives the starting balance, never zero', () {
      for (final raw in [
        null,
        '',
        'not json',
        '[]',
        '{"balance":"lots"}',
        '{"balance":-20}',
      ]) {
        expect(
          CreditsService.parseBalance(raw),
          CreditsService.startingBalance,
          reason: raw,
        );
      }
      expect(CreditsService.parseBalance('{"version":1,"balance":0}'), 0);
      expect(CreditsService.parseBalance('{"version":1,"balance":42}'), 42);
    });

    test('formats with thousands separators', () {
      expect(formatCredits(0), '0');
      expect(formatCredits(999), '999');
      expect(formatCredits(1000), '1,000');
      expect(formatCredits(1234567), '1,234,567');
      expect(formatCredits(-4000), '-4,000');
    });
  });
}

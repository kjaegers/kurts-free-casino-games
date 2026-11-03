import 'package:flutter_test/flutter_test.dart';
import 'package:kurts_free_casino_games/core/services/favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesService', () {
    final service = FavoritesService.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await service.ensureLoaded(forceReload: true);
      service.clearForTest();
    });

    test('toggle adds and removes a favorite', () {
      expect(service.isFavorite('blackjack'), isFalse);

      service.toggle('blackjack');
      expect(service.isFavorite('blackjack'), isTrue);

      service.toggle('blackjack');
      expect(service.isFavorite('blackjack'), isFalse);
    });

    test('notifies listeners on toggle', () {
      var notifications = 0;
      void listener() => notifications++;
      service.addListener(listener);
      addTearDown(() => service.removeListener(listener));

      service.toggle('klondike');
      expect(notifications, 1);
    });

    test('favorites persist across reloads', () async {
      service.toggle('blackjack');
      service.toggle('roulette');
      await service.saveNowForTest();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(FavoritesService.storageKey),
        '["blackjack","roulette"]',
      );

      service.clearForTest();
      await service.ensureLoaded(forceReload: true);
      expect(service.favoriteIds, {'blackjack', 'roulette'});
    });

    test('corrupted saved data is ignored safely', () async {
      SharedPreferences.setMockInitialValues({
        FavoritesService.storageKey: '{not valid json',
      });
      await service.ensureLoaded(forceReload: true);
      expect(service.favoriteIds, isEmpty);

      SharedPreferences.setMockInitialValues({
        FavoritesService.storageKey: '["blackjack", 42, null]',
      });
      await service.ensureLoaded(forceReload: true);
      expect(service.favoriteIds, {'blackjack'});
    });
  });
}

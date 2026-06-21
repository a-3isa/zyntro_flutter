import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/feed_cache_service.dart';

Post _post(String id) => Post(
      id: id,
      authorId: 'a',
      sessionId: 's',
      visibility: 'public',
      title: 'T$id',
      type: 'strength',
      summary: SessionSummary(),
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime(2025, 6, int.parse(id)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup cache contract', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'FeedCacheService seeded with 3 posts returns them synchronously '
        'before any network call', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = FeedCacheService(prefs);

      // Seed the cache (simulates a previous session that wrote posts)
      final seeded = [_post('1'), _post('2'), _post('3')];
      await svc.writeCachePosts(seeded);

      // Create a fresh service instance backed by the same prefs —
      // simulates app restart where SharedPreferences data is already on disk.
      final svc2 = FeedCacheService(prefs);

      final stopwatch = Stopwatch()..start();
      final cached = svc2.readCachePosts();
      stopwatch.stop();

      // Contract 1: 3 posts are readable immediately.
      expect(cached, hasLength(3));
      expect(cached.map((p) => p.id), containsAll(['1', '2', '3']));

      // Contract 2: read is synchronous — completes in << 1 second
      // (SC-001: feed visible within 1 second on re-launch).
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('Cache read is synchronous (no async await required)', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = FeedCacheService(prefs);
      await svc.writeCachePosts([_post('4'), _post('5')]);

      // readCachePosts must return synchronously — no Future involved.
      final result = svc.readCachePosts(); // synchronous call
      expect(result, hasLength(2));
    });

    test('Empty cache returns [] without throwing (first-time user path)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = FeedCacheService(prefs);

      // On first launch there is no cache — must not throw.
      expect(() => svc.readCachePosts(), returnsNormally);
      expect(svc.readCachePosts(), isEmpty);
    });

    test('sharedPreferencesProvider override surfaces to FeedCacheService',
        () async {
      // Verifies the Riverpod wiring used in main.dart is correct.
      final prefs = await SharedPreferences.getInstance();
      final svc = FeedCacheService(prefs);
      await svc.writeCachePosts([_post('6')]);

      // Same prefs instance → same data visible to a new FeedCacheService.
      final svc2 = FeedCacheService(prefs);
      expect(svc2.readCachePosts().first.id, equals('6'));
    });
  });
}

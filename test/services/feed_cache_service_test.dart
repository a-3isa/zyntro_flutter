import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/feed_cache_service.dart';

Post _makePost(String id, {DateTime? createdAt}) => Post(
      id: id,
      authorId: 'author_$id',
      sessionId: 'session_$id',
      visibility: 'public',
      title: 'Post $id',
      type: 'strength',
      summary: SessionSummary(),
      likesCount: 0,
      commentsCount: 0,
      createdAt: createdAt ?? DateTime(2025, 1, int.parse(id.replaceAll(RegExp(r'\D'), '1'))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedCacheService', () {
    late FeedCacheService svc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      svc = FeedCacheService(prefs);
    });

    test('readCachePosts returns [] when no cache', () {
      expect(svc.readCachePosts(), isEmpty);
    });

    test('isEmpty returns true when no cache', () {
      expect(svc.isEmpty, isTrue);
    });

    test('writeCachePosts then readCachePosts round-trips basic fields',
        () async {
      final posts = [_makePost('1'), _makePost('2')];
      await svc.writeCachePosts(posts);
      final read = svc.readCachePosts();
      expect(read, hasLength(2));
      expect(read.map((p) => p.id), containsAll(['1', '2']));
    });

    test('writeCachePosts enforces 20-post cap (write 25, read back 20)',
        () async {
      final posts = List.generate(
        25,
        (i) => _makePost('${i + 1}',
            createdAt: DateTime(2025, 1, 1).add(Duration(hours: i))),
      );
      await svc.writeCachePosts(posts);
      final read = svc.readCachePosts();
      expect(read, hasLength(20));
    });

    test('writeCachePosts keeps the 20 newest posts when capping', () async {
      final now = DateTime(2025, 6, 1);
      final posts = List.generate(
        25,
        (i) => _makePost('${i + 1}', createdAt: now.add(Duration(hours: i))),
      );
      await svc.writeCachePosts(posts);
      final read = svc.readCachePosts();
      // Newest 20 = posts 6..25 (index 5..24)
      final ids = read.map((p) => int.parse(p.id)).toList();
      expect(ids.every((id) => id >= 6), isTrue,
          reason: 'All 20 retained posts should be the newest');
    });

    test('clearCache makes isEmpty return true', () async {
      await svc.writeCachePosts([_makePost('1')]);
      expect(svc.isEmpty, isFalse);
      await svc.clearCache();
      expect(svc.isEmpty, isTrue);
    });

    test('readCachePosts returns [] after clearCache', () async {
      await svc.writeCachePosts([_makePost('1')]);
      await svc.clearCache();
      expect(svc.readCachePosts(), isEmpty);
    });

    test('corrupt JSON in SharedPreferences does not throw (returns [])',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('zyntro_feed_cache', 'NOT_VALID_JSON!!!');
      expect(() => svc.readCachePosts(), returnsNormally);
      expect(svc.readCachePosts(), isEmpty);
    });

    test('isStale returns false when cache is fresh', () async {
      await svc.writeCachePosts([_makePost('1')]);
      expect(svc.isStale, isFalse);
    });

    test('isStale returns true when cachedAt is more than 7 days ago',
        () async {
      final oldDate =
          DateTime.now().subtract(const Duration(days: 8)).toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'zyntro_feed_cache',
        '{"cachedAt":"$oldDate","posts":[]}',
      );
      expect(svc.isStale, isTrue);
    });

    test('isStale returns false when no cache exists', () {
      expect(svc.isStale, isFalse);
    });
  });
}

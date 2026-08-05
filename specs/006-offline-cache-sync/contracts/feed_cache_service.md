# Contract: FeedCacheService

**Feature**: [spec.md](../spec.md) | [data-model.md](../data-model.md)

## Interface

```dart
abstract class FeedCacheService {
  /// Returns cached posts synchronously. Returns [] if no cache or cache is cleared.
  /// Callers must NOT await this — the intent is synchronous access.
  List<Post> readCachePosts();

  /// Persists posts to disk. Enforces 20-post cap (newest first by createdAt).
  Future<void> writeCachePosts(List<Post> posts);

  /// Clears all feed cache. Must be called on logout.
  Future<void> clearCache();

  /// True if cached data was written more than 7 days ago.
  bool get isStale;

  /// True if no cache data exists (first-ever launch scenario).
  bool get isEmpty;
}
```

## Constraints

- `readCachePosts()` MUST return within 1ms (uses pre-loaded SharedPreferences instance)
- `writeCachePosts()` MUST enforce the 20-post cap at write time, not read time
- Posts are sorted by `createdAt` descending; oldest posts beyond the cap are evicted
- JSON serialization MUST include a `cachedAt` timestamp for staleness detection
- `clearCache()` MUST remove the SharedPreferences key entirely (not write an empty list)

## SharedPreferences Key

`zyntro_feed_cache` — JSON-encoded `List<Map<String, dynamic>>`

## Error Handling

- If JSON parsing fails (corrupt cache), `readCachePosts()` MUST return `[]` and log the error; MUST NOT throw
- If `writeCachePosts()` fails (storage full), log the error; MUST NOT throw; caller continues normally

# Data Model: Offline-First Caching & Background Sync

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## New Services & Data Structures

### `FeedCacheService`

File: `lib/services/feed_cache_service.dart`

```dart
class FeedCacheService {
  static const String _key = 'zyntro_feed_cache';
  static const int _maxPosts = 20;
  static const Duration _staleTTL = Duration(days: 7);

  // Synchronous read (SharedPreferences is pre-cached after init)
  List<Post> readCachePosts();

  // Async write — enforces 20-post cap, sorts by createdAt descending
  Future<void> writeCachePosts(List<Post> posts);

  // Called on logout
  Future<void> clearCache();

  // True if cached data is older than 7 days
  bool get isStale;
  
  // True if no cache exists (first-ever launch)
  bool get isEmpty;
}
```

**JSON structure** (per cached post):
```json
{
  "id": "string",
  "authorId": "string",
  "title": "string",
  "type": "gym|cardio|solo|partner",
  "visibility": "public|followers|private",
  "likeCount": 0,
  "commentCount": 0,
  "createdAt": "2026-06-20T10:00:00.000Z",
  "cachedAt": "2026-06-20T10:01:00.000Z",
  "sessionSummary": {}
}
```

**State transitions**:
```
EMPTY → POPULATED  (first successful Firestore page)
POPULATED → POPULATED  (on each subsequent fresh load, oldest entries evicted)
POPULATED → STALE  (after 7 days with no network refresh)
* → EMPTY  (on logout)
```

---

### `ProfileCacheService`

File: `lib/services/profile_cache_service.dart`

```dart
class ProfileCacheService {
  static const String _profilePrefix = 'zyntro_profile_cache_';
  static const String _historyPrefix = 'zyntro_workout_history_';

  // Profile snapshot
  UserProfile? readProfile(String userId);
  Future<void> writeProfile(String userId, UserProfile profile);

  // Workout history (all cached sessions)
  List<Map<String, dynamic>> readWorkoutHistory(String userId);
  Future<void> writeWorkoutHistory(String userId, List<Map<String, dynamic>> sessions);

  // Logout cleanup
  Future<void> clearCache(String userId);
}
```

---

### Terminology: "queued" vs "pending"

These two terms describe the same concept at different layers. Use them consistently:

| Term | Where used | Meaning |
|------|-----------|---------|
| **queued** | `QueuedOperation`, `OfflineManager.queueOperation()`, `zyntro_offline_queue` key | An operation stored in the OfflineManager queue awaiting sync |
| **pending** | UI field `isPending: bool` on local comment objects | A comment not yet confirmed by the server; shown in the comment list with a visual indicator |

Do **not** use "queued" in UI labels; do **not** use "pending" for the OfflineManager queue key or model names.

---

### Extended `QueuedOperation` — New Operation Types

Existing `QueuedOperation` in `OfflineManager` is unchanged. New operation type strings:

| Type | Payload Fields | Handler |
|------|---------------|---------|
| `like_post` | `postId: String, userId: String` | `offline_handlers.dart` |
| `unlike_post` | `postId: String, userId: String` | `offline_handlers.dart` |
| `add_comment` | `postId: String, userId: String, text: String, localId: String` | `offline_handlers.dart` |

The `localId` field in `add_comment` is a client-generated UUID used to track the pending comment in the UI. On successful sync, the server-assigned ID replaces it.

---

### `OfflineManager` Changes

File: `lib/utils/offline_manager.dart`

```dart
// Change:
static const int _maxRetries = 5;  // OLD
static const int _maxRetries = 3;  // NEW (per FR-014)

// Add:
final StreamController<FailedSyncEvent> _failureNotificationController =
    StreamController<FailedSyncEvent>.broadcast();

Stream<FailedSyncEvent> get onSyncFailure => _failureNotificationController.stream;
```

Emit `FailedSyncEvent` when an item is moved to `_failedOpsKey`:
```dart
class FailedSyncEvent {
  final String operationType;
  final String operationId;
  final int retryCount;
  final DateTime timestamp;
}
```

**Lifecycle observer** (new in `init()`):
```dart
WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));

// In _AppLifecycleObserver:
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && _manager.isOnline) {
    _manager.processQueue();
  }
}
```

---

### `PersonalExercisesCache` (extend `ExerciseCatalogService`)

File: `lib/services/exercise_catalog_service.dart` (minimal extension)

```dart
// Add to ExerciseCatalogService:
static const String _personalCachePrefix = 'zyntro_personal_exercises_';

Future<void> _cachePersonalExercises(String userId, List<PersonalExerciseEntry> exercises);
List<PersonalExerciseEntry> _readPersonalExercisesCache(String userId);
Future<void> clearPersonalExercisesCache(String userId);
```

Called automatically:
- Write: after successful Firestore load of personal exercises
- Read: as fallback when Firestore call fails (offline)
- Clear: on logout

---

## State Transitions Summary

```
Startup (returning user):
  FeedCache.POPULATED → FeedPage renders cached posts
  FeedCache.EMPTY → FeedPage renders SkeletonFeed
  [Firestore arrives] → FeedCache.POPULATED, FeedPage updates in-place

Offline action (like):
  PostProvider.likeCount++ [optimistic]
  QueuedOperation("like_post") added
  [Connectivity restored] → handler executes → server confirms
  [3 retries failed] → PostProvider.likeCount-- [revert] + FailedSyncEvent emitted

Session offline:
  QueuedOperation("session_event")* [per event]
  QueuedOperation("session_end") [on session end]
  QueuedOperation("post_create") [on session end]
  RecapPage shows "saved locally" message
  [Connectivity restored] → OfflineManager.processQueue() → all synced

Logout:
  FeedCacheService.clearCache()
  ProfileCacheService.clearCache(userId)
  ExerciseCatalogService.clearPersonalExercisesCache(userId)
  OfflineManager.clearQueue()
```

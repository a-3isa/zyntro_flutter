# Quickstart: Implementing Offline-First Caching & Background Sync

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## What's Already There

Before writing any code, verify these exist and are wired up:

```bash
# Confirm OfflineManager is initialized in main.dart
grep -r "registerOfflineHandlers\|offlineManagerProvider" lib/main.dart

# Confirm connectivity_plus is in pubspec
grep "connectivity_plus" pubspec.yaml

# Confirm shared_preferences is in pubspec  
grep "shared_preferences" pubspec.yaml
```

**Existing keys in SharedPreferences**: `zyntro_offline_queue`, `zyntro_failed_operations`  
**Existing operation types**: `session_event`, `session_end`, `post_create`, `voice_note_upload`

---

## P1: Instant Feed Cache (< 1 day)

### 1. Create `FeedCacheService`

```dart
// lib/services/feed_cache_service.dart
// Keys used: "zyntro_feed_cache"
// Cap: 20 posts, sorted by createdAt descending
// Staleness TTL: 7 days
```

### 2. Wire startup load in `FeedPage`

In `FeedPage.build()` (or its state provider), before initiating the Firestore stream:
1. Call `FeedCacheService.readCachePosts()`
2. If not empty → render posts immediately
3. If empty → render `SkeletonFeedWidget`
4. Initiate Firestore stream; when data arrives, call `FeedCacheService.writeCachePosts()` and update UI in-place

### 3. Create `SkeletonFeedWidget`

Use `shimmer` package or `AnimatedContainer` for shimmer effect. Render 3–5 skeleton post cards matching the real `PostCardWidget` dimensions.

### 4. Acceptance test

```dart
// test/features/feed/startup_cache_contract_test.dart
// Arrange: populate FeedCacheService with 5 mock posts
// Act: build FeedPage with no network (mock Firestore to not emit)
// Assert: posts visible in widget tree within widget test frame
```

---

## P2: Offline Training + Lifecycle Sync (1–2 days)

### 1. Reduce `_maxRetries` to 3

```dart
// lib/utils/offline_manager.dart
static const int _maxRetries = 3;  // was 5
```

### 2. Add failure notification stream

```dart
// lib/utils/offline_manager.dart
final StreamController<FailedSyncEvent> _failureNotificationController = ...
Stream<FailedSyncEvent> get onSyncFailure => ...

// In processQueue(), when retryCount >= _maxRetries:
_failureNotificationController.add(FailedSyncEvent(...));
```

### 3. Add `FailedSyncEvent` provider

```dart
// lib/utils/offline_manager.dart
final syncFailureProvider = StreamProvider<FailedSyncEvent>((ref) {
  return ref.watch(offlineManagerProvider).onSyncFailure;
});
```

### 4. Add lifecycle observer in `OfflineManager.init()`

```dart
// Register once in init():
WidgetsBinding.instance.addObserver(_LifecycleObserver(this));
```

### 5. Update `RecapPage`

When `ref.watch(connectivityProvider).valueOrNull == false`:
- Show "Saved locally — your workout will post when you're back online" banner

### 6. Wire failure notification in `MainShell`

```dart
// lib/features/main/presentation/main_shell.dart
ref.listen(syncFailureProvider, (_, event) {
  event.whenData((failure) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to sync ${failure.operationType}. Tap to retry.'))
    );
  });
});
```

---

## P3: Social Action Handlers (1 day)

### 1. Add handlers to `offline_handlers.dart`

```dart
// like_post handler
offlineManager.registerHandler('like_post', (op) async {
  await container.read(postServiceProvider).likePost(
    op.payload['postId'], op.payload['userId']
  );
});

// unlike_post handler
offlineManager.registerHandler('unlike_post', (op) async { ... });

// add_comment handler
offlineManager.registerHandler('add_comment', (op) async { ... });
```

### 2. Update `PostService.likePost()` call sites

When offline:
1. Apply optimistic state update to local Riverpod provider
2. Queue `like_post` operation
3. On sync failure → revert optimistic state

### 3. Pending comment indicator

Add `isPending: bool` to the comment model used in the feed thread view. Comments added offline have `isPending: true` until sync confirms.

---

## P4: Profile & History Cache (1 day)

### 1. Create `ProfileCacheService`

```dart
// lib/services/profile_cache_service.dart
// Keys: "zyntro_profile_cache_{userId}", "zyntro_workout_history_{userId}"
```

### 2. Wire in `ProfilePage`

When `connectivityProvider` is offline and cache exists:
- Load from `ProfileCacheService.readProfile(userId)` instead of Firestore
- Show "Viewing cached data" subtitle near profile header

### 3. Clear on logout

In the logout flow (auth repository / settings page):
```dart
await feedCacheService.clearCache();
await profileCacheService.clearCache(currentUserId);
await exerciseCatalogService.clearPersonalExercisesCache(currentUserId);
await offlineManager.clearQueue();
```

---

## Testing Checklist

| Test | File | Validates |
|------|------|-----------|
| FeedCacheService read/write | `test/services/feed_cache_service_test.dart` | 20-post cap, staleness TTL, clear |
| ProfileCacheService round-trip | `test/services/profile_cache_service_test.dart` | profile + history persist/clear |
| OfflineManager 3-retry cap | `test/utils/offline_manager_retry_test.dart` | hits failure at retry 3, emits FailedSyncEvent |
| Social handlers | `test/utils/offline_social_handlers_test.dart` | like_post/add_comment call correct services |
| Startup cache contract | `test/features/feed/startup_cache_contract_test.dart` | cached posts visible before Firestore emits |

---

## Acceptance Smoke Tests (Manual)

Run after each story completes:

**P1**: Enable airplane mode → restart app → cached feed visible immediately (no spinner)  
**P2**: Enable airplane mode → complete workout → restore connectivity → session appears in history within 30s  
**P3**: Enable airplane mode → like 3 posts + add comment → restore connectivity → confirm online within 60s  
**P4**: Load profile online → enable airplane mode → navigate to Profile → data visible

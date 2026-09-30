# Research: Offline-First Caching & Background Sync

**Generated**: 2026-06-20  
**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## Key Finding: Substantial Infrastructure Already Exists

The repository already contains a production-grade offline sync layer. This feature extends it — it does not build from scratch.

| Component | File | Status |
|-----------|------|--------|
| `OfflineManager` | `lib/utils/offline_manager.dart` | Exists — queue + retry + batch sync |
| `QueuedOperation` | Same | Exists — SharedPreferences-backed |
| `connectivityProvider` | Same | Exists — Riverpod StreamProvider |
| `ConnectionStatusWidget` | `lib/widgets/connection_status_widget.dart` | Exists — offline/syncing/online states |
| `SyncProgressOverlay` | `lib/widgets/sync_progress_overlay.dart` | Exists |
| Offline handlers | `lib/utils/offline_handlers.dart` | Exists — session_event, session_end, post_create, voice_note |
| `UserCacheService` | `lib/services/user_cache_service.dart` | Exists — in-memory LRU, NOT disk-persisted |
| Exercise catalog | `lib/core/data/gym_exercises.dart` | Exists as **static Dart file** — always offline |

---

## Decision Log

### D1 — Persistence: SharedPreferences (no new dependency)

- **Decision**: Use `shared_preferences ^2.3.3` (already in pubspec) for all new caches.
- **Rationale**: Already used by `OfflineManager` for queue storage (`zyntro_offline_queue`). The new caches (20 feed posts, one profile blob, personal exercises) are small enough for SharedPreferences.
- **Alternatives rejected**: Hive, Isar, sqflite — introduce new packages, initialization complexity, and migration surface without justification for this data volume.

### D2 — Exercise Catalog

- **Decision**: No new catalog caching needed. `lib/core/data/gym_exercises.dart` is a static Dart file bundled in the app binary.
- **Impact**: FR-016 (catalog cache) is satisfied by existing static data. Only user-created personal exercises (stored in Firestore) require a local cache (`zyntro_personal_exercises_{userId}`).

### D3 — Background Sync Trigger

- **Decision**: Add `WidgetsBindingObserver` to `OfflineManager` (registered in `init()`). Call `processQueue()` on `AppLifecycleState.resumed`.
- **Rationale**: The `connectivity_plus` stream already triggers sync on connectivity restore. The lifecycle observer fills the gap where the app was backgrounded when connectivity returned and the stream event was missed.
- **Alternatives rejected**: WorkManager / background_fetch — platform-specific, adds complexity, appropriate for long-running background tasks not immediate on-resume sync.

### D4 — Feed Cache Load Strategy

- **Decision**: `SharedPreferences.getInstance()` caches the platform channel result after first call. All subsequent reads within a session are effectively synchronous. Load cached posts before initiating Firestore stream.
- **Startup flow**: `OfflineManager.init()` → `FeedCacheService.readCachePosts()` → render → Firestore stream in parallel.
- **Cache write**: After each successful Firestore page, overwrite the cache with the latest 20 posts (by `createdAt` descending).

### D5 — Retry Cap

- **Decision**: Change `OfflineManager._maxRetries` from `5` to `3`.
- **Location**: `lib/utils/offline_manager.dart` line with `static const int _maxRetries = 5`.
- **Impact**: Permanently failed items surface faster; spec FR-014 requires 3-retry cap with in-app notification.

### D6 — Failure Notification

- **Decision**: Add `StreamController<String> _failureNotificationController` to `OfflineManager`. When an operation reaches `_maxRetries`, emit the operation type + ID. The `MainShell` (or a top-level Consumer) listens and shows a `SnackBar`.
- **Rationale**: Current code stores failed items in `_failedOpsKey` but does not surface them to the user. FR-014 requires a dismissible in-app notification.

### D7 — Optimistic Social Actions

- **Decision**: `PostService.likePost()` and `addComment()` apply immediate local state changes via Riverpod provider invalidation / state mutation. If the user is offline, the server call is skipped and the operation is queued. On sync failure (after 3 retries), revert state.
- **Pending comment indicator**: Add `isPending: bool` field to the local `Comment` model used in UI state; synced comments have `isPending: false`.

---

## Existing Handler Registration (offline_handlers.dart)

Current handlers registered:
- `session_event` (batch + individual)
- `session_end`
- `post_create`
- `voice_note_upload`

**New handlers to add**:
- `like_post`
- `unlike_post`
- `add_comment`

All new handlers follow the existing error-categorization + rethrow pattern.

---

## SharedPreferences Key Registry

| Key | Purpose | Owner |
|-----|---------|-------|
| `zyntro_offline_queue` | Pending sync operations | OfflineManager (existing) |
| `zyntro_failed_operations` | Permanently failed operations | OfflineManager (existing) |
| `zyntro_feed_cache` | Last 20 feed posts JSON | FeedCacheService (new) |
| `zyntro_profile_cache_{uid}` | User profile snapshot | ProfileCacheService (new) |
| `zyntro_workout_history_{uid}` | Workout history list | ProfileCacheService (new) |
| `zyntro_personal_exercises_{uid}` | User's personal exercises | ExerciseCatalogService (extend) |

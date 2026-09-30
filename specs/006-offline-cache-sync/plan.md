# Implementation Plan: Offline-First Caching & Background Sync

**Branch**: `006-offline-cache-sync` | **Date**: 2026-06-20 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/006-offline-cache-sync/spec.md`

---

## Summary

Enable instant startup from cached feed, full offline training, and offline social actions (likes/comments) with automatic background sync on connectivity restore. The app already has substantial offline infrastructure (`OfflineManager`, `ConnectionStatusWidget`, `QueuedOperation`, `connectivityProvider`); this feature extends it with disk-persisted feed/profile caches, social action handlers, a 3-retry cap, lifecycle-triggered sync, and skeleton/shimmer UI for first launch.

---

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x  
**Primary Dependencies**: Flutter Riverpod (state), GoRouter (navigation), Firebase Firestore (backend), `connectivity_plus` (already used), `shared_preferences` (already used — queue + new cache keys)  
**Storage**: `shared_preferences` for JSON cache (feed posts, profile, exercise personal list); Firestore as source of truth  
**Testing**: `flutter_test`, `mockito`, existing contract test pattern  
**Target Platform**: Android + iOS (mobile)  
**Project Type**: Mobile  
**Performance Goals**: Cached feed visible < 1 second; cached profile < 500ms; skeleton < 300ms on first launch; sync within 30–60s of reconnection  
**Constraints**: No new storage dependencies; OS-level sandbox is security boundary; feed cache capped at 20 posts; 3 retries max per sync item; background sync fires immediately on connectivity restore (foreground or background)  
**Scale/Scope**: Single-user, single-device; multi-device conflict out of scope

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope Discipline | ✅ Pass | Scoped to offline cache & sync; no feature creep |
| II. Evidence-First Cutover | ✅ Pass | Each story has independent acceptance test (airplane-mode smoke tests) |
| III. Security & Access Integrity | ✅ Pass | No auth changes; cache cleared on logout (FR-011); OS sandboxing confirmed |
| IV. Operational Safety & Reversibility | ✅ Pass | Cache is purely additive; removing it degrades gracefully to current behavior |
| V. Independent Deliverability | ✅ Pass | P1–P4 stories are independently implementable in priority order |

**Required quality gates**: Plans include pre-design and post-design constitution checks per constitution §Required Quality Gates.  
**Post-design re-check**: Scheduled at end of Phase 1.

---

## Project Structure

### Documentation (this feature)

```text
specs/006-offline-cache-sync/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── quickstart.md        ← Phase 1 output
├── contracts/           ← Phase 1 output
└── tasks.md             ← Phase 2 output (/speckit-tasks)
```

### Source Code (relevant paths)

```text
lib/
├── services/
│   ├── feed_cache_service.dart       ← NEW: disk-persisted feed post cache (20-post cap)
│   └── profile_cache_service.dart    ← NEW: disk-persisted profile + workout history cache
├── utils/
│   ├── offline_manager.dart          ← MODIFY: maxRetries 5→3, app lifecycle sync trigger
│   └── offline_handlers.dart         ← MODIFY: add like_post, unlike_post, add_comment handlers
├── features/
│   ├── feed/presentation/
│   │   └── feed_page.dart            ← MODIFY: load from cache first; skeleton on empty cache
│   ├── profile/presentation/
│   │   └── profile_page.dart         ← MODIFY: offline read from profile cache
│   └── session/presentation/
│       └── recap_page.dart           ← MODIFY: show "saved locally, will sync" when offline
├── widgets/
│   └── skeleton_feed.dart            ← NEW: shimmer placeholder for first-ever launch
└── main.dart                         ← MODIFY: lifecycle observer for sync-on-resume

test/
├── services/
│   ├── feed_cache_service_test.dart         ← NEW
│   └── profile_cache_service_test.dart      ← NEW
├── utils/
│   ├── offline_manager_retry_test.dart      ← NEW: verifies 3-retry cap + failure notification
│   └── offline_social_handlers_test.dart    ← NEW: like/unlike/comment handlers
└── features/
    └── feed/
        └── startup_cache_contract_test.dart ← NEW: cold-start cache rendering contract
```

**Structure Decision**: Single mobile project; no new packages required. All persistence uses `shared_preferences` (already a dependency). The static exercise catalog is already bundled in `lib/core/data/gym_exercises.dart` — no catalog caching needed.

---

## Complexity Tracking

No constitution violations. This feature is purely additive.

---

## Phase 0: Research

### Phase 0 Output → [research.md](research.md)

#### Decision 1 — Persistence Layer

**Decision**: Use `shared_preferences` (already in pubspec at `^2.3.3`) for feed, profile, and queue caches.  
**Rationale**: Already used by `OfflineManager` for the sync queue. Adding more keys to the same store keeps the dependency surface zero-change. Feed posts as JSON lists (≤20 items) and profile data are well within SharedPreferences capacity.  
**Alternatives considered**: `Hive` / `Isar` / `sqflite` — all require new packages, migrations, and initialization. The data volumes here (20 posts, one profile blob, exercise list) don't justify a full database.

#### Decision 2 — Exercise Catalog Offline

**Decision**: No new catalog caching required. The catalog is already available offline as a static Dart file (`lib/core/data/gym_exercises.dart`). The `ExerciseCatalogService` merges this static source with user-created personal exercises from Firestore. Personal exercises need to be cached for offline use.  
**Rationale**: Static bundled data is the strongest form of offline availability — no TTL, no sync, always present. Only personal exercises (user-specific Firestore docs) require a local cache.  
**Alternatives considered**: Full catalog Firestore-to-disk sync — unnecessary given static data.

#### Decision 3 — Background Sync Trigger

**Decision**: Extend `OfflineManager` to also call `processQueue()` when the app returns to `AppLifecycleState.resumed`. Register a `WidgetsBindingObserver` in the `OfflineManager.init()` path or via `main.dart`.  
**Rationale**: `OfflineManager` already triggers sync on connectivity restore via the `connectivity_plus` stream. Adding a lifecycle trigger ensures sync fires even when the device reconnected while the app was backgrounded (connectivity stream events may be missed in background on some platforms).  
**Alternatives considered**: `WorkManager` / platform background jobs — overkill for foreground-first sync; adds platform-specific complexity.

#### Decision 4 — Optimistic Social Actions

**Decision**: Likes and comments apply state updates immediately to local Riverpod providers before the Firestore call. The sync queue is used as fallback when offline; on success, the optimistic state is confirmed; on permanent failure, the state is reverted.  
**Rationale**: Matches the spec requirement for optimistic UI (FR-007). This pattern is already partially established in the app (session events are queued optimistically).  
**Alternatives considered**: Pessimistic updates (wait for server) — blocks UI and defeats the offline-first goal.

#### Decision 5 — Retry Cap Adjustment

**Decision**: Change `OfflineManager._maxRetries` from `5` to `3`.  
**Rationale**: Spec FR-014 specifies 3 retries. Existing code uses 5. The change is a single constant.  
**Impact**: Permanently-failed items reach `_failedOpsKey` sooner; the failure notification path becomes more visible in testing.

#### Decision 6 — Feed Cache Loading Strategy

**Decision**: Feed posts are loaded from `FeedCacheService` synchronously at startup (via `SharedPreferences.getInstance()` cached instance), then the Firestore stream is established in parallel. When fresh data arrives, the cache is overwritten.  
**Rationale**: `SharedPreferences` on mobile resolves on the first `getInstance()` call using a platform-cached instance — effectively synchronous after init. Loading cache before starting Firestore satisfies the < 1 second requirement.  
**Implementation note**: `FeedCacheService` reads at startup and writes after each successful Firestore page load. The 20-post cap is enforced at write time (keep newest 20 by timestamp).

---

## Phase 1: Design & Contracts

### Data Model → [data-model.md](data-model.md)

#### `FeedCacheEntry`

```
SharedPreferences key: "zyntro_feed_cache"
Value: JSON list of up to 20 Post objects, newest first
Fields per entry:
  - id: String
  - authorId: String
  - title: String
  - type: String (cardio | gym | solo | partner)
  - visibility: String
  - likeCount: int
  - commentCount: int
  - createdAt: ISO-8601 String
  - sessionSummary: Map<String, dynamic>? (serialized SessionSummary)
  - cachedAt: ISO-8601 String  ← added by FeedCacheService

Lifecycle:
  EMPTY → POPULATED (first Firestore page load succeeds)
  POPULATED → POPULATED (on each subsequent successful page load, replace)
  POPULATED → EMPTY (on logout)
  POPULATED → STALE (> 7 days since cachedAt — show staleness banner)
```

#### `ProfileCacheEntry`

```
SharedPreferences key: "zyntro_profile_cache_{userId}"
Value: JSON object
Fields:
  - userId: String
  - displayName: String
  - username: String?
  - avatarData: Map<String, dynamic>?
  - streakDays: int
  - totalWorkouts: int
  - followersCount: int
  - followingCount: int
  - cachedAt: ISO-8601 String

WorkoutHistory key: "zyntro_workout_history_{userId}"
Value: JSON list of OfflineWorkoutSession (all local sessions + synced ones)
```

#### `PersonalExercisesCache`

```
SharedPreferences key: "zyntro_personal_exercises_{userId}"
Value: JSON list of PersonalExerciseEntry
Refreshed: whenever ExerciseCatalogService loads personal exercises online
Cleared: on logout
```

#### `QueuedOperation` (existing — minor extension)

```
Existing: OfflineManager._maxRetries = 5  →  CHANGE TO 3
New operation types registered in offline_handlers.dart:
  - "like_post"    payload: { postId: String, userId: String }
  - "unlike_post"  payload: { postId: String, userId: String }
  - "add_comment"  payload: { postId: String, userId: String, text: String, localId: String }
```

#### `SyncStatus` (existing `SyncProgress` + new failure notification)

```
When operation.retryCount reaches _maxRetries (3) and permanently fails:
  - Moved to _failedOpsKey (existing behavior)
  - NEW: emit failure event via a new StreamController<FailedSyncEvent>
    so UI can display a dismissible in-app notification
```

### Interface Contracts → `/contracts/`

This is a mobile app with no public API surface. The relevant internal contracts are:

**`FeedCacheService` contract** (`contracts/feed_cache_service.md`):
```
readCachePosts() → List<Post>   (synchronous; returns [] if no cache)
writeCachePosts(List<Post>)     (async; enforces 20-post cap, newest first)
clearCache()                    (async; called on logout)
bool get isStale                (true if cachedAt > 7 days ago)
```

**`ProfileCacheService` contract** (`contracts/profile_cache_service.md`):
```
readProfile(userId) → UserProfile?    (synchronous)
writeProfile(userId, UserProfile)     (async)
readWorkoutHistory(userId) → List<OfflineWorkoutSession>
writeWorkoutHistory(userId, List<OfflineWorkoutSession>)
clearCache(userId)                    (called on logout)
```

**Offline handler contract** — new handler types must:
- Accept `QueuedOperation` with validated `payload` fields
- Throw on retryable failure (network/server error)
- Return normally on validation failures after retryCount >= 3
- Never mutate Riverpod state (state mutations happen at call site, not in handler)

### Quickstart → [quickstart.md](quickstart.md)

**Startup sequence (returning user):**

```
App launch
  → OfflineManager.init() (connectivity_plus check + lifecycle observer registration)
  → FeedCacheService.readCachePosts() [synchronous]
  → FeedPage renders with cached posts immediately
  → In parallel: Firestore feed stream established
  → When Firestore data arrives: FeedPage updates in-place (no full reload)
  → FeedCacheService.writeCachePosts(freshPosts) [background]
```

**Startup sequence (first-ever launch):**

```
App launch
  → FeedCacheService.readCachePosts() returns []
  → FeedPage renders SkeletonFeedWidget
  → Firestore feed stream establishes and returns data
  → FeedPage replaces skeleton with real posts
  → FeedCacheService.writeCachePosts(posts)
```

**Offline workout flow:**

```
User enters Train tab (offline)
  → ConnectionStatusWidget shows orange "Offline" banner
  → Session starts normally (OfflineManager.isOnline == false)
  → Each session event → OfflineManager.queueOperation("session_event", ...)
  → Session ends → OfflineManager.queueOperation("session_end", ...)
                 → OfflineManager.queueOperation("post_create", ...)
  → RecapPage shows "Saved locally — will post when you're online"
  → Connectivity restores → OfflineManager.processQueue() runs automatically
  → Session, post appear in history within 30 seconds
```

**Offline like flow:**

```
User taps Like (offline)
  → PostService.likePost() → detects offline
  → Optimistic: likeCount++ in local Riverpod state
  → OfflineManager.queueOperation("like_post", { postId, userId })
  → Connectivity restores → handler calls PostService.likePost() on server
  → On success: optimistic state confirmed (no UI change needed)
  → On permanent failure (3 retries): likeCount-- (revert); in-app notification shown
```

---

## Phase 1 Constitution Check (Post-Design)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope | ✅ Pass | Design touches only cache/sync layer; no auth, routing, or session logic changes |
| II. Evidence-First Cutover | ✅ Pass | Contract tests + airplane-mode smoke tests map directly to success criteria |
| III. Security & Access Integrity | ✅ Pass | Cache cleared on logout; no PII exposure beyond existing app data |
| IV. Operational Safety | ✅ Pass | Cache is read-only at startup; no blocking operations on main thread |
| V. Independent Deliverability | ✅ Pass | FeedCacheService (P1) deployable before social handlers (P3) |

---

## Implementation Sequence

Stories must be implemented in this order (dependencies):

```
P1: FeedCacheService + startup cache load + skeleton
    → Independently deployable; no other story depends on it

P2: Retry cap (3) + session offline flow + RecapPage message + lifecycle sync
    → Depends on existing OfflineManager; builds on current session_end/post_create handlers

P3: Social action handlers (like/unlike/comment) + optimistic UI
    → Depends on P2 (retry cap must match spec before social handlers go live)

P4: ProfileCacheService + profile/history offline read
    → Independent; can be developed in parallel with P2/P3
```

---

## Rollback Strategy

All cache writes are additive (new SharedPreferences keys). Removing them leaves the app in its current pre-feature state. The only behavior-changing change is `_maxRetries: 5 → 3`; reverting this is a single constant change.

---

## Out of Scope (backlog)

- Multi-device conflict resolution
- Background sync via platform WorkManager / background fetch
- Push notifications for synced items
- Feed cache beyond 20 posts
- Encryption of local cache

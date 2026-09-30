# Tasks: Offline-First Caching & Background Sync

**Input**: Design documents from `specs/006-offline-cache-sync/`  
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Tests**: Contract tests included per story (aligned with spec acceptance criteria).

**Organization**: Tasks are grouped by user story (P1–P4) to enable independent implementation and testing.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies on sibling tasks)
- **[Story]**: Which user story this task belongs to (US1–US4 maps to spec P1–P4)

---

## Phase 1: Setup (Service Scaffolds)

**Purpose**: Create the new files so parallel story work can proceed without merge conflicts.

- [x] T001 [P] Create empty `lib/services/feed_cache_service.dart` with `FeedCacheService` class stub (no logic yet; just the class + `feedCacheServiceProvider` stub)
- [x] T002 [P] Create empty `lib/services/profile_cache_service.dart` with `ProfileCacheService` class stub
- [x] T003 [P] Create empty `lib/widgets/skeleton_feed.dart` with `SkeletonFeedWidget` stub returning a `SizedBox`
- [x] T004 [P] Create empty `test/services/feed_cache_service_test.dart` with `main()` and `group('FeedCacheService', ...)` scaffold
- [x] T005 [P] Create empty `test/services/profile_cache_service_test.dart` with `main()` and `group('ProfileCacheService', ...)` scaffold
- [x] T006 [P] Create empty `test/utils/offline_manager_retry_test.dart` with `main()` scaffold (stub only — `flutter test` skips files with no test cases; populated fully in T017 during Phase 2)
- [x] T007 [P] Create empty `test/utils/offline_social_handlers_test.dart` with `main()` scaffold
- [x] T008 [P] Create empty `test/features/feed/startup_cache_contract_test.dart` with `main()` scaffold

**Checkpoint**: All new files exist; no logic yet; project still compiles.

---

## Phase 2: Foundational (OfflineManager Extensions)

**Purpose**: Core changes to `OfflineManager` that all user stories depend on.  
**⚠️ CRITICAL**: No user story work begins until this phase is complete.

- [x] T009 Change `static const int _maxRetries = 5` to `static const int _maxRetries = 3` in `lib/utils/offline_manager.dart` (FR-014); immediately after this edit, run `flutter test --reporter compact 2>&1 | Select-Object -First 80` to catch any existing `session_event`, `session_end`, and `post_create` handler tests that break due to the reduced retry count (regression gate — constitution §II)
- [x] T010 Add `FailedSyncEvent` class to `lib/utils/offline_manager.dart` with fields: `operationType: String`, `operationId: String`, `retryCount: int`, `timestamp: DateTime`
- [x] T011 Add `StreamController<FailedSyncEvent> _failureNotificationController` (broadcast) and `Stream<FailedSyncEvent> get onSyncFailure` getter to `OfflineManager` in `lib/utils/offline_manager.dart` (depends on T010)
- [x] T012 In `processQueue()` in `lib/utils/offline_manager.dart`, emit `FailedSyncEvent` to `_failureNotificationController` immediately before adding an item to `permanentlyFailed` (depends on T011)
- [x] T013 Add `syncFailureProvider` as `StreamProvider<FailedSyncEvent>` to `lib/utils/offline_manager.dart`, returning `offlineManagerProvider`'s `onSyncFailure` stream (depends on T011)
- [x] T014 Add `_AppLifecycleObserver` private class implementing `WidgetsBindingObserver` in `lib/utils/offline_manager.dart`; it calls `_manager.processQueue()` when `AppLifecycleState.resumed` and `_manager.isOnline` (spec Q5: sync immediately on reconnect, foreground or background)
- [x] T015 Register `_AppLifecycleObserver` via `WidgetsBinding.instance.addObserver(...)` inside `OfflineManager.init()` in `lib/utils/offline_manager.dart` (depends on T014)
- [x] T016 In `lib/utils/offline_manager.dart`, add `Stream<int> get queueCountStream` that re-emits the current pending queue length whenever `queueOperation()` or `processQueue()` mutates the queue (use a `BehaviorSubject`-style `StreamController` or re-read SharedPreferences and emit after each write). Then wire `syncFailureProvider` listener in `_MainShellState.build()` in `lib/features/main/presentation/main_shell.dart` using `ref.listen`; show a `SnackBar` with "Failed to sync [operationType] — [operationId]" on failure event (depends on T013). `queueCountStream` is consumed by `pendingQueueCountProvider` in Phase 7 (T041).
- [x] T017 Fill retry cap contract test in `test/utils/offline_manager_retry_test.dart`: mock a failing handler, queue one operation, call `processQueue()` 3 times, assert operation is in `_failedOpsKey` and `FailedSyncEvent` was emitted exactly once (depends on T006, T012, T013)

**Checkpoint**: `OfflineManager` uses 3-retry cap, emits failure events, syncs on app resume. `MainShell` shows failure snackbar. All existing tests still pass.

---

## Phase 3: User Story 1 — Instant Feed Cache (Priority: P1) 🎯 MVP

**Goal**: Returning users see the cached feed immediately on launch (< 1 second, no network required). First-time users see a skeleton shimmer while loading.

**Independent Test**: Enable airplane mode → restart app → cached feed visible before any Firestore response (widget test: cached posts present in widget tree before stream emits).

### Implementation

- [x] T018 [US1] Implement `FeedCacheService` in `lib/services/feed_cache_service.dart`:
  - `readCachePosts() → List<Post>` — deserializes from `zyntro_feed_cache` SharedPreferences key; returns `[]` on parse error (no throw)
  - `writeCachePosts(List<Post>)` — serializes latest 20 posts sorted by `createdAt` descending, adds `cachedAt` timestamp; overwrites key
  - `clearCache()` — removes `zyntro_feed_cache` key
  - `bool get isStale` — true if `cachedAt` > 7 days ago
  - `bool get isEmpty` — true if key does not exist
  - Add `feedCacheServiceProvider` returning `FeedCacheService(ref.watch(sharedPreferencesProvider))`
- [x] T019 [US1] Implement `SkeletonFeedWidget` in `lib/widgets/skeleton_feed.dart`: render 4 shimmer-style placeholder cards matching the height of `PostCardWidget`; use `AnimatedOpacity` cycling between 0.3–0.7 opacity if no `shimmer` package is available
- [x] T020 [US1] Modify `FeedPage` in `lib/features/feed/presentation/feed_page.dart`: on widget init, call `ref.read(feedCacheServiceProvider).readCachePosts()`; if non-empty, set initial state to cached posts; if empty, set initial state to skeleton; then initiate Firestore stream in parallel
- [x] T021 [US1] In `FeedPage` in `lib/features/feed/presentation/feed_page.dart`, after each successful Firestore page response, call `ref.read(feedCacheServiceProvider).writeCachePosts(freshPosts)` in the background (do not await in build path)
- [x] T022 [US1] Fill `test/services/feed_cache_service_test.dart` with contract tests:
  - `readCachePosts()` returns `[]` when no cache
  - `writeCachePosts()` enforces 20-post cap (write 25, read back, assert 20 newest)
  - `clearCache()` makes `isEmpty` return true
  - Corrupt JSON in SharedPreferences → `readCachePosts()` returns `[]` (no throw)
  - `isStale` returns true when `cachedAt` > 7 days
- [x] T023 [US1] Fill `test/features/feed/startup_cache_contract_test.dart`: seed `FeedCacheService` with 3 mock posts before building `FeedPage`; mock Firestore provider to never emit; assert `PostCardWidget` appears in widget tree within the first frame

**Checkpoint**: Launch app offline after prior session → cached posts visible immediately. First launch offline → skeleton shown.

---

## Phase 4: User Story 2 — Train Offline, Sync When Connected (Priority: P2)

**Goal**: Users can complete a full workout session with no internet. The session syncs automatically within 30 seconds of reconnection (foreground or background).

**Independent Test**: Airplane mode → complete gym session → restore connectivity → session appears in feed history within 30 seconds (manual smoke test per `quickstart.md`).

**Note**: Session queuing (`session_event`, `session_end`, `post_create`) and connectivity-triggered sync are already implemented in `OfflineManager` and `offline_handlers.dart`. Phase 2 foundational work covers the retry cap and lifecycle trigger. This phase adds only the RecapPage offline UX message.

### Implementation

- [x] T024 [US2] Modify `RecapPage` in `lib/features/session/presentation/recap_page.dart`: watch `connectivityProvider`; when offline, display a visible banner or subtitle reading "Saved locally — your workout will post when you're back online" below the session summary header
- [x] T025 [US2] Fill `test/utils/offline_manager_retry_test.dart` with the lifecycle sync assertion AND session handler regression: (a) register a mock `session_end` handler (using `MockSessionService`), pause connectivity, queue a `session_end` operation, simulate `AppLifecycleState.resumed` with connectivity restored, assert the mock `SessionService.endSession()` was called; (b) separately queue a `post_create` operation and assert it also processes on resume — verifying that existing operation types continue to work after the `_maxRetries` change (I1, C2; depends on T015, T017)

**Checkpoint**: Complete workout offline → RecapPage shows "saved locally" message → restore connectivity → session appears in history.

---

## Phase 5: User Story 3 — Offline Social Actions Queue (Priority: P3)

**Goal**: Likes and comments work offline with optimistic UI. All queued social actions sync automatically when connectivity is restored.

**Independent Test**: Airplane mode → like 3 posts + add 1 comment → UI reflects changes immediately → restore connectivity → all 4 actions confirmed online within 60 seconds.

### Implementation

- [x] T026 [US3] Add `like_post` handler in `lib/utils/offline_handlers.dart`: validate `postId` and `userId` in payload; call `container.read(postServiceProvider).likePost(postId, userId)`; rethrow on network/server errors; log and return on validation errors after retryCount >= 3
- [x] T027 [US3] Add `unlike_post` handler in `lib/utils/offline_handlers.dart` (same pattern as `like_post` but calls `unlikePost`; depends on T026 file slot)
- [x] T028 [US3] Add `add_comment` handler in `lib/utils/offline_handlers.dart`: validate `postId`, `userId`, `text`, `localId` in payload; call `container.read(postServiceProvider).addComment(...)`; depends on T027 file slot
- [x] T029 [US3] Modify `PostService.likePost()` in `lib/services/post_service.dart`: (1) check `ref.read(offlineManagerProvider).isOnline`; (2) if offline, increment `likeCount` in the existing post state provider (e.g., the `AsyncValue<Post>` held in `postProvider(postId)` or equivalent) and call `offlineManager.queueOperation('like_post', { 'postId': postId, 'userId': userId }, id: 'like_\${postId}_\${userId}')` — the `id` must be stable so the failure event can be matched; (3) in `_MainShellState` (or a top-level Consumer), listen to `syncFailureProvider`; when `FailedSyncEvent.operationId == 'like_\${postId}_\${userId}'`, decrement `likeCount` in the same post state provider to revert the optimistic update (depends on T026, T013)
- [x] T030 [US3] Apply same optimistic pattern to `PostService.unlikePost()` in `lib/services/post_service.dart` for `unlike_post` operation: if offline, decrement `likeCount` optimistically with stable operation id `'unlike_\${postId}_\${userId}'`; listen on `syncFailureProvider` and revert by incrementing `likeCount` when that id fails permanently (depends on T027)
- [x] T031 [US3] Modify comment submission in `lib/features/feed/presentation/post_detail_page.dart` (or the widget that submits comments): when offline, insert a local comment object with `isPending: true` and a client-generated UUID as id; call `offlineManager.queueOperation('add_comment', { ..., 'localId': uuid })`; depend on T028
- [x] T032 [US3] Add `isPending` display to the comment list item widget: if `isPending == true`, show a small clock/hourglass icon and grey the comment text slightly; remove indicator once sync confirms (depends on T031)
- [x] T033 [US3] Fill `test/utils/offline_social_handlers_test.dart` with contract tests: mock `PostService`; call the `like_post`, `unlike_post`, and `add_comment` handlers directly with valid payloads; assert correct service methods are called with correct arguments; assert validation errors are handled after 3 retries (depends on T026–T028)

**Checkpoint**: Like a post offline → like count increments immediately → restore connectivity → count confirmed. Comment offline → shows as pending → restored connectivity → pending indicator disappears.

---

## Phase 6: User Story 4 — Persistent Offline Profile & History (Priority: P4)

**Goal**: Users can view their own profile, stats, and workout history while offline using locally cached data.

**Independent Test**: Load profile online → enable airplane mode → navigate away and back to Profile → avatar, stats, streak, history all visible.

### Implementation

- [x] T034 [US4] Implement `ProfileCacheService` in `lib/services/profile_cache_service.dart`:
  - `readProfile(String userId) → UserProfile?` — from `zyntro_profile_cache_{userId}`; returns `null` on miss/parse error
  - `writeProfile(String userId, UserProfile profile)` — serializes to SharedPreferences
  - `readWorkoutHistory(String userId) → List<Map<String, dynamic>>` — from `zyntro_workout_history_{userId}`; returns `[]` on miss
  - `writeWorkoutHistory(String userId, List<Map<String, dynamic>> sessions)` — serializes to SharedPreferences
  - `clearCache(String userId)` — removes both keys for the user
  - Add `profileCacheServiceProvider`
- [x] T035 [US4] Modify `ProfilePage` in `lib/features/profile/presentation/profile_page.dart`: on init, load from `ProfileCacheService.readProfile(currentUserId)` as initial state when offline; initiate Firestore load in parallel when online; when Firestore data arrives, call `ProfileCacheService.writeProfile()` and update UI
- [x] T036 [US4] Add "Viewing cached data" subtitle/chip near the top of `ProfilePage` when `connectivityProvider` is offline and data is from cache
- [x] T037 [US4] Modify workout history view (in `lib/features/profile/presentation/workout_history_page.dart` or equivalent) to load from `ProfileCacheService.readWorkoutHistory()` when offline; call `writeWorkoutHistory()` after each successful Firestore load
- [x] T038 [P] [US4] Modify `search(userId, query)` in `lib/services/exercise_catalog_service.dart` (line ~276): after the `personalSnap` Firestore fetch succeeds (line ~304), add `await _cachePersonalExercises(userId, personalEntries)` to persist to `zyntro_personal_exercises_{userId}`; in the `catch` block (line ~323), before calling `_fallbackSearch()`, first try loading from `_readPersonalExercisesCache(userId)` and merge with the static catalog results; also add `clearPersonalExercisesCache(userId)` for logout. **Note**: the static `gym_exercises.dart` catalog already satisfies FR-016 for the bundled catalog — this task covers only user-created personal exercises stored in Firestore. **Runtime dependency**: requires Phase 2 (T015 `OfflineManager.init()`) complete before `isOnline` check works at runtime; can be coded independently.
- [x] T039 [US4] Fill `test/services/profile_cache_service_test.dart`: round-trip `readProfile`/`writeProfile` preserves all fields; `clearCache` removes both keys; `readProfile` returns `null` on miss; `readWorkoutHistory` returns `[]` on miss; add a stopwatch assertion: `final sw = Stopwatch()..start(); svc.readProfile(uid); expect(sw.elapsedMilliseconds, lessThan(10));` — documents the < 500ms SC-005 target (SharedPreferences reads are effectively synchronous after init)

**Checkpoint**: Profile page shows avatar, streak, workout count while airplane mode is on.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Logout cache clearing, pending sync count UI, stale data indicator.

- [x] T040 Update the logout flow in `lib/features/auth/data/repositories/auth_repository_impl.dart` (and/or `lib/features/settings/presentation/settings_page.dart`): after `FirebaseAuth.signOut()`, call `feedCacheService.clearCache()`, `profileCacheService.clearCache(userId)`, `exerciseCatalogService.clearPersonalExercisesCache(userId)`, and `offlineManager.clearQueue()` (FR-011)
- [x] T040a Wire `ConnectionStatusWidget` into `_MainShellState.build()` in `lib/features/main/presentation/main_shell.dart` (FR-006): wrap the existing `Scaffold` body or stack it above the `IndexedStack` using a `Column` so the offline banner is visible on every tab; consume `pendingQueueCountProvider` (the `StreamProvider<int>` created in T041) and pass its value to the widget's pending count parameter; this task provides the persistent offline indicator required by FR-006. **Note**: T041 must be completed first so `pendingQueueCountProvider` is defined before T040a consumes it — update Phase 7 ordering to T041 → T040a.
- [x] T041 After T040a, verify that `ConnectionStatusWidget` in `MainShell` correctly shows pending sync count (FR-013): when `queueCount > 0` and offline, the banner must read "Offline — N items waiting to sync"; wire `offlineManager.getQueueCount()` to a `StreamProvider<int>` named `pendingQueueCountProvider` and consume it in the widget
- [x] T042 Add stale cache indicator to `FeedPage` in `lib/features/feed/presentation/feed_page.dart`: if `feedCacheService.isStale`, show a small amber chip "Cached from [date]" near the top of the list when offline (FR-001 edge case: stale cache should be surfaced, not silently shown as fresh)
- [x] T043 Run all new contract tests: `flutter test test/services/feed_cache_service_test.dart test/services/profile_cache_service_test.dart test/utils/offline_manager_retry_test.dart test/utils/offline_social_handlers_test.dart test/features/feed/startup_cache_contract_test.dart --reporter compact`
- [x] T043a Run the full existing test suite to verify no regressions from `_maxRetries` change (T009), new `OfflineManager` streams (T011–T013), and lifecycle observer (T015): `flutter test --reporter compact 2>&1 | Select-Object -First 80` — all previously passing tests must still pass (constitution §II regression gate)
- [x] T044 Run manual acceptance smoke tests from `specs/006-offline-cache-sync/quickstart.md` (P1–P4 airplane-mode flows)

**Checkpoint**: All tests pass. All 4 smoke tests verified on device. Logout clears all cached data.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately; all T001–T008 are parallel
- **Phase 2 (Foundational)**: Depends on Phase 1 completion (new files must exist) — BLOCKS US2, US3 retry path
- **Phase 3 (US1)**: Depends on Phase 1 (T001 provides FeedCacheService stub) — independent of Phase 2
- **Phase 4 (US2)**: Depends on Phase 2 completion (T024 uses `connectivityProvider` which is fine; T025 needs T015)
- **Phase 5 (US3)**: Depends on Phase 2 completion (T029/T030 need retry cap in place via T009)
- **Phase 6 (US4)**: Depends on Phase 1 (T002 provides ProfileCacheService stub) — independent of Phase 2
- **Phase 7 (Polish)**: Depends on US1–US4 phases complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 1 — no dependency on US2/US3/US4
- **US2 (P2)**: Depends on Phase 2 foundational complete — no dependency on US1/US3/US4
- **US3 (P3)**: Depends on Phase 2 foundational complete — no dependency on US1/US2/US4
- **US4 (P4)**: Can start after Phase 1 — no dependency on US2/US3. **Exception**: T038 (`ExerciseCatalogService`) uses `OfflineManager.isOnline` at runtime, so its integration test requires Phase 2 (T015) complete; T038 itself can be coded in isolation.

### Within Each Phase

- Phase 1: All tasks parallel (T001–T008)
- Phase 2: T009 → T010 → T011 → T012+T013 (parallel) → T014 → T015 → T016+T017 (parallel)
- Phase 3: T018 → T019 (parallel, different file) → T020 → T021 → T022+T023 (parallel, different test files)
- Phase 4: T024 (independent) → T025 (depends on T015)
- Phase 5: T026 → T027 → T028 (sequential, same file) → T029+T030 (parallel, same file, different methods) → T031 → T032 → T033
- Phase 6: T034 → T035 → T036 (same file, sequential) + T037 (different file, parallel to T035) + T038 (different file, parallel) → T039
- Phase 7: T040 → T041 → T040a → T042 → T043 → T043a → T044  *(T041 defines `pendingQueueCountProvider` first; T040a consumes it)*

### Parallel Opportunities

```bash
# Phase 1 — all parallel:
T001 T002 T003 T004 T005 T006 T007 T008

# Phase 2 — after T011:
T012 T013  # different parts of same class

# Phase 3 — after T018:
T019       # different file (SkeletonFeedWidget)
T022 T023  # different test files (after T018 impl complete)

# Phase 6 — after T034:
T037       # WorkoutHistoryPage (different file from T035/T036)
T038       # ExerciseCatalogService (different file)
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup (all stubs)
2. Complete Phase 3: US1 (FeedCacheService + startup + skeleton)
3. **STOP and VALIDATE**: airplane mode restart → cached feed visible → T043 test subset
4. Deploy/demo this increment alone — P1 story delivers immediate user value

### Incremental Delivery

1. Phase 1 + Phase 3 (US1) → instant startup ← **demo-able**
2. Phase 2 + Phase 4 (US2) → offline training ← **demo-able**
3. Phase 5 (US3) → offline social ← **demo-able**
4. Phase 6 (US4) → offline profile ← **demo-able**
5. Phase 7 (Polish) → logout + pending count + stale indicator

### Parallel Team Strategy

With two developers:

1. Both complete Phase 1 together (15 minutes, all stubs)
2. **Dev A**: Phase 2 (Foundational OfflineManager) → Phase 4 (US2 RecapPage) → Phase 5 (US3 Social)
3. **Dev B**: Phase 3 (US1 FeedCacheService + startup) → Phase 6 (US4 ProfileCacheService)
4. Both merge → Phase 7 (Polish) together

---

## Notes

- `[P]` = parallel-safe (different files, no dependency on sibling tasks in same phase)
- `[Story]` label maps task to spec.md user story for traceability
- The static exercise catalog (`lib/core/data/gym_exercises.dart`) is always offline — no catalog caching task needed
- `UserCacheService` (existing) is in-memory only and does not need to change for this feature
- SharedPreferences keys introduced: `zyntro_feed_cache`, `zyntro_profile_cache_{uid}`, `zyntro_workout_history_{uid}`, `zyntro_personal_exercises_{uid}`
- Commit after each phase checkpoint before starting next phase


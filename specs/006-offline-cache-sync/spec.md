# Feature Specification: Offline-First Caching & Background Sync

**Feature Branch**: `006-offline-cache-sync`  
**Created**: 2026-06-20  
**Status**: Draft  
**Input**: User description: "the app is loading too long when starting, it can start on the cache feed enhance the ux when the user opens the app, also i want the app to work offline on cache and also the user can train offline and his workouts waits for connection to be posted online, also his comments likes anything is saved into local and when the connection is restored it synced online"

---

## Clarifications

### Session 2026-06-20

- Q: Should locally cached data (feed posts, workout history, sync queue) be encrypted on the device? → A: No extra encryption; rely on OS-level app sandboxing (industry standard for fitness apps with no PII/financial data)
- Q: How many feed posts should be cached locally for offline browsing? → A: Last 20 posts
- Q: How many times should a failed sync item be retried before giving up? → A: 3 retries with exponential backoff, then mark failed and notify the user
- Q: When offline, can the user browse and add exercises from the full catalog during a gym session? → A: Yes — the full exercise catalog must be cached locally and available offline
- Q: When should the background sync queue run after connectivity is restored? → A: Immediately on connectivity restore, whether the app is in the foreground or background

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Instant Feed on Cold Start (Priority: P1)

When a user opens the app, the cached feed from their last session is immediately visible while fresh content loads in the background. No loading spinner blocks interaction — the user can scroll and tap from the first frame.

**Why this priority**: Startup latency is the most damaging UX friction point. Every second of blank screen reduces retention. Showing cached content immediately makes the app feel instant regardless of network speed.

**Independent Test**: Launch the app with airplane mode on after a prior session. The feed from the last session must be fully rendered within 1 second with no loading state shown.

**Acceptance Scenarios**:

1. **Given** the user has launched the app at least once before, **When** they open the app on any network condition, **Then** the cached feed renders immediately (within 1 second) before any network call completes
2. **Given** cached content is visible, **When** fresh data arrives from the network, **Then** the feed updates in-place without a full reload or visible flash
3. **Given** the user has never launched the app before (no cache), **When** they open the app, **Then** a skeleton/shimmer placeholder is shown while the initial load completes

---

### User Story 2 — Train Offline, Sync When Connected (Priority: P2)

A user with no internet connection can start and complete a workout session. All session data (sets, reps, duration, exercise selections) is stored locally. When connectivity is restored, the workout is automatically posted online without any user action.

**Why this priority**: Training happens in gyms with poor signal. If the session fails to start or save offline, the user loses their workout data — a critical failure that destroys trust.

**Independent Test**: Enable airplane mode, complete a full workout session, restore connectivity. The session must appear in the user's workout history online within 30 seconds of reconnection.

**Acceptance Scenarios**:

1. **Given** the user has no internet connection, **When** they navigate to the Train tab, **Then** all workout types and session controls are available with an "offline" indicator shown
2. **Given** the user completes a session while offline, **When** the session ends, **Then** a confirmation screen confirms local save and informs the user it will sync when online
3. **Given** a pending offline workout exists, **When** internet connectivity is restored, **Then** the workout is automatically synced within 30 seconds with no user action required
4. **Given** sync fails after reconnection (server error), **When** the user checks their history, **Then** the workout is still visible locally and a retry is scheduled automatically

---

### User Story 3 — Offline Social Actions Queue (Priority: P3)

When a user taps Like on a post, adds a comment, or takes any social action while offline, the action is saved locally and an optimistic UI update is shown immediately. All queued actions are silently synced when connectivity returns.

**Why this priority**: Social actions are frequent and lightweight. Blocking them on connectivity would make the feed feel broken even in low-signal conditions.

**Independent Test**: Enable airplane mode, like 3 posts and add a comment. Restore connectivity. Confirm all 3 likes and the comment appear online within 60 seconds.

**Acceptance Scenarios**:

1. **Given** the user has no internet connection, **When** they like a post, **Then** the like count updates immediately in the UI (optimistic) and the action is queued locally
2. **Given** the user is offline, **When** they submit a comment, **Then** the comment appears in the thread immediately with a "pending" indicator
3. **Given** queued social actions exist, **When** connectivity is restored, **Then** all actions are synced in the order they were performed, and pending indicators are removed
4. **Given** a sync conflict occurs (e.g., post was deleted), **When** the sync fails for a specific action, **Then** the UI reverts that action gracefully without affecting other queued items

---

### User Story 4 — Persistent Offline Mode for Profile & History (Priority: P4)

Users can browse their own profile, workout history, and stats while offline using locally cached data. Read-only access to previously loaded content works without any connection.

**Why this priority**: Users reviewing past workouts or their stats in a gym (poor signal) should not hit blank screens.

**Independent Test**: Load the profile and workout history while online, then enable airplane mode. Navigate to Profile and Workout History — all previously loaded data must be visible.

**Acceptance Scenarios**:

1. **Given** the user previously viewed their profile while online, **When** they view their profile offline, **Then** all cached data (avatar, stats, streak, recent sessions) is displayed
2. **Given** the user views their workout history offline, **Then** all cached sessions are listed with full details accessible
3. **Given** the user is offline and the data has never been loaded, **When** they visit a screen, **Then** an empty state with "Connect to load your data" message is shown

---

### Edge Cases

- When cached data is stale (> 7 days since last network refresh), show an amber "Cached from [date]" chip near the top of the feed; silently refresh on next connectivity restore. Implemented in T042.
- How is cache invalidated when the user logs out — all local data must be cleared to protect privacy?
- What happens if two devices are used (phone + tablet) and an offline workout is synced from one while the other is offline — last-write-wins or merge?
- What if the sync queue grows very large (100+ pending actions) due to extended offline use — batch sync in chunks to avoid timeout?
- What if device storage is full — fail gracefully with a user-visible warning rather than silently dropping data?

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST display the last cached feed content within 1 second of launch, before any network call completes
- **FR-002**: The app MUST show skeleton/shimmer placeholders on first-ever launch while initial content loads
- **FR-003**: The app MUST allow users to start, log, and complete a workout session with no internet connection, including full access to the exercise catalog
- **FR-016**: The full exercise catalog MUST be accessible during offline gym sessions (covers user-created personal exercises, which are cached to `zyntro_personal_exercises_{userId}`; the static bundled catalog in `lib/core/data/gym_exercises.dart` is always offline by definition and does not require a separate cache)
- **FR-004**: The app MUST persist offline workout sessions to local storage immediately when each set or exercise is logged
- **FR-005**: The app MUST automatically sync pending offline workouts to the server within 30 seconds of connectivity being restored, whether the app is in the foreground or background at the time connectivity returns
- **FR-006**: The app MUST display a persistent "offline" indicator when no connection is available
- **FR-007**: The app MUST queue like and comment actions performed offline and apply them optimistically to the local UI
- **FR-008**: The app MUST sync all queued social actions immediately when connectivity is restored (foreground or background), preserving the original insertion order
- **FR-009**: The app MUST revert individual failed sync actions gracefully without disrupting the rest of the sync queue
- **FR-010**: The app MUST cache user profile data, workout history, and stats for offline read access
- **FR-011**: The app MUST clear all locally cached and queued data when the user logs out
- **FR-015**: Local cache and sync queue MUST NOT apply additional encryption beyond OS-level app sandboxing; the OS sandbox is the security boundary for stored workout and feed data
- **FR-012**: The feed MUST update with fresh content in the background without a full-screen reload when new data arrives after startup
- **FR-013**: Pending offline actions MUST be visible to the user (e.g., "3 items waiting to sync") with a status indicator
- **FR-014**: The sync queue MUST retry failed items up to 3 times using exponential backoff; after 3 consecutive failures the item MUST be marked permanently failed and the user MUST be notified via a dismissible in-app notification

### Key Entities

- **OfflineWorkoutSession**: A completed or in-progress session recorded locally while offline, containing exercise logs, timestamps, session type, and sync status (pending / synced / failed)
- **SyncQueue**: An ordered list of pending write operations (likes, comments, workout posts) with metadata: action type, target entity ID, payload, created timestamp, retry count (max 3), and status (pending / retrying / failed / synced)
- **ContentCache**: Local snapshots of feed posts (capped at 20 most recent), user profiles, workout history — keyed by user ID and content type, with a last-fetched timestamp and version token; feed cache evicts oldest entries beyond the 20-post limit
- **SyncStatus**: System-level state tracking connectivity state, last successful sync time, and count of pending queue items

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cached feed is visible to returning users within 1 second of app launch on any network condition, including no connectivity
- **SC-002**: 100% of offline workout sessions recorded are successfully synced to the server within 60 seconds of connectivity restoration, with zero data loss
- **SC-003**: Offline-queued social actions (likes, comments) sync within 60 seconds of reconnection with optimistic UI shown immediately
- **SC-004**: Users can complete the full Train → Session → Recap flow with no internet connection and receive confirmation of local save
- **SC-005**: Profile, workout history, and stats screens load cached content in under 500ms when offline data exists
- **SC-006**: First-ever launch (empty cache) shows a skeleton placeholder within 300ms, not a blank screen
- **SC-007**: Sync conflicts and failures are handled without crashes, data loss, or user-visible errors beyond a dismissible notification

---

## Assumptions

- The app already has a connectivity detection mechanism (`connectivityProvider`) — this feature extends its usage, not replaces it
- Offline sessions are single-device only; multi-device conflict resolution is out of scope for this iteration
- The local cache strategy uses a time-to-live of 7 days for feed content and indefinite retention for user's own workout history until explicit logout
- Push notifications for synced content updates are out of scope; sync is silent and background
- The sync queue processes actions sequentially in insertion order to preserve causality (e.g., comment after like on the same post)
- Cache storage is managed within device storage limits; if storage is critically low, oldest feed cache (not workout data) is evicted first
- The feed cache is limited to the 20 most recent posts; older entries are evicted automatically when new posts are cached
- The full exercise catalog is cached locally; catalog size is assumed to be manageable on device storage (hundreds of entries, not tens of thousands)

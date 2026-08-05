# Research: Database Exercise Picker

## Decision 1: Use Firestore as the shared catalog source with local seed fallback during transition

**Decision**: Store the shared exercise catalog in a top-level Firestore collection and use the existing local `GymExercises` dataset only as seed/fallback data during rollout.

**Rationale**: The feature requires "all exercises to be in db" and consistent results across entry points. Firestore is already the app's session/workout storage and is available through existing dependencies. Keeping local seed data avoids inventing a second catalog source while supporting a reversible rollout.

**Alternatives considered**:
- Keep the static local catalog only: rejected because it does not satisfy database-backed search.
- Store catalog inside session documents: rejected because catalog data is global, not session-owned.
- Add a separate backend API: rejected because the app already uses Firestore for this product slice.

## Decision 2: Merge shared catalog and personal custom exercises in one picker result stream

**Decision**: The picker should search the shared catalog and the current user's personal custom exercises together, clearly marking custom results where needed.

**Rationale**: Users expect custom exercises to be reusable immediately. Searching both sources through one picker preserves the requested single "Add exercise" flow and avoids separate custom tabs.

**Alternatives considered**:
- Search shared catalog first, then personal exercises only on a separate tab: rejected as extra friction.
- Save custom exercises only to the current session: rejected by clarification; custom exercises must be reusable.
- Promote custom exercises immediately to the shared catalog: rejected because shared catalog quality needs review.

## Decision 3: Custom exercises are personal immediately and submitted for review

**Decision**: Creating a custom exercise creates a personal exercise entry for the user and an exercise review submission for possible shared catalog inclusion.

**Rationale**: This satisfies the user's desire to create missing exercises without blocking their workout, while protecting the shared database from typos and duplicates.

**Alternatives considered**:
- Personal only: rejected because it loses the opportunity to grow the shared database.
- Review only: rejected because it delays reuse for the creating user.
- Shared immediately: rejected due to quality and moderation risk.

## Decision 4: Search should normalize text and support lightweight fuzzy matching

**Decision**: Search should be case-insensitive, ignore simple spacing/punctuation differences, support partial name matches, and tolerate likely typos with a bounded fuzzy-match strategy.

**Rationale**: The user explicitly requested non-letter-sensitive search and tolerance when the exercise name is mistaken. Lightweight fuzzy matching is enough for exercise names without requiring heavy infrastructure.

**Alternatives considered**:
- Exact or prefix-only search: rejected because it fails the clarified typo-tolerance requirement.
- Full external search service: rejected as disproportionate for the current catalog size and mobile app scope.

## Decision 5: Late-session add inserts planned remaining work only

**Decision**: Late-session "Add exercise" adds a selected exercise and set count to the active plan as remaining work. It does not create completed sets.

**Rationale**: The user chose this behavior explicitly. It keeps session history accurate because sets only become completed after normal logging.

**Alternatives considered**:
- Treat selected sets as completed: rejected by clarification.
- Ask each time whether sets are completed or planned: rejected as extra decision load for this flow.

## Decision 6: Enforce 1-20 sets in picker and plan model validation

**Decision**: The picker will allow set counts from 1 through 20, and selected exercise validation will reject values outside that range.

**Rationale**: The user selected 1-20. Enforcing this at both UI and data boundaries prevents corrupted plan entries and accidental huge set counts.

**Alternatives considered**:
- 1-10 sets: rejected as too restrictive for high-volume training.
- No maximum: rejected because it weakens validation and acceptance tests.

## T050: Firestore Index Audit for Exercise Search

### exerciseCatalog collection

The primary query is:

```
collection('exerciseCatalog').where('isActive', isEqualTo: true)
```

This is a single-field equality filter. Firestore auto-indexes single fields by default. **No composite index is required** for this query.

If additional filtering (e.g., by `muscleGroup`) is added in the future, a composite index on `(isActive ASC, muscleGroup ASC)` would be required.

### personalExercises subcollection

The query is:

```
collection('users/{userId}/personalExercises')
```

This is a simple collection read (no filters beyond the user path). **No index is required**.

If filtered by `normalizedName` for server-side prefix search, a single-field index on `normalizedName` would be needed. Currently all filtering is done client-side.

### exerciseReviewSubmissions collection

Reads are either by `submittedBy == auth.uid` or by moderators. No Firestore queries are issued by the client for this collection — writes only. **No index required**.

### Summary

All current queries are covered by Firestore automatic single-field indexes. No manual composite index configuration is needed for the initial release. Monitor the Firebase Console for index creation suggestions if query patterns change.

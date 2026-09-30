# Offline queue vs Firestore persistence

**Status:** Accepted  
**Date:** 2026-09-17  
**Related:** Z-OFF-001, Z-OFF-002

## Context

The app keeps a **custom offline queue** (`OfflineManager` + `offline_handlers.dart`) for
operations that need optimistic UI or non-Firestore side effects (media upload, likes,
comments, session events). Firestore also has its own **SDK write queue** for direct
document writes.

## Decision

1. **Keep the custom queue** for user-scoped ops that Firestore persistence alone cannot
   cover (multipart uploads, cross-collection orchestration, UI pending badges).
2. **Do not double-enqueue** the same logical write: if a path uses the custom queue, it
   must not also fire a live Firestore write that will replay again on reconnect without
   an idempotency key.
3. Session events use a **stable `clientEventId`** as the Firestore document id so custom
   queue replay and optimistic UI converge on one doc (Z-OFF-002 / Z-RT-004).
4. The queue is **user-scoped** and cleared on sign-out (Z-OFF-001).

## Prefer SDK when…

- Single-document upsert with no media / no multi-step side effects → write through
  Firestore and rely on SDK persistence.
- Custom queue is reserved for multi-step or non-Firestore work.

## Consequences

1. New offline paths must pick **one** durability mechanism and document it.
2. Replay handlers must be idempotent (stable ids / merge writes).
3. Long-term: evaluate shrinking the custom queue once media and engagement paths have
   server-side idempotency.

## Verification

- Session event writes pass `clientEventId` into doc ids.
- Sign-out clears the user-scoped queue.
- Contract / unit tests cover stable event ids and user scoping.

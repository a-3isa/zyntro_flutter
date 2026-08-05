# Phase 1 Data Model: Resume Active Session on App Re-entry

**Branch**: `007-resume-active-session` | **Date**: 2026-08-05

## Session — `sessions/{sessionId}`

### Existing fields this feature reads

| Field | Type | Notes |
|-------|------|-------|
| `participants` | `string[]` | Gates reads in `firestore.rules:287-289`. Never mutated by this feature. |
| `status` | `string` | `active` / `paused` / `completed` / `cancelled` (`constants.dart:131-135`) |
| `phase` | `string` | `setup` / `live` — **those two only** (`constants.dart:280-282`). There is no recap phase; a wrapped-up session is `status: completed`. Only `live` is resumable (FR-002). |
| `participantTypes` | `map<string,string>` | Drives `derivedMode`; used to pick the return view (FR-004) |
| `activeUserId` | `string?` | Whose turn it is, for the turn-based return view |
| `startedAt` | `timestamp` | Existing |

### New fields

| Field | Type | Written by | Purpose |
|-------|------|-----------|---------|
| `lastActivityAt` | `timestamp` | Client, on every session write | FR-007a activity clock; FR-014 ordering; warm/quiet split |
| `lastOccupiedAt` | `timestamp` | Client, on presence heartbeat | FR-007 empty-room condition |
| `expiresAt` | `timestamp` | Client, derived | `max(lastActivityAt, lastOccupiedAt) + 3h`. Single range-filterable field for the sweep (research R4). |
| `endedParticipants` | `string[]` | Client, append own uid only | FR-008 per-member termination |

### Validation rules

- `expiresAt` MUST be recomputed in the same write that touches `lastActivityAt` or
  `lastOccupiedAt`. A write that updates one without the other is a defect.
- `endedParticipants` MUST only ever grow, and a client MUST only append its own uid.
- `status` becomes `completed` when `endedParticipants` covers every entry in `participants`.
- A session with no `expiresAt` (created before this feature) MUST be treated as expired on read.

### State transitions

`phase` and `status` are two axes, not one chain. `phase` only ever holds `setup` or `live`; ending a
session moves `status`, never `phase`.

```
phase:    setup ──────────► live
                             │
status:   active ────────────┼──► completed   (last member terminates)
                             ├──► completed   (endedReason: 'expired', sweep)
                             └──► cancelled   (existing cancelSetup path)
```

Only `phase == live` **and** `status == active` is resumable.

> [!warning] There is no `recap` phase
> `SessionPhase` is `{setup, live}` only (`lib/core/constants/constants.dart:280-282`). The recap is
> a **route** — `/session/recap/:sessionId` — that the member is sent to after `endSession`, not a
> state the session sits in. Do not add a phase check for it; `status: completed` already excludes it.

`expired` is represented as `status: 'completed'` with `endedReason: 'expired'` rather than a new
status value, so existing readers of `status` keep working unchanged.

| From | To | Trigger | Who writes |
|------|----|---------|-----------|
| live | live | any participant records work | client |
| live | completed (`endedReason: 'expired'`) | `now > expiresAt` | `expireStaleSessions` Function (admin) |
| live | live, member in `endedParticipants` | one member terminates or discards | client |
| live | completed | last member terminates, or the remaining member chooses "finish too" | client |

## Participation — derived, not a document

A member's participation is `participants` minus `endedParticipants`. There is no separate document.

| Property | Derivation |
|----------|-----------|
| is a participant | `participants.contains(uid)` |
| has terminated | `endedParticipants.contains(uid)` |
| is resumable for this member | participant AND not terminated AND `phase == 'live'` AND `status == 'active'` AND `now < expiresAt` |
| partner has left | `endedParticipants` is non-empty and does not contain this member — drives the finish-or-continue choice (FR-008a, FR-008b) |

## Presence — `sessions/{sessionId}/presence/{userId}`

Existing document (`presence_service.dart:94-106`). No shape change.

| Field | Type | Notes |
|-------|------|-------|
| `status` | `string` | `online` / `away` / `offline` |
| `lastChanged` | `timestamp` | Server-stamped |
| `userId` | `string` | Mirrors doc id |
| `isTyping` | `bool` | Unused by this feature |

**New read rule**: presence counts as live only when `status == 'online'` **and**
`now - lastChanged < 90s`. A force-killed app leaves `online` behind permanently, so `status` alone
cannot be trusted (research R6).

**New write**: a 60-second heartbeat refreshing `lastChanged` while the session room is open, and a
matching bump of the session's `lastOccupiedAt` / `expiresAt`.

## Resume decision — transient, never persisted

Computed once per cold start. No document, no cache, no dismissal record — a member cannot leave a
live session without terminating it, so there is nothing to suppress (spec A-005).

```
ResumeDecision =
  | None                                  // nothing resumable
  | Redirect(sessionId, workoutType)      // warm  — FR-003
  | Prompt(sessionId, workoutType)        // quiet — FR-003a
  | ExpiredNotice(sessionId)              // expired since last seen — FR-007b
```

| Input | Source |
|-------|--------|
| candidate session | most recent `lastActivityAt` among resumable sessions (FR-014) |
| `now - lastActivityAt` | session doc |
| other participant present | presence subcollection, with the 90s staleness rule |
| launch had an explicit destination | notification / deep-link payload (FR-010) |

Decision table:

| Condition | Outcome |
|-----------|---------|
| explicit launch destination present | `None` — deep link wins (FR-010) |
| no candidate session | `None` |
| candidate expired, and member has not been told | `ExpiredNotice` |
| activity < 15 min ago, or another participant present | `Redirect` |
| otherwise, still inside 3h | `Prompt` |

## Feature flag — `config/featureFlags`

| Field | Type | Notes |
|-------|------|-------|
| `resumeActiveSessionEnabled` | `bool` | Runtime kill switch (FR-023). Read once at startup; falls back to the compile-time default when missing, unreadable or offline |

World-readable, client-write-denied. Exists because the project has no other runtime config
mechanism — `firebase_remote_config` is not a dependency and `feature_flags.dart` is compile-time
only (research R10).

## Launch intent — in-memory, never persisted

| Field | Type | Source |
|-------|------|--------|
| `hasExplicitDestination` | `bool` | `getInitialMessage() != null`, captured in `NotificationService.init()` before `runApp()` (research R11) |

Defaults to `true` when unresolved, so an unknown launch never hijacks a notification tap (FR-010a).

## Indexes

`firebase/firestore.indexes.json` gains:

1. `sessions`: `participants` (array-contains) + `status` (asc) + `phase` (asc) + `lastActivityAt` (desc) — resume lookup (research R7)
2. `sessions`: `status` (asc) + `expiresAt` (asc) — expiry sweep (research R4)

## Security rules

`firebase/firestore.rules`, `match /sessions/{sessionId}` update predicates gain a case allowing a
participant to append **only their own uid** to `endedParticipants`, with no other field changed
except the derived timestamps. The expiry sweep writes with admin privileges and bypasses rules by
design, matching how `expireStalePairedInvites` already operates.

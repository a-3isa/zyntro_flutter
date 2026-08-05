# Contract: Resume Decision

**Feature**: `007-resume-active-session` | **Consumer**: `lib/app/navigation/app_router.dart`

The resume decision is a **pure function** over already-fetched state. No I/O, no clock reads from
inside — `now` is passed in. This is what makes every branch of the decision table testable without
Firestore or a widget tree, which Constitution II requires for cutover evidence.

## Types

```dart
sealed class ResumeDecision {
  const ResumeDecision();
}

/// Show the default landing screen. Nothing to resume.
class ResumeNone extends ResumeDecision {
  const ResumeNone();
}

/// Session is warm — go straight in, no confirmation. FR-003.
class ResumeRedirect extends ResumeDecision {
  final String sessionId;
  final String workoutType;
  const ResumeRedirect(this.sessionId, this.workoutType);
}

/// Session is quiet — ask continue or discard. FR-003a.
class ResumePrompt extends ResumeDecision {
  final String sessionId;
  final String workoutType;
  const ResumePrompt(this.sessionId, this.workoutType);
}

/// Session expired while the member was away. FR-007b.
class ResumeExpiredNotice extends ResumeDecision {
  final String sessionId;
  const ResumeExpiredNotice(this.sessionId);
}
```

## Inputs

```dart
class ResumeCandidate {
  final String sessionId;
  final String workoutType;
  final SessionPhase phase;
  final SessionStatus status;
  final DateTime? lastActivityAt;
  final DateTime? expiresAt;
  final bool memberHasTerminated;
  final bool otherParticipantPresent; // already staleness-filtered, see R6
}

ResumeDecision resolveResumeDecision({
  required ResumeCandidate? candidate,
  required DateTime now,
  required bool hasExplicitLaunchDestination,
  required bool resumeEnabled,          // kill switch, R10
  required bool expiryAlreadyNotified,
});
```

### Where the two flag inputs come from

Neither is invented by this contract; both are resolved before the router exists.

| Input | Source | Fallback |
|---|---|---|
| `hasExplicitLaunchDestination` | `launchIntentProvider`, set from `getInitialMessage() != null` inside `NotificationService.init()`, which runs before `runApp()` (research R11, session-lifecycle.md §8) | **`true`** — skip the redirect. Hijacking a notification tap is worse than not redirecting (FR-010a) |
| `resumeEnabled` | `resumeActiveSessionEnabledProvider`, reading `config/featureFlags.resumeActiveSessionEnabled` from Firestore at startup (research R10, session-lifecycle.md §7) | compile-time default; never blocks startup |

## Behaviour

Evaluated in order; first match wins.

| # | Condition | Result | Requirement |
|---|-----------|--------|-------------|
| 1 | `hasExplicitLaunchDestination` | `ResumeNone` | FR-010 |
| 2 | `!resumeEnabled` | `ResumeNone` | R10 kill switch |
| 3 | `candidate == null` | `ResumeNone` | — |
| 4 | `memberHasTerminated` | `ResumeNone` | FR-009 |
| 5 | `status != active` or `phase != live` | `ResumeNone` | FR-002, FR-002a, FR-002b |
| 6 | `expiresAt == null` or `now >= expiresAt` | `ResumeExpiredNotice`, or `ResumeNone` if `expiryAlreadyNotified` | FR-007, FR-007b |
| 7 | `now - lastActivityAt < 15min` or `otherParticipantPresent` | `ResumeRedirect` | FR-003 |
| 8 | otherwise | `ResumePrompt` | FR-003a |

### Guarantees

- **Total** — every input combination yields a decision; no nulls, no throws.
- **Deterministic** — same inputs, same output. `now` is injected, never read internally.
- **Order matters** — rule 1 above rule 2 means a deep link works even with resume disabled;
  rule 4 above rule 6 means a member who terminated is never shown an expiry notice.
- A `null` `lastActivityAt` with a valid non-expired `expiresAt` falls to rule 8 (`ResumePrompt`) —
  unknown activity is treated as quiet, never as warm.

## Router integration

```dart
// app_router.dart, inside the existing `if (isProfileComplete)` block.
if (isProfileComplete) {
  final decision = resumeDecision; // latched once at cold start
  if (isOnAuthEntry || isOnSetup) {
    return switch (decision) {
      ResumeRedirect(:final sessionId, :final workoutType) =>
        AppRouteLocations.sessionRoom(sessionId, type: workoutType),
      _ => AppRoutes.main,
    };
  }
  return null;
}
```

`ResumePrompt` and `ResumeExpiredNotice` deliberately route to `AppRoutes.main` and surface on the
landing screen — neither is a navigation, so neither belongs in the redirect.

### Latching

The decision is resolved **once** per process start, during the existing splash hold, following the
`startupProfileCheckDone` pattern (`app_router.dart:223-244`). It MUST NOT be recomputed on
`refreshListenable` ticks — that would re-fire the redirect on ordinary auth events and violate
FR-001a.

## Test matrix

Every row of the behaviour table gets a case, plus:

| Case | Expected |
|------|----------|
| warm session, deep link present | `ResumeNone` — rule 1 beats rule 7 |
| expired session, member already terminated | `ResumeNone` — rule 4 beats rule 6 |
| quiet session, partner present | `ResumeRedirect` — presence alone makes it warm |
| `lastActivityAt` exactly 15 min ago | `ResumePrompt` — boundary is exclusive |
| `now` exactly `expiresAt` | `ResumeExpiredNotice` — boundary is inclusive |
| `expiresAt == null` (legacy session) | `ResumeExpiredNotice` |
| setup-phase session | `ResumeNone` |
| completed session (already wrapped up) | `ResumeNone` — caught by the `status` half of rule 5, not by a phase check. `SessionPhase` has only `setup` and `live`; there is no recap phase to test for |
| launch intent unresolved (fallback `true`) | `ResumeNone` — fail safe, FR-010a |
| `resumeEnabled == false`, warm session | `ResumeNone` — kill switch holds under every other input |
| session goes warm while a prompt is showing | decision is latched at cold start, so the prompt stands; continuing enters the now-active session (spec Edge Cases) |

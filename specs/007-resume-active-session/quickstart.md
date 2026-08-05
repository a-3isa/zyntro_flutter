# Quickstart: Resume Active Session on App Re-entry

**Branch**: `007-resume-active-session`

## The one-paragraph version

`session_room_page.dart` currently calls `endSession` when the app is closed
(`AppLifecycleState.detached` / `hidden`), so a force-closed workout is destroyed on the way out and
there is nothing to come back to. Remove that, keep the session alive, and decide at cold start
whether to drop the member back into it. A scheduled Cloud Function closes sessions nobody returns
to after 3 hours.

## Read in this order

1. [spec.md](./spec.md) — what and why, plus the eight clarifications
2. [research.md](./research.md) — R1 is the root cause; R3 is the scope surprise
3. [contracts/resume-decision.md](./contracts/resume-decision.md) — the decision table
4. [contracts/session-lifecycle.md](./contracts/session-lifecycle.md) — every code change
5. [data-model.md](./data-model.md) — new fields, indexes, rules

## Files that matter

| File | What happens |
|------|-------------|
| `lib/features/session/presentation/session_room_page.dart:516-523` | delete the `endSession` call |
| `lib/features/session/presentation/session_room_page.dart:103-104, 482-496` | delete the 10-minute inactivity timer |
| `lib/app/navigation/app_router.dart:302-306` | branch on the resume decision |
| `lib/services/session_service.dart:190-206` | `checkActiveSession` → `findResumableSession` |
| `lib/services/session_service.dart:939-981` | `endSession` gains a per-member path |
| `functions/index.js:671-696` | copy this function's shape for `expireStaleSessions` |

## Build order

Phase A is a hard prerequisite. Removing termination-on-close without shipping the expiry sweep
leaves live sessions with nothing to close them.

```
A. Foundation ──► B. US1 direct resume ──► C. US2 correct role ──► D. US3 prompt + expiry notice
   (blocking)       (shippable alone)        (layers on)             (layers on)
```

## Verify it works

**US1 — the actual reported problem**
1. Start a gym session, log a set.
2. Device home button → swipe the app out of recents.
3. Reopen. You land in the session with the set intact, no prompt.

**US2 — the one who stayed keeps going**
1. Two accounts in a turn-based session. B force-closes their app.
2. A finishes their turn. The turn does **not** pass to B — A goes straight into the next set. No
   waiting screen, ever.
3. A logs 10 sets in a row solo. B's avatar reads "away", visibly different from "left".
4. B reopens. Session is shared again, A's 10 sets are visible to B, turn order resumes at the next
   handover — B does not seize a set A is part-way through.

**US3 — the quiet prompt**
1. Start a session, log a set, force-close.
2. Wait 15+ minutes (or set `lastActivityAt` back by hand in the emulator).
3. Reopen. You land on home and are asked continue-or-discard.

**US3 — expiry**
1. Force-close mid-session.
2. Set `expiresAt` into the past; run the scheduled function locally.
3. Session reads `completed` / `endedReason: 'expired'`; reopening shows the notice, and the logged
   sets are still there.

**Per-member terminate + partner notice**
1. Two accounts in one session.
2. A terminates. B's session stays live.
3. B in the room → dialog appears, offers finish-too or carry-on, doesn't eject her. Dismiss it
   without choosing → session carries on, and A's avatar now shows the "left" style. Leave and
   re-enter the session → avatar still shows it, dialog does not come back.
4. B with the app closed → reopen; the notification is waiting in the in-app notification list.
   Reopen again before reading it — still exactly one, not a stack.
5. B with push disabled entirely → opening the session still shows the choice, from
   `endedParticipants` rather than the notification.
6. B chooses carry on → finishes alone. B chooses finish too → session completes normally.

Only two states exist for B while the session is live: in the room, or app closed. There is no
"elsewhere in the app" case to test — leaving the session screen means terminating.

## Traps

- **`detached` is not guaranteed.** Swiping from recents often skips it; an OS kill always does.
  Never make correctness depend on any close callback.
- **Presence lies after a kill.** A killed app leaves `status: 'online'` forever. Always apply the
  90-second `lastChanged` staleness rule, or every abandoned session reads as warm.
- **`doc.ref`, not `doc.reference`** in the Cloud Function. The Dart property is undefined in the
  Node SDK and already broke a scheduled function in this file once.
- **Latch the decision.** Compute it once per cold start. Recomputing on `refreshListenable` ticks
  re-fires the redirect on ordinary auth events.
- **One range filter per Firestore query.** Hence the derived `expiresAt` rather than querying both
  FR-007 conditions.

- **The notification is not the source of truth.** The finish-or-continue choice renders from
  `endedParticipants` on the session document. Drive it off the notification and a member who was
  offline when their partner left silently loses the decision.
- **Away is not left.** Away = presence went stale, temporary, reverses on return. Left = terminated,
  permanent. Different avatar treatments, and only one of them is reversible. Collapsing the two
  means a partner who closed their app looks permanently gone.
- **Damp the shared→solo transition, not solo→shared.** Slow to notice a partner left is harmless;
  slow to notice they came back is not. Symmetric damping makes the view oscillate on weak signal.
- **The kill switch cannot be compile-time.** `firebase_remote_config` is not a dependency here, and
  `feature_flags.dart` is all `static bool get`. Put the flag in either and rollback needs an app
  store release. Use the `config/featureFlags` Firestore document.
- **Launch intent is a race you must not try to win.** Cold-start notification navigation fires from
  a post-frame callback at `notification_service.dart:355-363`; the redirect fires from the router.
  `init()` runs before `runApp()`, so capture the fact there and let the redirect stand down. Do not
  try to sequence the two callbacks.

**Rollback (ship gate, not polish)**
1. Set `config/featureFlags.resumeActiveSessionEnabled` to false in the Firebase console.
2. Cold-start the app — no redirect, no prompt, pre-feature behaviour, **without a new build**.
3. Confirm `expireStaleSessions` still sweeps. Expiry is never gated by the flag.

**Launch intent**
1. Hold a warm resumable session. Send yourself any push notification.
2. Force-close, then open the app *by tapping the notification*.
3. You land on the notification's destination. No resume redirect, no double navigation.

## Scope note

Per-member termination does not exist in the code today — `endSession` completes the session for
everyone. It is in scope here, confirmed by the author on 2026-08-05, together with the partner-left
notification. See [plan.md](./plan.md) Complexity Tracking and
[contracts/session-lifecycle.md](./contracts/session-lifecycle.md) §2.2–2.4.

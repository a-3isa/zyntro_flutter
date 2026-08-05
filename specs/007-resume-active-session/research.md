# Phase 0 Research: Resume Active Session on App Re-entry

**Branch**: `007-resume-active-session` | **Date**: 2026-08-05
**Spec**: [spec.md](./spec.md)

All findings below come from reading the current codebase, not from assumption. File and line
references were verified on this branch.

---

## R1 — Why the feature does not work today (root cause)

**Finding**: The app deliberately terminates the session when it is closed.

`lib/features/session/presentation/session_room_page.dart:516-523`:

```dart
case AppLifecycleState.detached:
case AppLifecycleState.hidden:
  presenceService.setAway(widget.sessionId, uid);
  // Terminate session when app is fully closed
  ref.read(sessionServiceProvider).endSession(widget.sessionId, uid, null);
  break;
```

**Decision**: Remove this termination-on-close branch. It is the single reason there is nothing to
resume. Presence must still be set away on `detached`/`hidden`; only the `endSession` call goes.

**Rationale**: Every other piece of the feature is downstream of this. Leaving it in place would
make a resume redirect unreachable by construction.

**Alternatives considered**:
- *Keep the call and re-create a session on relaunch* — rejected; loses all recorded sets and breaks
  FR-005.
- *Only terminate on `detached`, not `hidden`* — rejected; `detached` is exactly the force-close
  path the user described, and delivery of either callback on a hard kill is not guaranteed anyway.

**Caveat that shapes the whole design**: `detached` is **not reliably delivered** when a user swipes
the app out of the recent-apps list, and never on an OS kill. The app therefore cannot depend on any
client-side callback to close out a session. This is why expiry must be server-side (R4).

---

## R2 — A second, competing termination path

**Finding**: `session_room_page.dart:103-104, 482-496` runs a client-side inactivity timer:

```dart
static const _inactivityLimit = Duration(minutes: 10);
...
_inactivityTimer = Timer(_inactivityLimit, _terminateSessionInactive);
```

After 10 minutes of no interaction it calls `endSession`.

**Decision**: Remove the client inactivity timer and let FR-007's server-side 3-hour expiry be the
only expiry authority.

**Rationale**: A 10-minute client timer directly contradicts the agreed 3-hour window, and it only
runs while the screen is mounted — so it punishes the member who stayed in the app while doing
nothing about the member who force-closed. Two expiry authorities with different thresholds would
produce behaviour nobody can predict.

**Alternatives considered**:
- *Raise the timer to 3 hours* — rejected; still dead when the app is closed, which is the case that
  matters, and it would double-fire against the server rule.

---

## R3 — Per-member termination does not exist in the code

**Finding**: `lib/services/session_service.dart:939-981`, `endSession` ends the session for
**everyone**:

```dart
batch.update(_firestore.collection('sessions').doc(sessionId), {
  'status': 'completed',
  'endedAt': FieldValue.serverTimestamp(),
  ...
});
// 3. Log workouts for all participants
for (final participantId in session.participants) { ... }
```

There is no `leaveSession`, no `arrayRemove` on `participants`, and no per-participant left/ended
marker anywhere in `lib/` (searched: `leaveSession|removeParticipant|arrayRemove|leftParticipants|
didLeave` — zero matches).

**Decision**: Build per-member termination as part of this feature. Confirmed by the author on
2026-08-05: terminating was always meant to end the session for the terminating member only, with the
remaining participant notified that their partner left and free to finish too or carry on. The
spec's Out-of-Scope wording was corrected to match.

**Rationale**: FR-008 and FR-008a depend on it, and the discard branch of the quiet-session prompt
(FR-003b) has nowhere to write without it. The spec asserts this is existing behaviour; it is not.
Flagged to the author rather than silently absorbed — see [plan.md](./plan.md) Complexity Tracking.

**Approach**: Add `endedParticipants: [userId]` to the session document. A session's status becomes
`completed` only when that array covers every entry in `participants`. `endSession` gains a
per-member path; the whole-session completion path stays for the last member out, so scoring, streak,
and workout-logging behaviour is unchanged for solo sessions.

The remaining participant is notified via a new `partner_left` notification type, but the
finish-or-continue choice is rendered from `endedParticipants` on the session document rather than
from the notification — so a member who was offline when their partner left still gets the choice on
return (FR-008b). See [contracts/session-lifecycle.md](./contracts/session-lifecycle.md) §2.4.

**Alternatives considered**:
- *Remove the member from `participants`* — rejected; the security rules gate reads on
  `hasParticipant(resource.data.participants, request.auth.uid)`
  (`firebase/firestore.rules:287-289`), so removing them would revoke their read access to a session
  they may still need in recap, and would corrupt `participants`-based workout logging.

---

## R4 — Server-side expiry

**Finding**: The codebase already has the exact pattern needed —
`functions/index.js:671-696`, `expireStalePairedInvites`, an `onSchedule("every 15 minutes")`
function that queries a timestamp field and batch-updates up to 400 docs.

**Decision**: Add `expireStaleSessions`, modelled directly on it, running every 15 minutes.

**Rationale**: Satisfies A-009 (expiry cannot depend on any member's app running) and matches an
established, deployed pattern in this repo. Admin privileges bypass the client rules that would
otherwise block a status write.

**Query shape**: Firestore permits only one range filter per query, so the two conditions in FR-007
cannot be expressed as a single query. Resolve by storing one derived field,
`expiresAt = max(lastActivityAt, lastOccupiedAt) + 3h`, recomputed on every activity and presence
change, and query `where('status','==','active').where('expiresAt','<',now)`. One range filter, one
composite index.

**Alternatives considered**:
- *Two scheduled queries, one per condition* — rejected; doubles reads and can double-write the same
  doc in one run.
- *Compute expiry on the client at read time* — rejected; leaves sessions live in the data, which
  FR-007 explicitly forbids.

**Granularity note**: A 15-minute schedule means a session can sit expired-but-unswept for up to 15
minutes. FR-002's resume check must therefore evaluate `expiresAt` itself rather than trusting
`status` alone, so a member returning in that window is never redirected into an expired session.

---

## R5 — Where the redirect belongs

**Finding**: `lib/app/navigation/app_router.dart:246-311` is a single `GoRouter.redirect` that
already sequences splash → auth → rollback → profile-completion, ending at:

```dart
if (isProfileComplete) {
  if (isOnAuthEntry || isOnSetup) return AppRoutes.main;
  return null;
}
```

It re-evaluates via `refreshListenable: authChangeNotifier` without rebuilding the router, and
mutable closure vars (`authState`, `profileComplete`, `startupProfileCheckDone`) are updated by
`ref.listen`.

**Decision**: Add a `resumeDecision` closure var following the identical pattern, and branch inside
that `isProfileComplete` block: when the decision is `redirect(sessionId, type)` and the member is on
an auth-entry or setup route, return `AppRouteLocations.sessionRoom(...)` instead of
`AppRoutes.main`.

**Rationale**: Places the decision after auth and onboarding, satisfying FR-011 for free, and after
the rollback guard. Reusing the existing closure-var pattern avoids the splash-frame flash the file's
own comments (lines 196-199) describe fixing, satisfying FR-015.

**Alternatives considered**:
- *Redirect from `SplashPage`* — rejected; splash is inside the redirect chain, so navigating from it
  races the router's own decision.
- *Redirect from the home screen after it mounts* — rejected; the member would see home first,
  breaking FR-015's no-flash rule.

**Cold-start scoping (FR-001 / FR-001a)**: The decision must be computed **once** per process start
and latched, not recomputed on every `refreshListenable` tick. A one-shot
`resumeDecisionProvider` resolved during the existing splash hold, mirroring
`startupProfileCheckDone`, gives cold-start-only semantics without adding lifecycle observers.

---

## R6 — Presence already exists

**Finding**: `lib/services/presence_service.dart` writes `sessions/{id}/presence/{userId}` with
`status` (`online`/`away`/`offline`) and a server-stamped `lastChanged`. `session_room_page.dart:505-518`
already drives it from `didChangeAppLifecycleState`.

**Decision**: Reuse it for the warm/quiet split (FR-003/FR-003a) and for `lastOccupiedAt`. Do **not**
trust `status` alone — treat presence as stale when `lastChanged` is older than a 90-second
threshold, because a force-killed app never writes `away` or `offline`.

**Rationale**: A killed app leaves `status: 'online'` behind forever. Without a staleness check every
abandoned session would read as warm and would redirect with no prompt, inverting the agreed
behaviour.

**Consequence**: A heartbeat is needed while the session room is open — refresh `lastChanged` on a
periodic tick so a genuinely present member is never misread as stale. 60 seconds against a 90-second
threshold gives one missed beat of tolerance.

**Alternatives considered**:
- *Firebase Realtime Database `onDisconnect`* — the standard answer to exactly this problem and
  strictly more reliable, but rejected for this slice: the project has no RTDB instance configured
  (`firebase.json` declares firestore, storage and functions only), so it would mean provisioning a
  second database for one flag. Recorded as a follow-up if heartbeat accuracy proves insufficient.

---

## R7 — Finding the session to resume

**Finding**: `session_service.dart:190-206`, `checkActiveSession(userId)` already queries
`participants arrayContains userId` + `status == 'active'` and returns the first doc id.

**Decision**: Extend rather than replace. The resume query needs `phase == 'live'`, ordering by
activity, exclusion of members who already terminated, and the `expiresAt` guard from R4 — but the
collection, the participant filter, and the error-swallowing shape are all reusable.

**Rationale**: `checkActiveSession` returns `snapshot.docs.first` with no ordering, which is
non-deterministic and cannot satisfy FR-014's most-recent-activity rule.

**Index required**: `sessions` composite on `participants` (array-contains) + `status` + `phase` +
`lastActivityAt` (desc), added to `firebase/firestore.indexes.json`.

---

## R8 — Offline resume (FR-012)

**Finding**: Branch `006-offline-cache-sync` is the immediately preceding feature and covers cache
and pending-write marking.

**Decision**: Consume it; build nothing new. The resume lookup runs through the same Firestore
instance, so an offline cold start is served from the local cache. Pending-write badging is
`006`'s contract, not this feature's.

**Rationale**: The spec's own checklist flagged this overlap. Duplicating cache logic here would
violate Constitution I (scope discipline).

**Open dependency**: If `006` has not merged when this ships, FR-012 degrades to "resume works
offline from cache, without the pending-work badge". Recorded as a risk in
[plan.md](./plan.md), not a blocker.

---

## R9 — Telemetry (Constitution IV)

**Decision**: Emit four analytics events — `session_resume_redirect`, `session_resume_prompt_shown`,
`session_resume_prompt_answered` (with `continue`/`discard`), and `session_expired_swept` — plus an
error counter for the fallback path in FR-016.

**Rationale**: Constitution IV requires success rate, error rate, and rollback-trigger conditions to
be live before cutover. These four cover SC-001, SC-005, SC-007 and SC-010 directly.

**Rollback trigger**: A spike in `session_resume_redirect` errors, or any redirect into an expired
session, flips the kill switch (R10).

---

## R10 — Rollback path (Constitution IV)

**Finding**: The project has **no runtime configuration mechanism at all.**

- `firebase_remote_config` is absent from `pubspec.yaml` and referenced nowhere in `lib/` (searched
  `remote_config|RemoteConfig|firebase_remote_config` across all Dart and YAML: zero matches).
- The existing flag system, `lib/core/constants/feature_flags.dart`, is entirely compile-time:
  every flag is a `static bool get isXEnabled => true;`. Its own header instructs the reader to
  "change the return value from `false` to `true`" — i.e. edit code and rebuild.
- `lib/app/app_runtime_config.dart` is environment selection driven by `.env` files at build time,
  not runtime config.

An earlier draft of this plan called for a "remote-config-backed flag" and the task list put it in
`app_runtime_config.dart`. Both were wrong: as written, rolling the feature back would have required
a full app store release, which does not satisfy Constitution IV's "tested rollback path before
cutover" in any meaningful sense.

**Decision**: Back the kill switch with a **Firestore config document** — `config/featureFlags`, field
`resumeActiveSessionEnabled` — read once at startup, exposed through a provider that mirrors the
existing `pairedFriendSessionsEnabledProvider` shape in `feature_flags.dart`. Default to the
compile-time constant when the document is missing, unreadable, or the app is offline.

**Rationale**:
- Firestore is already a hard dependency, already initialised before the router is built, and already
  cached offline — no new package, no new failure mode.
- Rollback becomes editing one boolean in the Firebase console, which is a genuine rollback path.
- Keeps the established `Provider<bool>` flag idiom rather than inventing a second one.

**Alternatives considered**:
- *Add `firebase_remote_config`* — the textbook answer, and better if more flags follow. Rejected for
  this slice: a new dependency, new init path, and staged-rollout semantics nobody needs for a single
  boolean. Recorded as the natural upgrade if runtime flags become common.
- *Keep it compile-time in `feature_flags.dart`* — rejected; rollback via app store release can take
  days, which is not a rollback path.

**Security note**: The config document must be world-readable and client-write-denied. Rules for it
belong with the rules change in T007's phase.

**Not gated by the switch**: the removal of termination-on-close (R1) and the server expiry (R4).
With the switch off and termination-on-close already removed, gating expiry too would leak live
sessions forever. Expiry runs in both states.

---

## R11 — The launch-intent race (FR-010)

**Finding**: Cold-start notification handling already exists, and it will race the resume redirect.

`lib/services/notification_service.dart:355-363`:

```dart
// Handle notification tap that launched the app from terminated state.
// onMessageOpenedApp does NOT fire for this case — only getInitialMessage does.
// init() is called before runApp(), so defer navigation one frame.
final initialMessage = await _messaging.getInitialMessage();
if (initialMessage != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_navigateBasedOnData(initialMessage.data));
  });
}
```

The resume redirect fires from the router's `redirect` callback; this fires from a post-frame
callback. Both target the same navigator, and nothing sequences them. A member who taps a
notification while holding a resumable session would get whichever landed last — non-deterministic.

The repo has already been bitten by an adjacent version of this: audit ticket **AUD-014, "Preserve
protected deep links through auth"** (severity High) records protected routes losing their intended
destination through the auth redirect.

**Decision**: `notification_service.init()` already runs **before** `runApp()`, so the answer is to
capture rather than to synchronise. Have `init()` record whether `getInitialMessage()` returned a
payload into a `launchIntentProvider` before the router is ever built. The resume decision reads that
provider as `hasExplicitLaunchDestination` (rule 1 of the decision table) and stands down.

**Rationale**: Turns a race into an ordering fact. No locks, no delays, no coordination between two
navigation sources — one of them simply never starts.

**Fail-safe**: If the launch intent cannot be resolved, treat it as present and skip the redirect
(FR-010a). Landing on the intended destination is always recoverable; hijacking a member's
notification tap is not.

**Alternatives considered**:
- *Delay the notification navigation until the resume decision settles* — rejected; adds latency to
  the deep-link path and reintroduces ordering assumptions between two independent callbacks.
- *Let the redirect win and re-navigate afterwards* — rejected; produces exactly the double
  navigation FR-015 forbids.

---

## Unresolved

None. No `NEEDS CLARIFICATION` markers remain in Technical Context.

Two corrections came out of the cross-artifact analysis and are tracked in
[plan.md](./plan.md) Complexity Tracking:

- **R3** — the spec listed per-member termination as pre-existing behaviour; it does not exist and is
  built here. Confirmed in scope by the author on 2026-08-05.
- **R10** — the plan called for a "remote-config-backed flag" against a project that has no runtime
  config mechanism of any kind. Replaced with a Firestore-backed flag.

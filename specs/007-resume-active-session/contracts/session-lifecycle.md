# Contract: Session Lifecycle Changes

**Feature**: `007-resume-active-session`
**Touches**: `lib/services/session_service.dart`, `lib/services/presence_service.dart`,
`functions/index.js`, `firebase/firestore.rules`

## 1. Removed behaviour

### 1.1 Termination on app close

`session_room_page.dart`, `didChangeAppLifecycleState`:

```dart
case AppLifecycleState.detached:
case AppLifecycleState.hidden:
  presenceService.setAway(widget.sessionId, uid);
- ref.read(sessionServiceProvider).endSession(widget.sessionId, uid, null);
  break;
```

`setAway` stays. The `endSession` call goes. This is the root cause (research R1).

### 1.2 Client inactivity timer

`_inactivityTimer`, `_inactivityLimit` and `_terminateSessionInactive` are removed entirely. The
scheduled Function is the only expiry authority (research R2).

**Guard**: neither removal may ship without §3 in place, or live sessions leak with nothing to close
them.

## 2. `SessionService` additions

### 2.1 `findResumableSession`

```dart
Future<ResumeCandidate?> findResumableSession(String userId);
```

- Queries `sessions` where `participants` array-contains `userId`, `status == 'active'`,
  `phase == 'live'`, ordered by `lastActivityAt` desc, limit 1 (FR-014).
- Filters out candidates where `endedParticipants` contains `userId`.
- Reads presence for the other participants and applies the 90-second staleness rule (research R6).
- Returns `null` on any error — never throws into startup (FR-016).
- Requires the composite index in [data-model.md](../data-model.md#indexes).

Extends rather than replaces `checkActiveSession` (`session_service.dart:190-206`), which has no
ordering and cannot satisfy FR-014.

### 2.2 `terminateForMember`

```dart
Future<void> terminateForMember(String sessionId, String userId);
```

- Appends `userId` to `endedParticipants` via `FieldValue.arrayUnion`.
- When `endedParticipants` then covers every entry in `participants`, delegates to the existing
  `endSession` so scoring, streaks and workout logging are unchanged for the last member out.
- Otherwise the session document keeps `status: 'active'` and the remaining participant stays
  resumable (FR-008).
- Writes a `leave` event to the `events` subcollection, matching the existing event conventions.
- Notifies every remaining participant (§2.4).

**This is new behaviour, not a refactor.** `endSession` currently completes the session for all
participants (`session_service.dart:939-981`); no per-member path exists (research R3). Author
confirmed 2026-08-05 that per-member termination is the intended semantic and is in scope.

### 2.4 Partner-left notification

`notification_service.dart` gains a `partnerLeft` case in the `NotificationType` enum
(`notification_service.dart:27-46`) with value `'partner_left'`, following the shape of the existing
`sessionInvite` and `jointPostInvite` cases.

- Written by `terminateForMember` for each remaining participant, keyed deterministically as
  `partner_left_<sessionId>_<leaverId>` so a retry cannot double-notify.
- Payload carries `sessionId` and the leaver's display name.
- **The notification informs; it never acts.** Neither delivery nor a tap ends the remaining
  member's session (FR-008a).

**Two routes, both built (FR-008b):**

| | Route 1 — notification | Route 2 — the session record |
|---|---|---|
| What it is | stored notification document + push | leaver's id written to `endedParticipants` |
| Purpose | speed — member finds out right away | guarantee — the choice cannot be lost |
| Reaches | member with the app closed — the only away-state that exists | member whenever they open the session |
| Survives app restart? | yes — the document persists and shows in the in-app list | yes |
| Can fail? | push delivery can; the stored document cannot | no |

**The notification is stored, not fleeting (FR-008b-i).** It is written as a notification document
the same way `sessionInvite` and `jointPostInvite` already are, so a member who was outside the app
when it fired finds it waiting in their in-app notification list on return. Push delivery is the
fast path on top; the document is what makes the notification itself survivable.

The deterministic key `partner_left_<sessionId>_<leaverId>` gives idempotency for free: reopening the
app repeatedly, or a write retry, cannot stack duplicates for one departure (FR-008b-ii).

**Route 2 is the authority.** The finish-or-continue sheet renders from `endedParticipants` on the
session document, never from notification receipt (FR-008c). Route 1 only ever routes the member to
the session; it does not carry the decision.

Concretely:

**Only two states are reachable.** A member whose session is live is either in the session room or
has the app closed. "Elsewhere in the app with a live session" cannot happen — leaving the session
screen requires terminating, and a terminated session is no longer theirs. Do not design or test for
a third state.

| Member's state when the partner leaves | What happens |
|---|---|
| in the session room | dialog appears in place, driven off the existing session snapshot stream — no ejection from the screen. Route 2 only; no notification needed, they are looking at it. See §2.5. |
| app closed | push fires (Route 1); the stored notification is waiting in the in-app list on return regardless of whether push landed. Opening the session shows the sheet (Route 2). |
| app closed, push never arrived or dismissed | stored notification still in the list; opening the session still shows the sheet (Route 2) |

This is why the sheet must not be built as a handler on the notification tap. Wire it to session
state and both routes fall out for free.

Choosing **finish too** calls `terminateForMember` for the member, which — being the last
participant — delegates to `endSession` and completes the session normally. Choosing **carry on**
dismisses the dialog and leaves the session live and solo.

### 2.5 In-room departure: dialog, then avatar state

Two layers, and the distinction matters — one is an interruption, the other is durable state.

**Layer 1 — the dialog (transient).** Fires once when `endedParticipants` gains an entry while the
member has the session room open. Tells them the partner left; offers finish-too or carry-on.

- Dismissable by tap-outside, back, or an explicit close (FR-008e).
- **Dismiss == carry on.** It never ends the session and never forces a choice.
- Shown **once per departure** (FR-008g). Track the departures already acknowledged in page state
  keyed by leaver id, so a rebuild, a stream re-emit, or a later return to the session does not
  re-raise it. Do not key it on "dialog has been shown this frame" — snapshot streams re-emit
  freely.

**Layer 2 — the avatar (durable).** The partner's avatar renders in a distinct "left" style for the
rest of the session, everywhere it appears (FR-008f). This is derived from `endedParticipants`, so
it is correct on first paint after a cold start with no dialog involved.

Avatar render sites to cover:

| File | Context |
|------|---------|
| `widgets/waiting_turn_screen.dart` | partner avatar with glow — the glow must not animate for a departed partner |
| `widgets/parallel_gym_view.dart` | partner side of a parallel session |
| `widgets/parallel_cardio_view.dart` | partner side of a parallel session |
| `session_room_page.dart` | participant strip / header |

The "left" style is a visual treatment only — dimmed, desaturated, with a clear left indicator. It
must not remove the avatar; the member should still see who they started with.

**Turn-based sessions**: if the departed partner held the turn, the session must hand the turn to the
remaining member rather than stalling on an `activeUserId` that will never act. Fold this into
`terminateForMember` alongside the `endedParticipants` write, in the same batch.

### 2.6 Continuing while a partner is away

**Away is not left.** Away means presence has gone stale while the member is still a participant and
has not terminated. It is temporary and reverses the moment they return.

| | Away | Left |
|---|---|---|
| Source of truth | presence stale (§4) | `endedParticipants` contains them |
| Duration | temporary, reverses on return | permanent for the session |
| Avatar | "away" treatment | "left" treatment (§2.5) — must not be confused |
| Turn eligible? | no, while stale | no, ever |

#### Turn eligibility

Introduce one predicate and route every turn decision through it:

```dart
bool canHoldTurn(String userId) =>
    !endedParticipants.contains(userId) && isPresenceLive(presence[userId], now);
```

- On turn handover, skip anyone failing `canHoldTurn`. With a two-member session and one away, the
  turn returns to the present member immediately (FR-017).
- When nobody qualifies, leave `activeUserId` as-is rather than clearing it. A session with no
  present members is heading for expiry anyway, and a null `activeUserId` would need handling on
  every read.
- `session_service.dart:1345` (`'activeUserId': nextUserId`) is the write that must respect this.

#### View selection

`SessionRoomPage` currently dispatches on `derivedMode`. Add the presence check ahead of it: when
every other participant fails `canHoldTurn`, render the solo view regardless of `derivedMode` —
never `WaitingTurnScreen` (FR-018). `derivedMode` itself is unchanged; this is a presentation-layer
override, not a data change, so the session reverts to shared automatically on return (FR-019).

#### Flicker damping (FR-021)

The 60s heartbeat / 90s staleness pair (§4) already tolerates one missed beat. On top of that, the
transition **shared → solo** must be delayed by a further grace period, while **solo → shared** takes
effect immediately.

Asymmetric on purpose: being slow to declare a partner away is harmless, while being slow to
recognise their return is not. This prevents the view oscillating on a weak connection.

Once a set is in progress, the view must not switch underneath it — a returning partner resumes turn
order at the next handover, never by seizing the current one.

#### Expiry interaction (FR-022)

Sets logged by the solo member stamp `lastActivityAt` and push `expiresAt` out exactly as they do in
a shared session, so a session with one active member never expires underneath them. This falls out
of §2.3 with no extra work — noted because it is easy to assume "one member away" implies "session
idle", which it does not.

### 2.3 Activity stamping

Every existing write that changes session state — set logged, turn passed, plan committed, invite
accepted — additionally writes:

```dart
'lastActivityAt': FieldValue.serverTimestamp(),
'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 3))),
```

Viewing does not stamp `lastActivityAt` (FR-007a).

## 3. `expireStaleSessions` Cloud Function

Modelled on the deployed `expireStalePairedInvites` (`functions/index.js:671-696`).

```js
exports.expireStaleSessions = onSchedule("every 15 minutes", async () => {
  const now = Timestamp.now();
  const snapshot = await db
    .collection("sessions")
    .where("status", "==", "active")
    .where("expiresAt", "<", now)
    .limit(400)
    .get();
  // batch.update(doc.ref, { status: "completed",
  //                         endedReason: "expired",
  //                         endedAt: FieldValue.serverTimestamp() })
});
```

- Runs on admin privileges, bypassing client rules by design.
- Uses `doc.ref`, not `doc.reference` — the latter is the Dart property and threw on every run of an
  earlier function in this file (see the comment at `functions/index.js:686-688`).
- Idempotent: the `status == 'active'` filter means a re-run cannot double-expire.
- Emits the `session_expired_swept` count to logs (research R9).

**Recorded work is preserved.** Expiry only closes the session document; it does not touch the
`events` subcollection or logged sets (FR-007b).

## 4. Presence heartbeat

`presence_service.dart` gains:

```dart
Timer startHeartbeat(String sessionId, String userId);   // 60s tick
bool isPresenceLive(UserPresence p, DateTime now);        // status == online && age < 90s
```

Each heartbeat refreshes `lastChanged` and bumps the session's `lastOccupiedAt` and `expiresAt`.
The timer is cancelled in `SessionRoomPage.dispose`.

The 60s/90s pair gives one missed beat of tolerance before a member reads as absent.

## 5. Security rules

`match /sessions/{sessionId}`, update predicates gain a case permitting a participant to append
**only their own uid** to `endedParticipants`, changing no other field except the derived timestamps.

```
isOwnTerminationUpdate() — request.auth.uid is the only value added to endedParticipants,
                           and the diff touches no field outside
                           {endedParticipants, lastActivityAt, expiresAt}
```

Every other write path is unchanged. Reads remain gated on `hasParticipant`
(`firestore.rules:287-289`), so no member can ever resume a session they do not belong to (FR-011).

## 6. Telemetry

| Event | Fired when | Covers |
|-------|-----------|--------|
| `session_resume_redirect` | warm redirect executes | SC-001 |
| `session_resume_prompt_shown` | quiet prompt displayed | SC-005 |
| `session_resume_prompt_answered` | continue or discard chosen | SC-005, SC-007 |
| `session_expired_swept` | sweep closes a session | SC-010 |
| `session_partner_left_choice` | finish-too or carry-on chosen | SC-007 |
| `session_resume_error` | FR-016 fallback taken | rollback trigger |

## 7. Kill switch

> [!warning] There is no runtime config in this project
> `firebase_remote_config` is not a dependency, and `lib/core/constants/feature_flags.dart` is
> entirely compile-time (`static bool get isXEnabled => true`). A flag placed there or in
> `app_runtime_config.dart` would need an app store release to flip — which is not a rollback path.
> See research R10.

Back the switch with a Firestore config document:

```
config/featureFlags
  resumeActiveSessionEnabled: bool
```

- Read **once at startup**, before the router is built, alongside the other startup resolution.
- Exposed as `resumeActiveSessionEnabledProvider`, mirroring the existing
  `pairedFriendSessionsEnabledProvider` shape in `feature_flags.dart:56-58`.
- Defaults to the compile-time constant when the document is missing, unreadable, or the device is
  offline — never blocks startup.
- Rules: world-readable, client-write-denied. Add alongside the §5 rules change.

When off, `resolveResumeDecision` returns `ResumeNone` for every input and the app behaves as it does
today.

**Expiry is NOT gated by this switch** (FR-023a). With resume off and termination-on-close already
removed, gating expiry too would leave live sessions with nothing to close them.

## 8. Launch intent capture

> [!important] This is a race, not a preference
> The resume redirect fires from the router's `redirect` callback. Cold-start notification handling
> fires from a post-frame callback at `notification_service.dart:355-363`. Both drive the same
> navigator and nothing sequences them.

`NotificationService.init()` already runs **before** `runApp()`. Use that ordering rather than trying
to synchronise the two:

```dart
// notification_service.dart init(), at the existing getInitialMessage call
final initialMessage = await _messaging.getInitialMessage();
launchIntent.hasExplicitDestination = initialMessage != null;   // set BEFORE runApp
if (initialMessage != null) { /* existing postFrame navigation, unchanged */ }
```

`resolveResumeDecision` reads this as `hasExplicitLaunchDestination` — rule 1 of the decision table —
and returns `ResumeNone`, so the redirect never starts.

**Fail-safe**: if the value cannot be resolved, treat it as `true` and skip the redirect (FR-010a).
Landing on the intended destination is recoverable; hijacking a member's notification tap is not.

**Routing the new type**: `_navigateBasedOnData` currently branches on `session_invite`
(`notification_service.dart:436`). Add a `partner_left` branch routing to the session room, so
FR-008d's "tapping it takes the member to the session" holds.

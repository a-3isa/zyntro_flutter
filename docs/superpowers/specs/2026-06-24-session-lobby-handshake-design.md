# Session Lobby Handshake — Design

**Date:** 2026-06-24
**Status:** Approved (design) — pending implementation plan
**Area:** Paired "train together" sessions (invite → setup → live)

## 1. Problem & goal

Today, a host building a gym session must finish the full workout plan **before**
inviting a friend, then the friend opens a **separate acceptance page**
(`SessionInviteAcceptancePage`), picks a workout type, edits a personal copy of
the plan, and joins a session that is already `live`. There are no mutual
"waiting" states and no shared go-live moment.

We want an **invite-first, concurrent handshake** so both buddies prepare in
parallel and start together:

- Host picks a workout type, sends the invite, and **then** builds the plan.
- The friend opens the session setup lobby from the invite, chooses their
  category, joins setup, and then either waits for the host's plan or prepares
  their own side — depending on whether they train the same category.
- Neither starts training until **both** are ready (mutual go-live gate).

## 2. Confirmed requirements (from brainstorming)

1. **Sequencing:** invite first, build plan after (true concurrent handshake).
   This requires a much larger accept window than today's `pairedInviteTimeout`
   (currently **30 s** in `constants.dart`) — see §5.2. The friend must be able
   to receive the push and accept while the host is still building the plan.
2. **Plan model (same-category gym):** the friend gets **their own copy**,
   seeded from the host's plan; the host's plan is never mutated by the friend.
3. **UI location:** the whole handshake happens **inside the session setup
   screen** (the role-aware lobby experience), not on a separate acceptance page.
4. **Go-live gate:** the session goes `live` (timers start, training begins)
   **only after both** invited buddies are joined and ready. A pending invitee
   counts as not ready, so the host cannot start alone while an invite is still
   pending.
5. **Host plan-building** happens **inside the lobby's setup view** (the
   pre-invite plan builder is skipped for friend-invites).
6. **Different-category friend (parallel):** still gated — the friend confirms
   ready, the host waits for "buddy to agree", and both go live together.
7. **Same-category non-gym** (e.g. both running, no plan): the friend still sees
   a "ready to start?" confirm step, and the host waits for agreement.

**Unified model:** every friend-invite session runs through a `setup` phase with
a mutual readiness gate before `live`, regardless of category.

## 3. Chosen approach

**Approach B — a dedicated session lobby experience.** The existing
`GymSessionSetupPage` becomes the role-aware lobby for both roles, then
transitions both participants into the existing live `SessionRoomPage` when the
gate opens.

Rejected alternatives:
- **A (extend the live room's setup branch in-place):** reuses more code but
  tangles setup UI into the already-large `SessionRoomPage`.
- **C (keep the acceptance page, add waiting text):** contradicts requirement #3
  (handshake must be in the session screen).

## 4. Architecture

### 4.1 The lobby screen (evolve `GymSessionSetupPage`)
**Decision:** rather than a brand-new screen, evolve the existing
`GymSessionSetupPage` (route `/session/setup/:sessionId`, already reached via
`AppRouteLocations.sessionEntry` for gym+setup) into the role-aware lobby. It
already loads/ensures a plan, edits a draft, has a ready button + go-live
redirect, and joins the session — i.e. it is the gym/single-role slice of the
lobby. We generalize it (host vs friend, category choice, waiting states,
agree/edit, non-gym/parallel confirm) instead of duplicating it.
- **Route:** reuse `/session/setup/:sessionId` via
  `AppRouteLocations.gymSessionSetup(sessionId)`. Non-gym setups also route
  here now (today `sessionEntry` only sends gym+setup); friend-invites enter
  here. Do **not** add a separate `sessionLobby(...)` route/helper for this
  design pass.
- **Responsibility:** render the handshake by **role × readiness state**, drive
  the per-step actions (build plan / choose category / agree / edit / mark
  ready), and auto-navigate both participants to the live room when
  `phase == live`.
- **Initialization guard:** branch on role before running today's participant
  setup side effects. A pending invitee may watch the session/host plan and
  choose a category, but must not call `ensureGymPlan`, create presence, write
  events, or create their own plan doc until after `joinSetup` succeeds.
- **Inputs (watched):** `currentSessionProvider(sessionId)` (phase, participants,
  participantTypes, invitationStatus, hostId), the host plan doc, and the
  viewer's own plan doc / readiness after the viewer has joined.
- **Reused widgets:** the type-selection grid + host card (lifted from
  `SessionInviteAcceptancePage`), `GymPlanEditor`, `GymExercisePickerSheet`.

### 4.2 Retire `SessionInviteAcceptancePage`
Its pieces move into the lobby. The invite tap path (push notification +
`SessionInviteListener`) routes to the lobby instead of the acceptance page.

### 4.3 Role × state matrix

The friend opens the setup lobby while still a **pending invitee**. The
`SessionInviteListener` dialog and push-tap route to
`AppRouteLocations.gymSessionSetup(sessionId)`; they do not call `joinSetup`
yet, because the lobby must collect the friend's category first. The pending
invitee can read the session and host plan through the existing
`isPendingSessionInviteeById(sessionId)` rules, but must not create presence,
events, or a plan doc until they join.

| State | **Host** view | **Friend** view |
|---|---|---|
| Friend not yet accepted | "Waiting for your buddy to join" (ready action disabled) | invite prompt can open lobby or decline |
| Pending friend choosing category | (host type is fixed) | "Same or different category?" grid + Join / Decline |
| Same-cat **gym**, host plan not ready | building plan (editor) | **"Waiting for host to finish the plan"** |
| Same-cat **gym**, host plan ready | building / ready | host's plan shown → **Agree** (accept copy) or **Edit** (own copy) |
| Same-cat **non-gym** / **different-cat** | "I'm ready" confirm | own type/plan (parallel) or "Ready to start?" confirm |
| I'm ready, partner not | **"Waiting for buddy to agree"** | "Waiting for host / buddy" |
| **Both ready** | auto-enter live room | auto-enter live room |

"Agree" writes the friend's own ready plan as a copy of the host's; "Edit" lets
them modify that copy first. The host's plan is read-only to the friend. The
host can build and save a draft before the friend joins, but cannot mark ready
until the invitee has joined the setup roster. For a **gym** host, the "I'm
ready" action also requires a non-empty plan (≥1 exercise) so the friend never
agrees to an empty plan.

## 5. Backend & data flow

Reuses the existing `setup`-phase + per-plan `isReady` infrastructure.

1. **Host:** Train screen → pick type (+ friend) → `createSession(phase: setup,
   invitedUserIds: [friend])` + invite (CF-authoritative) → navigate host to
   lobby. (Solo/bot/random flows unchanged — no lobby.)
2. **Invite delivery:** unchanged — CF writes the durable `session_invite` doc +
   push; `SessionInviteListener` / push-tap now routes to the setup lobby as a
   pending invitee instead of the acceptance page.
3. **Friend joins setup:** the pending invitee chooses a category in the lobby,
   then taps Join. `joinSetup(sessionId, userId, chosenWorkoutType)` — **new,
   split out of today's `acceptInvite`** — adds the friend to `participants`
   while the session stays `setup`, records only
   `participantTypes.<friendId>`, sets `invitationStatus: accepted`, creates
   their not-ready plan stub, and keeps the friend in the joined lobby.
   - *Security:* the existing `isInviteAcceptUpdate` rule already permits exactly
     this transition (pending invitee adds only themselves; `participantTypes`
     only their own key). Tighten it so acceptance is only legal when the current
     session is still `status: active`, `phase: setup`,
     `invitationStatus: pending`, and unexpired. `joinSetup` keeps
     `invitationStatus: accepted`, preserves `status: active` and
     `phase: setup`, and uses the same affected-keys set the rule allows.
4. **In lobby:**
   - Host builds plan → `saveGymPlan` (draft, not ready). The host "I'm
     ready" action remains disabled while `invitationStatus == pending` or
     `participants` does not contain the invited friend; after join it calls
     `setGymPlanReady(host, true)`.
   - Pending friend picks category → Join calls `joinSetup`. For same-cat gym,
     the joined friend reads the host plan once ready, **Agree/Edit** → writes
     their own plan → "I'm ready" → `setGymPlanReady(friend, true)`. For
     non-gym/parallel, a confirm step marks a ready stub plan.
5. **Go-live gate:** `setGymPlanReady` flips `setup → live` only when:
   - every required buddy is present in `participants` (host + accepted friend
     for friend-invite sessions),
   - every participant has a plan/stub document,
   - every participant plan has `isReady == true`, and
   - `invitationStatus` is not `pending` or `declined`.

   Today `setGymPlanReady` computes `allParticipantsReady` from the **current**
   `participants` only ([session_service.dart:1042-1050]); with `participants ==
   [host]` before the friend joins, a host ready-tap flips straight to `live`.
   The gate must therefore key off the **required roster** (host +
   `invitedUserIds`) and `invitationStatus == accepted`, not just the present
   `participants`.

   Generalize the readiness check so non-gym/parallel participants count via
   their ready stub (the code already creates stubs). In the same transaction
   that flips to `live`, also write the final `mode`
   (`derivePairedSessionMode(participantTypes)` — the friend may have changed
   category in the lobby) and set `sharedClockStartedAt:
   FieldValue.serverTimestamp()` if absent, so both clients enter the live room
   with the same mode and workout clock anchor.
6. **Auto-enter:** both setup lobby instances stream the session; on
   `phase == live` → `context.go(sessionRoom)`.

### 5.1 `acceptInvite` refactor
Split today's monolithic `acceptInvite` (join + plan + ready in one shot) into:
- invite entry navigation — `SessionInviteListener`, push-tap handling, and any
  compatibility `/session/accept/:id` route open
  `AppRouteLocations.gymSessionSetup(sessionId)` without mutating session state.
- `joinSetup(sessionId, userId, chosenWorkoutType)` — pre-check invite expiry,
  add participant to `setup`, record the friend's chosen type, set
  `invitationStatus: accepted`, and create a not-ready plan/stub in the same
  batch/transaction.
- lobby step actions — `saveDraftPlan`, `copyHostPlanForFriend`, and
  `markReady` (via existing `setGymPlanReady`). The friend's category is written
  by `joinSetup`; their ready action happens in the lobby after category/plan
  confirmation.

Keep the existing expiry pre-check (named, still-pending invitee) at the start of
`joinSetup`, and also reject if the session is no longer `status: active` or
`phase: setup`.

### 5.2 Invite accept window (blocking issue)

`pairedInviteTimeout` is currently **`Duration(seconds: 30)`**
([constants.dart:302]). Because `isInviteAcceptUpdate` only permits the join
while `inviteExpiresAt > request.time`, a 30 s window means the friend must
receive the push and accept within 30 s — incompatible with "invite first,
build plan after," where the host is still building when the friend decides.

**Fix:** raise `pairedInviteTimeout` to a handshake-appropriate window
(proposed **10 minutes**) so the friend can accept while the host builds. The
expiry still only gates the *accept* (join); once joined, the rest of the
handshake is ungated. The deployed `expireStalePairedInvites` sweeper already
cleans up never-answered invites at the new horizon. Note: this also lengthens
how long an unanswered invite ties up the host's "active session" slot — the
host's lobby "Cancel" (§6) is the manual escape hatch.

### 5.3 Rules and invariants

- `isInviteAcceptUpdate` remains the only legal pre-join self-add path for a
  paired invite. It must continue to allow exactly the join transition fields:
  `participants`, `participantTypes.<friendId>`, `invitationStatus`, and `mode`.
  It must also require the source session to be `status: active`,
  `phase: setup`, `invitationStatus: pending`, and unexpired, and the accepted
  update must preserve `status: active` and `phase: setup`.
- After the friend joins, participant updates must not be able to rewrite another
  user's `participantTypes` entry. Tighten participant-session rules or add a
  dedicated type-update rule so a user can write only
  `participantTypes.<request.auth.uid>`.
- The host's `participantTypes.<hostId>` is fixed by `createSession`; the friend
  can only choose their own type.
- Client-side plan writes remain owner-only: the friend writes only
  `sessions/{sessionId}/plans/{friendId}`. Copying the host plan means reading the
  host plan and writing a separate friend-owned plan, never updating the host
  document.
- Readiness must be computed from the required roster, not only from the current
  `participants` array, so a pending invitee cannot be accidentally ignored.

## 6. Edge cases
- **Friend declines before joining:** `declineInvite` → `invitationStatus:
  declined`, host sees the existing decline banner; session can be ended by host.
- **Friend leaves after joining setup:** use a separate `leaveSetup`/cancel path,
  not `declineInvite`. Because this is a paired handshake, the conservative
  behavior is to cancel the setup instead of silently converting it to solo:
  write `status: cancelled`, `endedAt: serverTimestamp()`,
  `cancelledBy: <friendId>`, `cancelReason: setup_partner_left`, and leave
  `phase`, `participants`, `participantTypes`, and `invitationStatus` intact for
  audit/history. Do not delete plan docs. The host sees a terminal "buddy left"
  state and must start or invite again.
- **Host abandons setup:** host "Cancel" uses the same setup-cancel semantics as
  `leaveSetup`, not the live-room `endSession` workout-completion flow: write
  `status: cancelled`, `endedAt: serverTimestamp()`, `cancelledBy: <hostId>`,
  and `cancelReason: setup_host_cancelled`. A never-answered invite is handled
  by the deployed `expireStalePairedInvites` sweeper if the host does not cancel
  manually.
- **Backgrounding / resume:** readiness lives in Firestore; either side can
  reopen the lobby and continue from the current state.
- **Different-category friend:** never blocks on the host's plan — they prepare
  their own parallel side and mark ready.
- **Invite expiry mid-setup:** if the invite expired before the friend joins,
  `joinSetup` throws "invite has expired" (host plan-building continues; host can
  cancel or re-invite).

## 7. Component boundaries
- `GymSessionSetupPage` — evolved into the role-aware lobby; pure render of
  role×state + action dispatch, with no business logic beyond reading providers
  and calling services.
- `SessionService` — `createSession(phase: setup)`, `joinSetup`,
  `saveGymPlan`, `copyHostPlanForFriend`, `setGymPlanReady` (roster-gated,
  mode- and clock-setting), `declineInvite`, `leaveSetup`, `cancelSetup`.
- `StartSessionPage` — for friend-invites, skip the pre-invite plan builder:
  pick type (+ friend) → `createSession(phase: setup)` + invite → route host to
  the lobby. Solo/bot/random paths unchanged.
- Routing — reuse `AppRouteLocations.gymSessionSetup(sessionId)` and the existing
  `/session/setup/:sessionId` `GoRoute`; repoint the retired `sessionAccept`
  route as a compatibility redirect/alias and every invite entry point —
  `SessionInviteListener`, push-tap in `notification_service`, and
  `NotificationsPage` session-invite taps — at the setup lobby.
- `constants.dart` — raise `pairedInviteTimeout` (§5.2).
- Reused widgets — type grid, host card, `GymPlanEditor`,
  `GymExercisePickerSheet` (no new plan-editing UI).

## 8. Testing
- **Service:** `createSession` writes `phase: setup` for friend-invites; a host
  ready attempt while the invite is still pending does not flip to `live`;
  `joinSetup` adds the participant without going live; `setGymPlanReady` flips to
  `live` only when the required friend has joined and **all** participants are
  ready (gym + non-gym/parallel), and writes `sharedClockStartedAt` in that same
  transaction; pre-join decline and post-join leave/cancel paths are distinct;
  setup cancel writes `status: cancelled` and does not create completed workout
  records.
  Add explicit coverage that a host ready-tap with only `[host]` in
  `participants` (friend not yet joined) does **not** flip to `live`, and that
  the go-live transaction writes `mode` + `sharedClockStartedAt`.
- **Widget (lobby):** each role×state cell renders the right content
  (host-waiting, pending friend category choice, friend-waiting-for-plan, friend
  agree/edit, ready/wait); pending invitee initialization does not call
  `ensureGymPlan`, create presence, create events, or create a plan doc before
  Join; on `phase == live` the lobby navigates to the room.
- **Routing/notification contracts:** `SessionInviteListener`,
  `notification_service` push-tap handling, `NotificationsPage` invite taps, and
  the compatibility `/session/accept/:id` route all resolve to
  `AppRouteLocations.gymSessionSetup(sessionId)` without calling `joinSetup`
  before the friend chooses a category.
- **Test migration:** the retired `SessionInviteAcceptancePage` and its
  `session_invite_acceptance_page_test.dart` (6 tests) are removed; their
  behaviour (type choice, host-plan seed, agree/edit) is re-covered by the lobby
  widget tests above.
- **Rules:** the join transition continues to pass `isInviteAcceptUpdate`; add
  emulator/rules-unit coverage (not only string `contains(...)` assertions) that
  a pending invitee can read the session/host plan but cannot create events,
  presence, or plan docs before joining; a joined participant can only write
  their own `participantTypes.<uid>` entry and cannot rewrite the host/friend
  type; a pending invite cannot bypass readiness; accept is denied when the
  session is cancelled, not `setup`, expired, or no longer pending; and
  `declineInvite` is denied after acceptance. Keep the existing string contract
  tests if useful, but the security acceptance evidence must execute the rules.

## 9. Out of scope
- Solo, bot, and random-matchmaking flows (no lobby).
- Changing the live session room's in-session mechanics.
- Server-side matchmaking-join migration (tracked separately).

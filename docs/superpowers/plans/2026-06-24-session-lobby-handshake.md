# Session Lobby Handshake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the paired "train together" flow into an invite-first concurrent handshake where both buddies prepare in a shared setup lobby and start together only when both are ready.

**Architecture:** Friend-invite sessions are created in `phase: setup`. The existing `GymSessionSetupPage` is evolved into a role-aware **lobby** (host vs friend, same/different category, waiting states, agree/edit). A roster-gated `setGymPlanReady` flips the session to `live` (and stamps `mode` + shared clock) only when the invited friend has joined and every participant is ready; both lobbies auto-enter the live room on that flip.

**Tech Stack:** Flutter, Riverpod, `go_router`, Cloud Firestore, Firestore security rules, `flutter_test` + `mocktail`.

Spec: `docs/superpowers/specs/2026-06-24-session-lobby-handshake-design.md`

## Global Constraints

- Flutter analyze must stay clean: `flutter analyze <changed files>` → "No issues found!".
- Clients write only their own notifications/plans (owner-only rule already deployed). Never write another user's `sessions/{id}/plans/{otherUid}` or `participantTypes.<otherUid>`.
- The join transition for a pending invitee must keep passing `isInviteAcceptUpdate` (changes only `participants`, `participantTypes.<self>`, `invitationStatus`, `mode`; `inviteExpiresAt > request.time`).
- A session goes `live` ONLY when: the invited friend is in `participants`, every participant has a plan/stub doc, every participant plan `isReady == true`, and `invitationStatus` is not `pending`/`declined`.
- Workout-type values come from `WorkoutType.value`; invitation states from `WorkoutInvitationStatus`; phases from `SessionPhase`.
- Reuse existing widgets (`GymPlanEditor`, `GymExercisePickerSheet`) — no new plan-editing UI.
- Run pure-logic tests with: `flutter test test/services/session_lobby_gate_test.dart --reporter compact`.

---

## File structure

- `lib/services/session_lobby_gate.dart` (Create) — pure decision helpers (`shouldGoLive`, `requiredRoster`) so the go-live gate is unit-testable without Firestore mocking.
- `lib/services/session_service.dart` (Modify) — `joinSetup`, roster-gated `setGymPlanReady`, `leaveSetup`/`cancelSetup`; `createSession` already accepts `phase`.
- `lib/core/constants/constants.dart` (Modify) — `pairedInviteTimeout`.
- `firebase/firestore.rules` (Modify) — restrict `participantTypes` writes to own key.
- `lib/features/session/presentation/gym_session_setup_page.dart` (Modify → the lobby) — role-aware states.
- `lib/features/session/presentation/widgets/lobby_waiting_view.dart` (Create) — shared "waiting…" panel.
- `lib/features/session/presentation/widgets/lobby_category_grid.dart` (Create) — friend same/different category chooser (lifted from acceptance page).
- `lib/app/navigation/app_router.dart`, `lib/app/navigation/app_route_locations.dart` (Modify) — route invite accept into the lobby; retire `sessionAccept`.
- `lib/services/notification_service.dart`, `lib/features/session/presentation/session_invite_listener.dart` (Modify) — invite entry points → lobby.
- `lib/features/session/presentation/start_session_page.dart` (Modify) — friend-invite skips pre-invite builder.
- `lib/features/session/presentation/session_invite_acceptance_page.dart` (Delete) + its test.

---

## Task 1: Raise the invite accept window

**Files:**
- Modify: `lib/core/constants/constants.dart:302`
- Test: `test/core/paired_invite_timeout_test.dart` (Create)

**Interfaces:**
- Produces: `const Duration pairedInviteTimeout` (value `Duration(minutes: 10)`).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/paired_invite_timeout_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';

void main() {
  test('invite window is long enough for the build-plan-after handshake', () {
    expect(pairedInviteTimeout, greaterThanOrEqualTo(const Duration(minutes: 5)));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/paired_invite_timeout_test.dart --reporter compact`
Expected: FAIL (current value is `Duration(seconds: 30)`).

- [ ] **Step 3: Apply the change**

In `lib/core/constants/constants.dart`, replace:
```dart
const Duration pairedInviteTimeout = Duration(seconds: 30);
```
with:
```dart
// Long enough for the invite-first lobby handshake: the friend must be able to
// receive the push and accept while the host is still building the plan.
const Duration pairedInviteTimeout = Duration(minutes: 10);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/paired_invite_timeout_test.dart --reporter compact`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/constants.dart test/core/paired_invite_timeout_test.dart
git commit -m "feat(session): widen paired invite window for lobby handshake"
```

---

## Task 2: Pure go-live gate helpers

**Files:**
- Create: `lib/services/session_lobby_gate.dart`
- Test: `test/services/session_lobby_gate_test.dart`

**Interfaces:**
- Produces:
  - `List<String> requiredRoster({required String hostId, required List<String> invitedUserIds})` — host + invited, de-duplicated.
  - `bool shouldGoLive({required List<String> requiredRoster, required List<String> participants, required Map<String, bool> planReadiness, required String? invitationStatus})` — true only when every required member is a participant, every required member's plan is ready, and `invitationStatus` is not `pending`/`declined`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/services/session_lobby_gate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/services/session_lobby_gate.dart';

void main() {
  group('requiredRoster', () {
    test('is host plus invited, de-duplicated', () {
      expect(
        requiredRoster(hostId: 'h', invitedUserIds: ['f', 'h']),
        ['h', 'f'],
      );
    });
  });

  group('shouldGoLive', () {
    const roster = ['h', 'f'];

    test('false when invited friend has not joined yet', () {
      expect(
        shouldGoLive(
          requiredRoster: roster,
          participants: ['h'],
          planReadiness: {'h': true},
          invitationStatus: 'accepted',
        ),
        isFalse,
      );
    });

    test('false when a required member is not ready', () {
      expect(
        shouldGoLive(
          requiredRoster: roster,
          participants: ['h', 'f'],
          planReadiness: {'h': true, 'f': false},
          invitationStatus: 'accepted',
        ),
        isFalse,
      );
    });

    test('false while the invitation is still pending', () {
      expect(
        shouldGoLive(
          requiredRoster: roster,
          participants: ['h', 'f'],
          planReadiness: {'h': true, 'f': true},
          invitationStatus: 'pending',
        ),
        isFalse,
      );
    });

    test('true when roster joined, all ready, invite accepted', () {
      expect(
        shouldGoLive(
          requiredRoster: roster,
          participants: ['h', 'f'],
          planReadiness: {'h': true, 'f': true},
          invitationStatus: 'accepted',
        ),
        isTrue,
      );
    });

    test('true for solo-style roster (no invite) when host ready', () {
      expect(
        shouldGoLive(
          requiredRoster: ['h'],
          participants: ['h'],
          planReadiness: {'h': true},
          invitationStatus: null,
        ),
        isTrue,
      );
    });

    test('matchmaking: false when a non-roster participant is not ready', () {
      // Matchmaking adds the partner via joinSession, so roster == [host] but
      // participants == [host, partner]. The partner must still be ready.
      expect(
        shouldGoLive(
          requiredRoster: ['h'],
          participants: ['h', 'p'],
          planReadiness: {'h': true, 'p': false},
          invitationStatus: null,
        ),
        isFalse,
      );
    });

    test('matchmaking: true when all participants ready (roster not naming partner)', () {
      expect(
        shouldGoLive(
          requiredRoster: ['h'],
          participants: ['h', 'p'],
          planReadiness: {'h': true, 'p': true},
          invitationStatus: null,
        ),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/session_lobby_gate_test.dart --reporter compact`
Expected: FAIL with "Target of URI doesn't exist: session_lobby_gate.dart".

- [ ] **Step 3: Write the implementation**

```dart
// lib/services/session_lobby_gate.dart

/// Pure decision helpers for the paired-session setup → live gate.
/// Extracted so the go-live rule is unit-testable without Firestore mocking.

/// Host plus any invited users, de-duplicated, host first.
List<String> requiredRoster({
  required String hostId,
  required List<String> invitedUserIds,
}) {
  final roster = <String>[hostId];
  for (final id in invitedUserIds) {
    if (id.isNotEmpty && !roster.contains(id)) roster.add(id);
  }
  return roster;
}

/// True only when every required member has joined, EVERY current participant
/// is ready, and the invite (if any) is neither pending nor declined.
///
/// Two distinct conditions, because the partner can arrive two ways:
///  - friend-invite: the partner is named in `invitedUserIds` (the roster) and
///    must have JOINED before go-live (host cannot start alone).
///  - matchmaking: the partner is added via joinSession and is NOT in the
///    roster — so readiness must be checked over ALL `participants`, not just
///    the roster, or a matchmaking session would go live with only the host
///    ready.
bool shouldGoLive({
  required List<String> requiredRoster,
  required List<String> participants,
  required Map<String, bool> planReadiness,
  required String? invitationStatus,
}) {
  if (invitationStatus == 'pending' || invitationStatus == 'declined') {
    return false;
  }
  if (participants.isEmpty) return false;
  // (1) every invited/required member must have joined.
  for (final member in requiredRoster) {
    if (!participants.contains(member)) return false;
  }
  // (2) every current participant must be ready.
  for (final participant in participants) {
    if (planReadiness[participant] != true) return false;
  }
  return true;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/session_lobby_gate_test.dart --reporter compact`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/session_lobby_gate.dart test/services/session_lobby_gate_test.dart
git commit -m "feat(session): pure go-live gate helpers for lobby handshake"
```

---

## Task 3: Roster-gate `setGymPlanReady` (+ stamp mode & clock)

**Files:**
- Modify: `lib/services/session_service.dart:980-1051` (the `setGymPlanReady` transaction)
- Test: covered by Task 2 (pure helper) + manual trace; add a regression note test in `test/services/session_lobby_gate_test.dart` is already done.

**Interfaces:**
- Consumes: `requiredRoster`, `shouldGoLive` (Task 2), existing `derivePairedSessionMode`, `WorkoutInvitationStatus`.
- Produces: `setGymPlanReady` only flips `phase: live` per the gate, and in the same transaction writes `mode` and `sharedClockStartedAt` (if absent).

- [ ] **Step 1: Add the import**

At the top of `lib/services/session_service.dart`, add:
```dart
import 'session_lobby_gate.dart';
```

- [ ] **Step 2: Replace the readiness/flip block**

In `setGymPlanReady`, replace the block that computes `allParticipantsReady` and flips the phase (currently `lib/services/session_service.dart:1029-1050`) with:

```dart
      // Readiness must be read for EVERY current participant (not just the
      // invited roster) so a matchmaking partner — added via joinSession and
      // absent from invitedUserIds — is not ignored by the gate.
      final planReadiness = <String, bool>{userId: isReady};
      for (final participantId in participants) {
        if (participantId == userId) continue;
        final memberPlanSnapshot = await transaction.get(
          plansCollection.doc(participantId),
        );
        final memberPlanData = memberPlanSnapshot.data();
        planReadiness[participantId] =
            memberPlanSnapshot.exists && memberPlanData != null
            ? GymSessionPlan.fromMap(memberPlanData).isReady
            : false;
      }

      final invitedUserIds =
          (sessionData['invitedUserIds'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];
      final roster = requiredRoster(
        hostId: hostId,
        invitedUserIds: invitedUserIds,
      );
      final invitationStatus = sessionData['invitationStatus'] as String?;
      allParticipantsReady = shouldGoLive(
        requiredRoster: roster,
        participants: participants,
        planReadiness: planReadiness,
        invitationStatus: invitationStatus,
      );

      if (currentPhase == SessionPhase.setup && allParticipantsReady) {
        final liveUpdate = <String, dynamic>{
          'phase': SessionPhase.live.value,
          'mode': mode, // derivePairedSessionMode(participantTypes) above
        };
        if (sessionData['sharedClockStartedAt'] == null) {
          liveUpdate['sharedClockStartedAt'] = FieldValue.serverTimestamp();
        }
        transaction.update(sessionRef, liveUpdate);
      }
```

> Note: `mode` and `participants` are already computed earlier in the existing
> transaction body (`derivePairedSessionMode(participantTypes)` and the
> `participants` list). Keep those lines.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/services/session_service.dart`
Expected: "No issues found!"

- [ ] **Step 4: Re-run the gate + service tests**

Run: `flutter test test/services/session_lobby_gate_test.dart test/services/session_service_test.dart --reporter compact`
Expected: PASS (existing session-service tests unchanged; gate tests pass).

- [ ] **Step 5: Commit**

```bash
git add lib/services/session_service.dart
git commit -m "fix(session): roster-gate go-live so host can't start before friend joins"
```

---

## Task 4: `joinSetup` — split the friend join out of `acceptInvite`

**Files:**
- Modify: `lib/services/session_service.dart` (add `joinSetup`; keep `acceptInvite` callable until UI is migrated, then remove in Task 10)
- Test: `test/services/session_service_test.dart` (add a focused test mirroring the existing `acceptInvite` test setup)

**Interfaces:**
- Consumes: existing `userCacheServiceProvider`, `WorkoutInvitationStatus`, `GymSessionPlan.defaultPersonalPlan`, the expiry pre-check pattern already in `acceptInvite`.
- Produces:
  `Future<void> joinSetup({required String sessionId, required String userId, required String chosenWorkoutType})`
  — verifies the caller is a named, still-pending, non-expired invitee **and** the session is still `status: active` + `phase: setup`; in one batch adds the caller to `participants`, sets `participantTypes.<userId>`, `invitationStatus: accepted`, and creates a **not-ready** plan stub at `plans/<userId>`. Preserves `status: active` and `phase: setup` (does NOT change them).

- [ ] **Step 1: Write the failing test**

Add to `test/services/session_service_test.dart` (reuse the file's existing mock harness and `kPaired*` ids; model it on the existing "real friend session allows exactly one eligible invitee" test):

```dart
  test('joinSetup adds the invitee in setup without going live', () async {
    // Arrange a pending, non-expired invite session doc via the existing
    // MockDocumentSnapshot pattern used by the acceptInvite test, with:
    //   hostId: kPairedHostId,
    //   participants: [kPairedHostId],
    //   invitedUserIds: [kPairedFriendId],
    //   invitationStatus: 'pending',
    //   inviteExpiresAt: Timestamp(now + 10min),
    //   phase: 'setup',
    //   type: 'gym',
    // (See the acceptInvite test above for the exact stubbing helpers.)

    await service.joinSetup(
      sessionId: kPairedSessionId,
      userId: kPairedFriendId,
      chosenWorkoutType: WorkoutType.gym.value,
    );

    // Assert the batch.update set participants arrayUnion + participantTypes.<friend>
    // + invitationStatus accepted, and DID NOT set phase. Verify via the
    // captured MockBatch.update arguments (same verification style as the
    // acceptInvite test).
  });

  test('joinSetup rejects a non-invited user', () async {
    // invitedUserIds: [someoneElse]
    expect(
      () => service.joinSetup(
        sessionId: kPairedSessionId,
        userId: kPairedFriendId,
        chosenWorkoutType: WorkoutType.gym.value,
      ),
      throwsA(isA<Exception>()),
    );
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/services/session_service_test.dart --reporter compact`
Expected: FAIL ("method 'joinSetup' isn't defined").

- [ ] **Step 3: Implement `joinSetup`**

Add to `SessionService` (model the expiry/eligibility pre-check on the current `acceptInvite` head):

```dart
  /// Friend joins a paired session's setup phase. Mirrors the start of
  /// acceptInvite (named, still-pending, non-expired invitee) but only joins —
  /// readiness/plan are completed later in the lobby via setGymPlanReady.
  Future<void> joinSetup({
    required String sessionId,
    required String userId,
    required String chosenWorkoutType,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final sessionDoc = await sessionRef.get();
    final sessionData = sessionDoc.data();

    final invitedUserIds =
        (sessionData?['invitedUserIds'] as List?)?.cast<String>() ??
        const <String>[];
    if (!invitedUserIds.contains(userId)) {
      throw Exception('You are not invited to this session.');
    }
    if (sessionData?['invitationStatus'] !=
        WorkoutInvitationStatus.pending.value) {
      throw Exception('This invite is no longer open.');
    }
    if (sessionData?['status'] != SessionStatus.active.value ||
        sessionData?['phase'] != SessionPhase.setup.value) {
      throw Exception('This session is no longer accepting buddies.');
    }

    final inviteExpiresAt = sessionData?['inviteExpiresAt'];
    final expiresAt = inviteExpiresAt is Timestamp
        ? inviteExpiresAt.toDate()
        : inviteExpiresAt is DateTime
        ? inviteExpiresAt
        : null;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw Exception('This invite has expired.');
    }

    final user = await _ref.read(userCacheServiceProvider).getUser(userId);
    final userName = user?.displayName ?? 'User';

    final batch = _firestore.batch();
    batch.update(sessionRef, {
      'participants': FieldValue.arrayUnion([userId]),
      'participantTypes.$userId': chosenWorkoutType,
      'invitationStatus': WorkoutInvitationStatus.accepted.value,
    });

    // Not-ready plan stub so the lobby can edit / confirm before readiness.
    final planRef = sessionRef.collection('plans').doc(userId);
    batch.set(
      planRef,
      GymSessionPlan.defaultPersonalPlan(
        userId: userId,
        workoutType: WorkoutType.fromString(chosenWorkoutType),
      ).copyWith(isReady: false).toMap(),
    );

    final joinEventRef = sessionRef
        .collection('events')
        .doc('join_${userId}_${DateTime.now().millisecondsSinceEpoch}');
    batch.set(joinEventRef, {
      'type': SessionEventType.join.value,
      'userId': userId,
      'text': '$userName joined the session',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await withRetryCircuitBreakerVoid(
      () => batch.commit(),
      operationType: 'session_join_setup',
      maxFailures: 5,
      cooldownDuration: const Duration(seconds: 30),
    );

    _ref.read(userCacheServiceProvider).warmSessionParticipants(sessionId);
  }
```

> If `GymSessionPlan` has no `copyWith(isReady:)`, build the stub directly:
> `GymSessionPlan(userId: userId, source: GymSessionPlanSource.personalCopy, isReady: false, exercises: const [])`.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/services/session_service_test.dart --reporter compact`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/services/session_service.dart
git add lib/services/session_service.dart test/services/session_service_test.dart
git commit -m "feat(session): add joinSetup for invite-first lobby join"
```

---

## Task 5: `leaveSetup` / host cancel

**Files:**
- Modify: `lib/services/session_service.dart`
- Test: `test/services/session_service_test.dart`

**Interfaces:**
- Produces a single shared setup-cancel path (spec §6 — a paired handshake is
  cancelled, never silently downgraded to solo):
  - `Future<void> cancelSetup({required String sessionId, required String byUserId, required String reason})`
    — writes `status: cancelled`, `endedAt: serverTimestamp()`,
    `cancelledBy: byUserId`, `cancelReason: reason`; leaves `phase`,
    `participants`, `participantTypes`, `invitationStatus`, and plan docs intact
    for audit. Allowed by `isParticipantSessionUpdate` (those fields aren't
    frozen; `participantTypes` is unchanged → empty diff passes the own-key rule).
  - Host "Cancel" → `cancelSetup(reason: 'setup_host_cancelled')`.
  - Friend "Leave" (after joining) → `cancelSetup(reason: 'setup_partner_left')`.

- [ ] **Step 1: Write the failing test**

```dart
  test('cancelSetup writes the audit fields and keeps roster intact', () async {
    // session doc exists, caller is a participant, status active/setup
    await service.cancelSetup(
      sessionId: kPairedSessionId,
      byUserId: kPairedHostId,
      reason: 'setup_host_cancelled',
    );
    // verify the captured update on the session doc ref contains:
    //   status: 'cancelled', cancelledBy: kPairedHostId,
    //   cancelReason: 'setup_host_cancelled', and an endedAt FieldValue,
    // and does NOT touch participants/participantTypes/invitationStatus/phase.
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/services/session_service_test.dart --reporter compact`
Expected: FAIL ("method 'cancelSetup' isn't defined").

- [ ] **Step 3: Implement**

```dart
  /// Terminal cancel for a paired setup handshake (host cancels or friend leaves
  /// after joining). A paired handshake is cancelled, not downgraded to solo.
  /// Leaves phase/participants/participantTypes/invitationStatus and plan docs
  /// intact for audit. status is not frozen for participants, so this passes
  /// isParticipantSessionUpdate; participantTypes is unchanged (empty diff).
  Future<void> cancelSetup({
    required String sessionId,
    required String byUserId,
    required String reason,
  }) async {
    await withRetry(
      () => _firestore.collection('sessions').doc(sessionId).update({
        'status': SessionStatus.cancelled.value,
        'endedAt': FieldValue.serverTimestamp(),
        'cancelledBy': byUserId,
        'cancelReason': reason,
      }),
    );
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/services/session_service_test.dart --reporter compact`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/services/session_service.dart
git add lib/services/session_service.dart test/services/session_service_test.dart
git commit -m "feat(session): add cancelSetup audit path for lobby host-cancel/friend-leave"
```

---

## Task 6: Harden session rules (own-key types + scoped invite accept)

**Files:**
- Modify: `firebase/firestore.rules` (`isParticipantSessionUpdate`, `isInviteAcceptUpdate`)
- Test: `test/firebase/firestore_rules_contract_test.dart`

**Interfaces:**
- Produces: (a) a participant update may change `participantTypes` only for
  `request.auth.uid`; (b) `isInviteAcceptUpdate` only accepts when the source
  session is `status: active` + `phase: setup` (in addition to the existing
  pending + unexpired checks).

- [ ] **Step 1: Write the failing contract tests**

Add to `test/firebase/firestore_rules_contract_test.dart`:

```dart
    test('participant updates can only change their own participantTypes', () {
      expect(
        rules,
        contains(
          "request.resource.data.participantTypes.diff(resource.data.participantTypes).affectedKeys().hasOnly([request.auth.uid])",
        ),
      );
    });

    test('invite accept is scoped to an active session still in setup', () {
      final idx = rules.indexOf('function isInviteAcceptUpdate()');
      expect(idx, isNonNegative);
      final body = rules.substring(idx, idx + 800);
      expect(body, contains("resource.data.status == 'active'"));
      expect(body, contains("resource.data.phase == 'setup'"));
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/firebase/firestore_rules_contract_test.dart --reporter compact`
Expected: FAIL (strings not present).

- [ ] **Step 3a: Restrict `participantTypes` to own key**

In `firebase/firestore.rules`, replace `isParticipantSessionUpdate` with:

```
    function isParticipantSessionUpdate() {
      return hasParticipant(resource.data.participants, request.auth.uid) &&
        !request.resource.data.diff(resource.data).affectedKeys()
          .hasAny(['hostId', 'invitedUserIds', 'invitationStatus']) &&
        request.resource.data.participantTypes
          .diff(resource.data.participantTypes)
          .affectedKeys().hasOnly([request.auth.uid]);
    }
```

> `diff().affectedKeys()` is empty when `participantTypes` is unchanged, and
> `[].hasOnly([uid])` is true — so state-only updates (status/phase/clock),
> the go-live flip, the cancel-with-audit update (Task 5), and matchmaking
> (writes only `participants`) still pass. Every session that reaches an update
> has `participantTypes` (set at create), so the field always exists.

- [ ] **Step 3b: Scope `isInviteAcceptUpdate` to active+setup**

In the existing `isInviteAcceptUpdate`, add two source-state conjuncts (e.g.
right after the `isPendingSessionInvitee(...)` line):

```
        resource.data.status == 'active' &&
        resource.data.phase == 'setup' &&
```

> `status`/`phase` aren't in the join's allowed `affectedKeys`
> (`['participants','participantTypes','invitationStatus','mode']`), so they
> cannot change during the accept — requiring the *source* to be active+setup is
> sufficient to also guarantee they're preserved.

- [ ] **Step 4: Validate + run the contract test**

Run: `flutter test test/firebase/firestore_rules_contract_test.dart --reporter compact`
Expected: PASS.

Then compile-check the rules (editor MCP validate or `firebase deploy --only
firestore:rules` in Task 12). Expected: "compiled successfully" (the pre-existing
`isModerationFieldChange` warnings are unrelated).

- [ ] **Step 5: Commit**

```bash
git add firebase/firestore.rules test/firebase/firestore_rules_contract_test.dart
git commit -m "fix(rules): own-key participantTypes + scope invite accept to active setup"
```

---

## Task 7: Route invite-accept into the lobby; add lobby waiting + category widgets

**Files:**
- Create: `lib/features/session/presentation/widgets/lobby_waiting_view.dart`
- Create: `lib/features/session/presentation/widgets/lobby_category_grid.dart`
- Modify: `lib/features/session/presentation/session_invite_listener.dart` (Accept → `joinSetup` then go to setup route)
- Modify: `lib/services/notification_service.dart` (`_navigateBasedOnData` session_invite branch → setup route)
- Modify: `lib/app/navigation/app_route_locations.dart` (`sessionAccept` returns the setup path) — keep the symbol to minimise churn
- Test: `test/features/session/presentation/lobby_waiting_view_test.dart`

**Interfaces:**
- Produces:
  - `LobbyWaitingView({required String title, String? subtitle})` — centered spinner + texts. Used for "Waiting for host to finish the plan", "Waiting for your buddy to join", "Waiting for buddy to agree".
  - `LobbyCategoryGrid({required WorkoutType hostType, required WorkoutType? selected, required ValueChanged<WorkoutType> onSelect})` — the same/different chooser (lift the grid from `SessionInviteAcceptancePage._buildTypeGrid`).

- [ ] **Step 1: Write the failing widget test**

```dart
// test/features/session/presentation/lobby_waiting_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/lobby_waiting_view.dart';

void main() {
  testWidgets('LobbyWaitingView shows title and subtitle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LobbyWaitingView(
          title: 'Waiting for host to finish the plan',
          subtitle: 'They are still building it',
        ),
      ),
    ));
    expect(find.text('Waiting for host to finish the plan'), findsOneWidget);
    expect(find.text('They are still building it'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/session/presentation/lobby_waiting_view_test.dart --reporter compact`
Expected: FAIL (URI doesn't exist).

- [ ] **Step 3: Implement `LobbyWaitingView`**

```dart
// lib/features/session/presentation/widgets/lobby_waiting_view.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LobbyWaitingView extends StatelessWidget {
  const LobbyWaitingView({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.userAccent),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textV2Primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textV2Secondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/session/presentation/lobby_waiting_view_test.dart --reporter compact`
Expected: PASS.

- [ ] **Step 5: Extract `LobbyCategoryGrid`**

Create `lib/features/session/presentation/widgets/lobby_category_grid.dart` by lifting `_buildTypeGrid` / `_iconForWorkout` / `_gradientFor` from `session_invite_acceptance_page.dart` into a stateless widget with the `hostType`/`selected`/`onSelect` interface above. (Copy the existing grid code verbatim, parameterising the three callbacks.)

- [ ] **Step 6: Repoint invite entry points (navigation only — no state mutation)**

Per spec §5.1/§5.2, invite entry **must not** mutate session state — the friend
opens the lobby as a *pending invitee* and joins from there (after choosing a
category). In `lib/features/session/presentation/session_invite_listener.dart`,
the Accept branch only navigates:
```dart
} else if (action == 'Accept' && mounted) {
  context.go(AppRouteLocations.gymSessionSetup(sessionId));
}
```
(`joinSetup` is NOT called here — it is called from the lobby's Join button in
Task 9. Decline still calls `declineInvite` as today.)

In `lib/services/notification_service.dart`, the `session_invite` branch of `_navigateBasedOnData` should push `AppRouteLocations.gymSessionSetup(sessionId)` instead of `sessionAccept`. (Keep the existing "mark invite read" guard.)

In `lib/app/navigation/app_route_locations.dart`, make `sessionAccept` delegate to the setup path so any stragglers land in the lobby:
```dart
  static String sessionAccept(String sessionId) => gymSessionSetup(sessionId);
```

- [ ] **Step 7: Analyze + commit**

```bash
flutter analyze lib/features/session/presentation/widgets/lobby_waiting_view.dart lib/features/session/presentation/widgets/lobby_category_grid.dart lib/features/session/presentation/session_invite_listener.dart lib/services/notification_service.dart lib/app/navigation/app_route_locations.dart
git add lib/features/session/presentation/widgets/lobby_waiting_view.dart lib/features/session/presentation/widgets/lobby_category_grid.dart test/features/session/presentation/lobby_waiting_view_test.dart lib/features/session/presentation/session_invite_listener.dart lib/services/notification_service.dart lib/app/navigation/app_route_locations.dart
git commit -m "feat(session): route invite accept into the setup lobby + waiting/category widgets"
```

---

## Task 8: Lobby role + state model in `GymSessionSetupPage`

**Files:**
- Modify: `lib/features/session/presentation/gym_session_setup_page.dart`
- Test: `test/features/session/presentation/gym_session_setup_page_test.dart` (extend; widget tests with a fake session provider override)

**Interfaces:**
- Consumes: `currentSessionProvider`, `authSessionProvider`, `gymSessionPlanProvider` (host plan), `requiredRoster`/`shouldGoLive` are server-side only — the UI derives display state from the session + plan docs.
- Produces (private to the page): a `_LobbyState` enum and a `_resolveState(session, authUid)` method returning which view to render:
  `hostWaitingForFriend`, `hostBuildingPlan`, `hostWaitingForBuddy`,
  `friendChoosingCategory`, `friendWaitingForHostPlan`, `friendReviewPlan`,
  `friendConfirm`, `selfWaitingForPartner`.

- [ ] **Step 1: Write the failing widget test (host waiting for friend)**

```dart
  testWidgets('host with pending invite can build the plan but ready is disabled', (tester) async {
    // Override currentSessionProvider with a setup session:
    //   hostId == me, participants == [me], partnerKind == realFriend,
    //   partnerId == friend, invitationStatus == 'pending', type == 'gym',
    //   status == active, phase == setup.
    // Override authSessionProvider with me as host.
    // pump GymSessionSetupPage(sessionId: ...)
    // The host builds the plan WHILE the friend decides (invite-first):
    expect(find.byType(GymPlanEditor), findsOneWidget);          // editor visible
    expect(find.text('Waiting for your buddy to join'), findsOneWidget); // ready hint
    // The "I'm ready" button is present but disabled (onPressed == null) because
    // the invited friend has not joined yet.
    final readyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "I'm ready"),
    );
    expect(readyButton.onPressed, isNull);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/session/presentation/gym_session_setup_page_test.dart --reporter compact`
Expected: FAIL (text not found — page currently renders the plan editor unconditionally).

- [ ] **Step 3: Add the state resolver + branch the build**

Add to `_GymSessionSetupPageState`:
```dart
enum _LobbyState {
  terminalCancelled,     // status == cancelled (host cancelled / friend left)
  terminalDeclined,      // invitationStatus == declined (friend declined before joining)
  hostBuildingPlan,      // gym host: editor (ready disabled until friend joins)
  hostNonGymConfirm,     // non-gym host: "I'm ready" (disabled until friend joins)
  hostWaitingForBuddy,   // host is ready; waiting for friend to join/agree
  friendChoosingCategory,
  friendWaitingForHostPlan,
  friendReviewPlan,
  friendConfirm,         // non-gym/different-cat friend: "Ready to start?"
  selfWaitingForPartner,
}

WorkoutType? _friendChosenType; // null until the friend picks in the lobby

// The "I'm ready" action is enabled only once the invited friend has joined
// (solo/matchmaking sessions have no invited friend → always enabled). The gate
// also enforces this server-side; this is the UI mirror. NOTE: the Session model
// has no `invitedUserIds`; the single invited friend is `partnerId` with
// `partnerKind == realFriend` (1:1 invites are enforced by validateOneToOneInvitees).
bool _readyEnabled(Session session) {
  final friend = session.partnerId;
  if (session.partnerKind != PairedPartnerKind.realFriend || friend == null) {
    return true;
  }
  return session.participants.contains(friend);
}

_LobbyState _resolveState(Session session, String uid) {
  final isHost = session.hostId == uid;
  final hostType = WorkoutType.fromString(session.type);

  // Terminal states first — neither side can proceed past these.
  if (session.status == SessionStatus.cancelled) {
    return _LobbyState.terminalCancelled;
  }
  if (session.invitationStatus == WorkoutInvitationStatus.declined) {
    return _LobbyState.terminalDeclined;
  }

  final viewerType =
      WorkoutType.fromString(session.participantTypes[uid] ?? session.type);

  // Matchmaking / non-invite setup sessions reuse this same page but must KEEP
  // the legacy behavior: every participant builds independently and marks ready
  // — no friend handshake, no waiting-for-host, no category step. Friend invites
  // are exactly those with `partnerKind == realFriend` (set by createSession when
  // an invitee is named); matchmaking has no partnerKind. (Spec §9: matchmaking
  // is out of scope — its behavior must not change.)
  if (session.partnerKind != PairedPartnerKind.realFriend) {
    if (_isReady) return _LobbyState.selfWaitingForPartner;
    return viewerType == WorkoutType.gym
        ? _LobbyState.hostBuildingPlan
        : _LobbyState.hostNonGymConfirm;
  }

  if (isHost) {
    if (_isReady) return _LobbyState.hostWaitingForBuddy;
    // Host prepares WHILE the friend decides (invite-first, build-after). The
    // editor / confirm is always available; only the ready button is gated via
    // _readyEnabled(session).
    return hostType == WorkoutType.gym
        ? _LobbyState.hostBuildingPlan
        : _LobbyState.hostNonGymConfirm;
  }

  // Friend — a pending invitee (not yet in participants) stays on the category
  // chooser with a Join button until joinSetup adds them to the roster.
  final joined = session.participants.contains(uid);
  if (!joined) return _LobbyState.friendChoosingCategory;
  final myType =
      WorkoutType.fromString(session.participantTypes[uid] ?? session.type);
  if (_isReady) return _LobbyState.selfWaitingForPartner;
  final sameAsHost = myType == hostType;
  if (sameAsHost && myType == WorkoutType.gym) {
    final hostPlan = ref.watch(gymSessionPlanProvider(
      (sessionId: session.id, userId: session.hostId),
    )).valueOrNull;
    if (hostPlan == null || !hostPlan.isReady) {
      return _LobbyState.friendWaitingForHostPlan;
    }
    return _LobbyState.friendReviewPlan;
  }
  if (myType == WorkoutType.gym) return _LobbyState.hostBuildingPlan; // friend builds own
  return _LobbyState.friendConfirm;
}
```

> Adjust `gymSessionPlanProvider`'s family argument to its real shape (check its
> definition in `session_service.dart`; it is a `family` keyed by session+user).
> If its key differs, match it exactly.

**Init-side-effect guard (spec §4.1):** today's `_loadInitialPlan` calls
`joinSession` + `ensureGymPlan` whenever the viewer isn't a participant. A
*pending invitee* must NOT do that — they only watch the session/host plan and
pick a category until they tap Join. Replace the body of `_loadInitialPlan` so
it early-returns for a non-participant viewer:
```dart
  Future<void> _loadInitialPlan() async {
    final authUser = await ref.read(authSessionProvider.future);
    final session = await ref.read(
      currentSessionProvider(widget.sessionId).future,
    );
    if (!mounted || authUser == null || session == null) {
      if (mounted) setState(() => _isLoadingPlan = false);
      return;
    }
    // Pending invitee (not yet a participant): no joinSession / ensureGymPlan /
    // presence / event / plan-doc writes until joinSetup runs from the lobby.
    if (!session.participants.contains(authUser.id)) {
      if (mounted) setState(() => _isLoadingPlan = false);
      return;
    }
    final plan = await ref.read(sessionServiceProvider).ensureGymPlan(
          sessionId: widget.sessionId,
          hostId: session.hostId,
          userId: authUser.id,
        );
    if (!mounted) return;
    setState(() {
      _draftExercises = _reindexExercises(plan.exercises);
      _isReady = plan.isReady;
      _isLoadingPlan = false;
    });
  }
```

Then, in `build`, after resolving `session`, switch on `_resolveState(session, uid)`:
- `hostBuildingPlan` / `friendReviewPlan` → the existing plan-editor column. The
  host's "I'm ready" button is `onPressed: _readyEnabled(session) ? () => _markReady(session) : null` (disabled + a "Waiting for your buddy to join" hint until the friend joins).
- `friendChoosingCategory` → `LobbyCategoryGrid` + Join/Decline (Task 9).
- `hostNonGymConfirm` / `friendConfirm` → a single "Ready to start?" button calling
  `_confirmReadyNoPlan(session)` (NOT `_markReady`, which requires a gym plan — see below). The host's button respects `_readyEnabled(session)`.
- `hostWaitingForBuddy` → `LobbyWaitingView(title: 'Waiting for your buddy to agree')`.
- `friendWaitingForHostPlan` → `LobbyWaitingView(title: 'Waiting for the host to finish the plan')`.
- `selfWaitingForPartner` → `LobbyWaitingView(title: 'Waiting for your buddy')`.
- `terminalDeclined` → a centered panel: "Your buddy declined" + a "Back to Train"
  button that navigates to the Train tab via the existing pattern
  `context.go(AppRouteLocations.mainTab(<the Train MainShellTab value>))` (the
  session room already uses `AppRouteLocations.mainTab(MainShellTab.feed)` —
  confirm the correct Train enum value); the host can invite someone else there.
- `terminalCancelled` → a centered panel: "This setup was cancelled" + the same
  "Back to Train" button. (A host "Cancel" button in `hostBuildingPlan`/
  `hostNonGymConfirm`/`hostWaitingForBuddy` calls
  `cancelSetup(reason: 'setup_host_cancelled')`; a joined friend's back/leave
  calls `cancelSetup(reason: 'setup_partner_left')`.)

Keep the existing `phase == live` redirect listener — but use the viewer's own type:
```dart
final myType = session.participantTypes[authUser.id] ?? session.type;
context.go(AppRouteLocations.sessionRoom(session.id, type: myType));
```

**Non-gym ready path (Bug fix):** the existing `_markReady` early-returns unless
`_isPlanValid` (≥1 exercise), so it cannot be reused for non-gym/parallel
participants who have no exercises. Add a separate method that writes a ready
stub plan and flips readiness without the exercise requirement:
```dart
  Future<void> _confirmReadyNoPlan(Session session) async {
    if (_isSavingReady) return;
    final authUser = ref.read(authSessionProvider).valueOrNull;
    if (authUser == null) return;
    setState(() => _isSavingReady = true);
    final svc = ref.read(sessionServiceProvider);
    final myType = WorkoutType.fromString(
      session.participantTypes[authUser.id] ?? session.type,
    );
    try {
      await svc.saveGymPlan(
        sessionId: widget.sessionId,
        plan: GymSessionPlan.defaultPersonalPlan(
          userId: authUser.id,
          workoutType: myType,
        ), // ready stub, no exercises required for non-gym/parallel
      );
      await svc.setGymPlanReady(
        sessionId: widget.sessionId,
        userId: authUser.id,
        isReady: true,
      );
      if (mounted) setState(() { _isReady = true; _isSavingReady = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingReady = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unable to confirm: $error'),
        backgroundColor: AppColors.error,
      ));
    }
  }
```
> Confirm `GymSessionPlan.defaultPersonalPlan(...)` yields `isReady: true` (the
> old `acceptInvite` used it as a "mark ready immediately" stub). If it defaults
> to not-ready, set `isReady: true` explicitly.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/session/presentation/gym_session_setup_page_test.dart --reporter compact`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/features/session/presentation/gym_session_setup_page.dart
git add lib/features/session/presentation/gym_session_setup_page.dart test/features/session/presentation/gym_session_setup_page_test.dart
git commit -m "feat(session): role/state-aware setup lobby"
```

---

## Task 9: Friend category choice + agree/edit wiring

**Files:**
- Modify: `lib/features/session/presentation/gym_session_setup_page.dart`
- Test: `test/features/session/presentation/gym_session_setup_page_test.dart`

**Interfaces:**
- Consumes: `LobbyCategoryGrid` (Task 7); `joinSetup` (Task 4) records the
  friend's category at join time.
- Produces: `_onFriendPickCategory(WorkoutType)` (local selection only, while
  pending), `_onJoinSetup(Session)` (the Join button → `joinSetup`),
  `_onAgreeHostPlan(Session)`, plus reuse of existing `_markReady`. Optional
  `saveFriendType` for a post-join category change.

- [ ] **Step 1: Write the failing test (pending friend joins, then sees confirm/review)**

```dart
  testWidgets('pending friend picks category and Join calls joinSetup', (tester) async {
    // session: hostId=host, type='gym', participants=[host] (friend NOT yet in),
    //   partnerKind=realFriend, partnerId=me, invitationStatus='pending',
    //   status=active, phase=setup
    // me = pending invitee; pump page → category grid + Join visible.
    // Tap 'Running' tile, then 'Join' → verify sessionService.joinSetup called
    // with chosenWorkoutType == 'running' (use a mock SessionService override).
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/session/presentation/gym_session_setup_page_test.dart --reporter compact`
Expected: FAIL.

- [ ] **Step 3: Implement the handlers**

```dart
  // Pending invitee: pick category locally; nothing is written until Join.
  void _onFriendPickCategory(WorkoutType type) {
    setState(() => _friendChosenType = type);
  }

  // Join button (pending invitee only): joins setup with the chosen category.
  Future<void> _onJoinSetup(Session session) async {
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    final type = _friendChosenType ?? WorkoutType.fromString(session.type);
    if (uid == null) return;
    try {
      final svc = ref.read(sessionServiceProvider);
      await svc.joinSetup(
        sessionId: session.id,
        userId: uid,
        chosenWorkoutType: type.value,
      );
      // The pending invitee did NOT run _loadInitialPlan (it early-returns for
      // non-participants), and it won't re-run on this pending→joined rebuild.
      // Load the freshly-seeded plan now so the Edit path / readiness reflect
      // the stub instead of opening an empty editor.
      final plan = await svc.ensureGymPlan(
        sessionId: session.id,
        hostId: session.hostId,
        userId: uid,
      );
      if (mounted) {
        setState(() {
          _draftExercises = _reindexExercises(plan.exercises);
          _isReady = plan.isReady; // false — joinSetup wrote a not-ready stub
          _isLoadingPlan = false;
        });
      }
      // The stream rebuild also moves us out of the pending "choose category"
      // state automatically (we are now in participants).
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not join: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _onAgreeHostPlan(Session session) async {
    final hostPlan = ref.read(gymSessionPlanProvider(
      (sessionId: session.id, userId: session.hostId),
    )).valueOrNull;
    if (hostPlan == null) return;
    setState(() => _draftExercises = _reindexExercises(hostPlan.exercises));
    await _markReady(session); // writes own copy + setGymPlanReady
  }
```

Wire `LobbyCategoryGrid.onSelect` → `_onFriendPickCategory`. In the
`friendChoosingCategory` state (pending invitee), render the grid plus a **Join**
button (`_onJoinSetup`, enabled once `_friendChosenType != null`) and a
**Decline** button (`declineInvite`). In `friendReviewPlan` render the editor
with **Agree** (`_onAgreeHostPlan`) and **Edit** (enable editing then
`_markReady`). In `friendConfirm`, render a single "Ready to start?" button →
`_markReady`.

> A post-join category change is out of scope for the happy path; if added
> later, `saveFriendType(sessionId, userId, type.value)` updates only the
> caller's `participantTypes` key (allowed by the Task 6 rule).

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/session/presentation/gym_session_setup_page_test.dart --reporter compact`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/features/session/presentation/gym_session_setup_page.dart
git add lib/features/session/presentation/gym_session_setup_page.dart test/features/session/presentation/gym_session_setup_page_test.dart
git commit -m "feat(session): pending-invitee category choice, Join, and agree/edit in lobby"
```

---

## Task 10: Host entry — friend-invite skips the pre-invite builder

**Files:**
- Modify: `lib/features/session/presentation/start_session_page.dart` (`_handleStartSession` / `_handleStartSessionWithPlan`)
- Test: `test/features/session/presentation/start_session_page_test.dart` (add a focused test; note the 9 pre-existing failures here are unrelated partner-mode-UI tests)

**Interfaces:**
- Consumes: `createSession(phase: SessionPhase.setup, invitedUserIds: [...])`, `AppRouteLocations.gymSessionSetup`.
- Produces: when `_partnerMode == 'friends'` with a selected friend, the host creates a **setup** session (no pre-invite plan) and routes to the lobby; solo/bot/random unchanged.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('selecting a friend routes the host to the setup lobby', (tester) async {
    // Pump StartSessionPage with a mutual follow available and gym selected;
    // select the buddy (sets _partnerMode='friends'); trigger start.
    // Expect navigation to '/session/setup/<id>' (lobby), NOT the plan builder.
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/session/presentation/start_session_page_test.dart --reporter compact --plain-name "routes the host to the setup lobby"`
Expected: FAIL.

- [ ] **Step 3a: Add a dedicated friend-invite starter**

Add this method to `_StartSessionPageState` (it works for gym AND non-gym — the
plan is built later in the lobby, so there is no pre-invite plan builder):
```dart
  Future<void> _handleStartFriendInvite(WorkoutType type) async {
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    if (uid == null || _selectedFriends.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final sessionService = ref.read(sessionServiceProvider);
      final existing = await sessionService.checkActiveSession(uid);
      if (existing != null) {
        // reuse the existing active-session sheet path (resume/end) here
        setState(() => _isLoading = false);
        return;
      }
      final sessionId = await sessionService.createSession(
        hostId: uid,
        type: type.value,
        title: '${type.displayName} Session',
        invitedUserIds: _selectedFriends.toList(),
        phase: SessionPhase.setup,
      );
      await HapticFeedback.mediumImpact();
      if (mounted) context.push(AppRouteLocations.gymSessionSetup(sessionId));
    } catch (e) {
      if (mounted) {
        _showError(_mapStartSessionError(e));
        await HapticFeedback.vibrate();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
```

- [ ] **Step 3b: Route friend-invites to it BEFORE the gym→plan-builder branch**

In the FAB trigger `ref.listen<int>(sessionStartTriggerProvider, ...)` inside
`build`, the current logic sends gym to `_navigateToPlanView()`. Add a
friend-invite check **first** so friend-invites (gym or not) skip the pre-invite
builder:
```dart
    ref.listen<int>(sessionStartTriggerProvider, (_, _) {
      if (_isLoading) return;
      final isFriendInvite =
          _partnerMode == 'friends' && _selectedFriends.isNotEmpty;
      if (_view == 'plan') {
        HapticManager.heavy();
        _handleStartSessionWithPlan();
      } else if (isFriendInvite && _selectedType != null) {
        HapticManager.medium();
        _handleStartFriendInvite(_selectedType!);
      } else if (_selectedType != null) {
        HapticManager.medium();
        if (_selectedType == WorkoutType.gym) {
          _navigateToPlanView();
        } else {
          _handleStartSession();
        }
      }
    });
```
(Solo gym still goes to `_navigateToPlanView`; solo non-gym still
`_handleStartSession`; bot/random unchanged.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/session/presentation/start_session_page_test.dart --reporter compact --plain-name "routes the host to the setup lobby"`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/features/session/presentation/start_session_page.dart
git add lib/features/session/presentation/start_session_page.dart test/features/session/presentation/start_session_page_test.dart
git commit -m "feat(session): friend invites create a setup session and open the lobby"
```

---

## Task 11: Retire `SessionInviteAcceptancePage`

**Files:**
- Delete: `lib/features/session/presentation/session_invite_acceptance_page.dart`
- Delete: `test/features/session/presentation/session_invite_acceptance_page_test.dart`
- Modify: `lib/app/navigation/app_router.dart` (remove the `sessionAccept` GoRoute + import), `lib/services/session_service.dart` (remove now-unused `acceptInvite` once nothing references it)

**Interfaces:**
- Consumes: nothing new. Confirms no references remain to the deleted page or `acceptInvite`.

- [ ] **Step 1: Find references**

Run: `grep -rn "SessionInviteAcceptancePage\|acceptInvite" lib test`
Expected: only the acceptance page, its route, and (until now) `acceptInvite` definition/test.

- [ ] **Step 2: Remove the route**

In `lib/app/navigation/app_router.dart`, delete the `GoRoute(path: AppRoutes.sessionAccept, ...)` block (lines ~394-408) and the `SessionInviteAcceptancePage` import.

- [ ] **Step 3: Delete the page, its test, and `acceptInvite`**

```bash
git rm lib/features/session/presentation/session_invite_acceptance_page.dart
git rm test/features/session/presentation/session_invite_acceptance_page_test.dart
```
Then remove the `acceptInvite` method from `session_service.dart` (its expiry/eligibility logic now lives in `joinSetup`; its readiness logic in the lobby `_markReady` → `setGymPlanReady`).

- [ ] **Step 4: Analyze + full session test pass**

Run: `flutter analyze lib`
Expected: "No issues found!" (no dangling references).

Run: `flutter test test/services/session_service_test.dart test/services/session_lobby_gate_test.dart test/firebase/firestore_rules_contract_test.dart test/features/session/presentation/gym_session_setup_page_test.dart --reporter compact`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(session): retire SessionInviteAcceptancePage in favour of the lobby"
```

---

## Task 12: Deploy backend

**Files:** none (deploy only)

- [ ] **Step 1: Deploy rules + (no function change this plan)**

Run: `firebase deploy --only firestore:rules`
Expected: "released rules ... Deploy complete!"

> No Cloud Function or index changes in this plan — the go-live gate and lobby
> are all client + rules. `pairedInviteTimeout` ships with the app build.

- [ ] **Step 2: Smoke test (manual)**

Two accounts that mutually follow:
1. Host picks Gym + buddy → lands in lobby (empty plan), sees "Waiting for your buddy to join".
2. Friend gets push within 10 min, accepts → lands in lobby.
3. Host builds plan, taps Ready → host sees "Waiting for buddy to agree".
4. Friend sees the host's plan → Agree → both auto-enter the live room together.
5. Repeat with friend choosing a different category → friend sees confirm, both still gate to live together.

---

## Self-review (completed)

- **Spec coverage:** §2 reqs 1-7 → Tasks 1 (timeout), 4 (join), 8-9 (UI/category/agree-edit), 3 (gate), 10 (host entry); §4.1 init-side-effect guard → Task 8; §5.1 invite entry is navigation-only → Task 7; §5.2 timeout → Task 1; §5.3 rules (own-key types + active/setup-scoped accept) → Task 6; §6 cancel-with-audit (host cancel + friend leave) → Task 5; §4.1 evolve setup page → Tasks 8-9; retire acceptance page → Task 11.
- **Flow consistency (refined spec):** the friend opens the lobby as a *pending invitee*; `joinSetup` fires from the lobby Join button (Task 9), not on Accept (Task 7); the init guard (Task 8) blocks plan/presence/event writes until joined; `_resolveState` keeps a non-participant on the category chooser.
- **Logic-review fixes (this pass):**
  1. *Matchmaking go-live regression* — the gate now requires the invited roster to have **joined** AND **every current participant** to be ready (matchmaking partners are added via `joinSession` and aren't in `invitedUserIds`); Task 2 helper + tests and Task 3 readiness loop both iterate `participants`.
  2. *Non-gym readiness was impossible* — `_markReady` requires `_isPlanValid` (≥1 exercise); added `_confirmReadyNoPlan` for non-gym/parallel ready (host + friend).
  3. *Host could not build the plan while the friend was pending* — resolver now shows the editor/confirm to the host immediately and only disables the "I'm ready" action (`_readyEnabled`) until the friend joins.
  4. *No terminal states* — added `terminalDeclined`/`terminalCancelled` so a decline/cancel doesn't strand either side on a screen that can never go live.
- **Logic-review fixes (second pass):**
  5. *Matchmaking inherited the friend handshake* — the lobby is the same page matchmaking uses; `_resolveState` now short-circuits to the legacy independent-build behavior when `partnerKind != realFriend`, so matchmaking is unchanged (spec §9).
  6. *Friend's plan not loaded after join* — the pending invitee skips `_loadInitialPlan`, which doesn't re-run on pending→joined; `_onJoinSetup` now loads the seeded plan after `joinSetup` so the Edit path isn't empty.
  7. *`Session.invitedUserIds` doesn't exist (compile error)* — the model exposes `partnerId` (the single invited friend) + `partnerKind == realFriend`; the UI uses those. The backend gate still reads raw `invitedUserIds` from the doc (not the model), which is correct.
- **Placeholder scan:** the "adjust to the real family key" note (Task 8) is an explicit verification step against a named symbol, not a vague TODO.
- **Type consistency:** `requiredRoster`/`shouldGoLive` match between Task 2 (def) and Task 3 (use); `joinSetup(sessionId,userId,chosenWorkoutType)` and `cancelSetup(sessionId,byUserId,reason)` match between definition (Tasks 4, 5) and call sites (Tasks 7-10); `leaveSetup` was folded into `cancelSetup`; `saveFriendType` is optional/out-of-scope.

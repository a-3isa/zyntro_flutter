---

description: "Task list for 007-resume-active-session"
---

# Tasks: Resume Active Session on App Re-entry

**Input**: Design documents from `/specs/007-resume-active-session/`
**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: Included. Constitution II requires regression evidence for primary and critical failure
paths before cutover, and Constitution IV requires a tested rollback path.

**Organization**: Grouped by user story so each ships and demos independently.

**Revision**: Regenerated 2026-08-05 after cross-artifact analysis. All constitution-mandated
pre-cutover gates were previously scheduled in the final polish phase — after cutover — and have been
moved into the phases they gate. Coverage added for FR-005, FR-006, FR-008d, FR-010a, SC-002 and
SC-014.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 / US2 / US3, mapping to the prioritized stories in spec.md
- Exact file paths in every task

## Path Conventions

Flutter app at repo root: `lib/`, `test/`. Firebase side: `functions/`, `firebase/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Configuration and scaffolding needed by everything that follows

- [X] T001 [P] Add two composite indexes to `firebase/firestore.indexes.json`: `sessions` on participants (array-contains) + status + phase + lastActivityAt (desc) for the resume lookup, and `sessions` on status + expiresAt (asc) for the expiry sweep, per data-model.md § Indexes
- [X] T002 Create the `config/featureFlags` Firestore document with `resumeActiveSessionEnabled: true`, and add `resumeActiveSessionEnabledProvider` to `lib/core/constants/feature_flags.dart` reading it once at startup, mirroring the existing `pairedFriendSessionsEnabledProvider` shape at line 56-58. Fall back to a compile-time default when the document is missing, unreadable or offline; never block startup (FR-023, research R10)
- [X] T003 [P] Add analytics event name constants for `session_resume_redirect`, `session_resume_prompt_shown`, `session_resume_prompt_answered`, `session_partner_left_choice`, `session_expired_swept`, `session_resume_error` alongside the existing analytics constants (FR-024)

> [!warning] Do not put the flag in `app_runtime_config.dart` or as a `static bool get`
> Both are compile-time. `firebase_remote_config` is not a dependency of this project. A flag in
> either place would need an app store release to flip, which is not a rollback path (research R10).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Session lifecycle changes every user story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

**⚠️ SAFETY**: T009 and T010 remove the only mechanisms that currently close sessions. They MUST NOT
be merged before T006 (the expiry Function) is deployed, or live sessions leak with nothing to close
them. Keep them in the same PR.

**⚠️ CONSTITUTION II**: T009 and T010 are legacy removal. Constitution II permits removal only after
cutover evidence is accepted, and they cannot be deferred past T006. The resolution is a **merge
gate**: this branch does not merge until US1's evidence (T020, T021) is green, so removal and
evidence arrive together. See plan.md § Post-analysis re-check.

### Data model

- [X] T004 Add `lastActivityAt`, `lastOccupiedAt`, `expiresAt` (all timestamps) and `endedParticipants` (string list) to the `Session` model in `lib/core/models/models.dart`, including `fromFirestore`/`toMap` handling, treating a missing `expiresAt` as expired per data-model.md
- [X] T005 Stamp `lastActivityAt` and recompute `expiresAt = now + 3h` on every existing session state write in `lib/services/session_service.dart` — set logged, turn passed, plan committed, invite accepted — per contracts/session-lifecycle.md §2.3. Viewing must NOT stamp activity (FR-007a). This is also what keeps a solo-continuing session alive (FR-022)

### Server-side expiry

- [X] T006 Add the `expireStaleSessions` scheduled Function to `functions/index.js`, modelled on `expireStalePairedInvites` at line 671: `onSchedule("every 15 minutes")`, query `status == 'active'` + `expiresAt < now`, limit 400, batch-update to `status: 'completed'` with `endedReason: 'expired'` and `endedAt`. Use `doc.ref`, never `doc.reference`. Log the swept count (FR-007, A-009)

### Security (Constitution III — verified in this phase, not deferred)

- [X] T007 Add an `isOwnTerminationUpdate()` predicate to `firebase/firestore.rules` under `match /sessions/{sessionId}`, allowing a participant to append only their own uid to `endedParticipants` and to touch no field outside `{endedParticipants, lastActivityAt, expiresAt}`. Add a `match /config/{doc}` rule making the flag document world-readable and client-write-denied (FR-008, FR-011, FR-023, Constitution III)
- [X] T008 Verify T007 with the Firestore emulator: a participant can append only their own uid to `endedParticipants`, cannot append another member's, cannot touch other fields in the same write, and no client can write `config/featureFlags`. **Constitution III requires this before cutover — do not defer to polish**

### Removing the current termination paths

- [X] T009 Remove the `endSession` call from the `detached`/`hidden` branch of `didChangeAppLifecycleState` in `lib/features/session/presentation/session_room_page.dart:516-523`, keeping `presenceService.setAway` (research R1)
- [X] T010 Remove `_inactivityTimer`, `_inactivityLimit` and `_terminateSessionInactive` from `lib/features/session/presentation/session_room_page.dart:103-104, 482-496` and every call site, leaving the scheduled Function as the sole expiry authority (research R2)

### Presence

- [X] T011 Add `isPresenceLive(UserPresence, DateTime now)` to `lib/services/presence_service.dart` — true only when status is online AND `now - lastChanged < 90s` — because a force-killed app leaves `online` written forever (FR-021, research R6)
- [X] T012 Add `startHeartbeat(sessionId, userId)` to `lib/services/presence_service.dart` on a 60s tick, refreshing presence `lastChanged` and bumping the session's `lastOccupiedAt` and `expiresAt`; start it on session-room mount and cancel it in `dispose` in `lib/features/session/presentation/session_room_page.dart` (FR-021)

### Foundational tests

- [X] T013 [P] Unit-test the expiry rule in `test/services/session_expiry_test.dart`: `expiresAt` derived from the later of activity and occupancy, a missing `expiresAt` treated as expired, viewing not resetting the activity clock, and solo work keeping a session alive past 3 hours from start (FR-022, SC-010)
- [X] T014 [P] Unit-test `isPresenceLive` in `test/services/presence_service_test.dart`: fresh online is live, online with `lastChanged` older than 90s is not, away and offline are not (FR-021)

**Checkpoint**: Sessions survive app close, expire server-side, and the rules are verified. User story work can begin.

---

## Phase 3: User Story 1 — Return to a live workout after leaving the app (Priority: P1) 🎯 MVP

**Goal**: A member who force-closes the app mid-workout lands straight back in their live session on
the next cold start, with everything they logged intact.

**Independent Test**: Start a session, log a set, swipe the app out of recents, reopen — the member
arrives on the live session screen with the set intact and no prompt.

### Tests for User Story 1

> Write these first; they must fail before implementation.

- [X] T015 [P] [US1] Unit-test `resolveResumeDecision` in `test/features/session/domain/resume_decision_test.dart` covering all eight rules plus every boundary in contracts/resume-decision.md § Test matrix: deep link beats warm session, terminated beats expired, partner present makes a quiet session warm, activity exactly 15 min ago is a prompt, `now` exactly `expiresAt` is expired, null `expiresAt` is expired, a setup-phase session yields none, a completed session yields none (there is no recap phase to test — `SessionPhase` is `{setup, live}`), unresolved launch intent yields none, kill switch off yields none under every other input (FR-002, FR-002a, FR-002b, FR-009, SC-005, SC-006)
- [X] T016 [P] [US1] Widget-test the router redirect in `test/features/session/presentation/resume_redirect_test.dart`: a warm session redirects to the session room instead of main across force-close, OS-kill and device-restart starts; no intermediate main-screen frame is rendered; an unauthenticated or onboarding-incomplete member is never redirected (FR-011, FR-015, SC-001)
- [X] T017 [P] [US1] Test that recorded work survives a cold start in `test/features/session/presentation/resume_preserves_work_test.dart`: 10 logged sets are all present after restart, none duplicated or re-counted (FR-005, SC-003)
- [X] T018 [P] [US1] Test the launch-intent guard in `test/features/session/presentation/launch_intent_test.dart`: a cold start carrying a notification payload produces no resume redirect, and an unresolved launch intent also produces none (FR-010, FR-010a, SC-012)
- [X] T019 [P] [US1] Assert the startup budget in `test/features/session/presentation/resume_timing_test.dart`: from app-start timestamp to the first frame of the session screen is under 2 seconds on a warm session (SC-002)

### Implementation for User Story 1

- [X] T020 [P] [US1] Create the `ResumeDecision` sealed class (`ResumeNone`, `ResumeRedirect`, `ResumePrompt`, `ResumeExpiredNotice`), the `ResumeCandidate` input type, and the pure `resolveResumeDecision` function in `lib/features/session/domain/resume_decision.dart`, exactly per contracts/resume-decision.md — `now` injected, never read internally, total over all inputs
- [X] T021 [US1] Implement `findResumableSession(String userId)` in `lib/services/session_service.dart`: participants array-contains + `status == 'active'` + `phase == 'live'`, ordered by `lastActivityAt` desc, limit 1; filter out candidates whose `endedParticipants` contains the member; attach presence with the T011 staleness rule; return null on any error rather than throwing into startup (FR-002, FR-002a, FR-002b, FR-009, FR-014, FR-016)
- [X] T022 [US1] Capture launch intent in `lib/services/notification_service.dart` at the existing `getInitialMessage()` call (line 355-363): record whether a payload was present into a `launchIntentProvider` **before** `runApp()`, leaving the existing post-frame navigation unchanged. Default to `true` (skip redirect) if it cannot be resolved (FR-010a, research R11, contracts/session-lifecycle.md §8)
- [X] T023 [US1] Add a one-shot `resumeDecisionProvider` resolved during the existing splash hold in `lib/app/navigation/app_router.dart`, latched like `startupProfileCheckDone` (lines 223-244) so it computes once per cold start and never on `refreshListenable` ticks (FR-001, FR-001a)
- [X] T024 [US1] Branch on the latched decision inside the `isProfileComplete` block of the redirect at `lib/app/navigation/app_router.dart:302-306`: `ResumeRedirect` returns `AppRouteLocations.sessionRoom(sessionId, type:)`, everything else falls through to `AppRoutes.main` (FR-003, FR-015)
- [X] T025 [US1] Feed `resumeActiveSessionEnabledProvider` (T002) and `launchIntentProvider` (T022) into `resolveResumeDecision` so that with the flag off it returns `ResumeNone` for every input (FR-023)
- [X] T026 [US1] Emit `session_resume_redirect` on a successful redirect and `session_resume_error` on the FR-016 fallback path

### Pre-cutover gates for User Story 1 (Constitution IV)

> [!important] These gate the MVP ship. They are not polish.
> Constitution IV requires a tested rollback path and active telemetry **before** cutover.

- [X] T027 [US1] Rehearse the rollback: set `config/featureFlags.resumeActiveSessionEnabled` to false in the Firebase console, confirm the app returns to pre-feature redirect behaviour with no new build, and confirm `expireStaleSessions` still runs with the flag off (FR-023, FR-023a, SC-013)
- [X] T028 [US1] Confirm `session_resume_redirect` and `session_resume_error` fire with correct payloads, and wire the error counter to the rollback trigger (FR-024)

**Checkpoint**: The reported problem is fixed, rollback is proven, telemetry is live. US1 is shippable.

---

## Phase 4: User Story 2 — Return to the correct place in a shared session (Priority: P2)

**Goal**: Neither partner is punished when one closes the app. The one who stayed keeps training with
no waiting screen; the one who left returns to the role and view that is correct right now.

**Independent Test**: Two-member turn-based session; close one app; the other finishes a turn and
continues straight into the next set with no waiting state; reopen the first app and it lands in the
correct view with the solo work visible.

### Tests for User Story 2

- [X] T029 [P] [US2] Unit-test `canHoldTurn` in `test/features/session/domain/turn_eligibility_test.dart`: a terminated member never qualifies, an away member does not qualify while stale, a present member does, and turn handover skips non-qualifying members (FR-017)
- [X] T030 [P] [US2] Widget-test the solo override in `test/features/session/presentation/solo_when_partner_away_test.dart`: `WaitingTurnScreen` is never rendered when every other participant is away, 10 consecutive sets can be logged, and the shared view returns as soon as presence recovers (FR-018, FR-019, SC-008)
- [X] T031 [P] [US2] Test live partner progress in `test/features/session/presentation/partner_progress_test.dart`: work a partner logged while the member was away is visible on return with no manual refresh, and solo work is visible to the returning partner (FR-006, SC-009)

### Implementation for User Story 2

- [X] T032 [US2] Add the `canHoldTurn(userId)` predicate — not in `endedParticipants` AND `isPresenceLive` — to `lib/features/session/domain/turn_eligibility.dart` (contracts/session-lifecycle.md §2.6)
- [X] T033 [US2] Route turn handover through `canHoldTurn` in `lib/services/session_service.dart:1345` (`'activeUserId': nextUserId`): skip participants who fail it, and when nobody qualifies leave `activeUserId` unchanged rather than clearing it (FR-017)
- [X] T034 [US2] Add a presence check ahead of the `derivedMode` dispatch in `lib/features/session/presentation/session_room_page.dart`: when every other participant fails `canHoldTurn`, render the solo view regardless of `derivedMode`, never `WaitingTurnScreen`. Presentation-layer override only — do not mutate `derivedMode` (FR-018, FR-019)
- [X] T035 [US2] Add asymmetric flicker damping to the shared↔solo transition in `lib/features/session/presentation/session_room_page.dart`: delay shared → solo by a 30-second grace period on top of the 90-second presence timeout, apply solo → shared immediately (FR-021a)
- [X] T036 [US2] Guard against the view switching mid-set: a returning partner resumes turn order at the next handover and never seizes a set in progress (spec Edge Cases)
- [X] T037 [US2] Add the "away" avatar treatment — visually distinct from the "left" treatment added in T048 — in `lib/features/session/presentation/widgets/waiting_turn_screen.dart`, `parallel_gym_view.dart` and `parallel_cardio_view.dart` (FR-020)
- [X] T038 [US2] Verify `SessionRoomPage` resolves `derivedMode` and `activeUserId` from live session state at mount, so a turn that changed while the member was away lands them in the right view (FR-004, SC-004)

**Checkpoint**: US1 and US2 both work independently. Neither partner is blocked by the other.

---

## Phase 5: User Story 3 — Not being dragged into a session that is over (Priority: P3)

**Goal**: Quiet sessions ask before pulling a member back in, expired sessions are explained, and a
partner leaving is communicated without ending anyone else's workout.

**Independent Test**: Return after 40 minutes to a quiet session and get asked rather than redirected;
return after 3 hours and find the session ended with a clear explanation; have a partner terminate
and confirm the remaining member is told, offered a choice, and never force-ended.

### Tests for User Story 3

- [X] T039 [P] [US3] Widget-test the quiet prompt in `test/features/session/presentation/resume_prompt_test.dart`: shown for a quiet in-window session, continue enters the session, discard terminates only this member, ignoring it blocks nothing and it does not reappear until the next cold start, and a session going warm while the prompt shows does not swap it for a redirect (FR-003a, FR-003b, spec Edge Cases)
- [X] T040 [P] [US3] Unit-test `terminateForMember` in `test/services/terminate_for_member_test.dart`: one member of two leaves and the session stays `active`, the last member leaving delegates to `endSession`, the notification is written once per departure, and the turn is handed over if the leaver held it (FR-008, FR-008b-ii, SC-007)
- [X] T041 [P] [US3] Widget-test the partner-left dialog in `test/features/session/presentation/partner_left_dialog_test.dart`: appears once per departure, dismiss equals carry-on and never ends the session, does not reappear on stream re-emit or on returning later, and the "left" avatar style persists after dismissal (FR-008e, FR-008f, FR-008g, SC-007)

### Quiet-session prompt

- [X] T042 [P] [US3] Create the continue-or-discard prompt in `lib/features/session/presentation/widgets/resume_session_prompt.dart` and wire it to the `ResumePrompt` decision on the landing screen — not in the router redirect (FR-003a, FR-003b)
- [X] T043 [US3] Implement the discard branch to call `terminateForMember` and leave the member on the home screen; ensure ignoring the prompt never blocks the rest of the app and it is not re-shown until the next cold start (FR-003b)

### Per-member termination

- [X] T044 [US3] Implement `terminateForMember(sessionId, userId)` in `lib/services/session_service.dart`: `arrayUnion` the uid into `endedParticipants`, write a `leave` event, hand over the turn if the leaver held it, and delegate to the existing `endSession` only when `endedParticipants` covers all `participants` — leaving scoring, streaks and workout logging unchanged for the last member out (FR-008, research R3)

### Partner-left communication

- [X] T045 [P] [US3] Add a `partnerLeft` case with value `partner_left` to the `NotificationType` enum and its extension in `lib/services/notification_service.dart:27-46`, following the existing `sessionInvite` shape (FR-008a, FR-008b)
- [X] T046 [US3] Write the stored partner-left notification from `terminateForMember` for each remaining participant, keyed `partner_left_<sessionId>_<leaverId>` so retries and repeated app opens cannot stack duplicates; payload carries `sessionId` and the leaver's display name; mark it read once the member has seen it (FR-008b-i, FR-008b-ii)
- [X] T047 [US3] Add a `partner_left` branch to `_navigateBasedOnData` in `lib/services/notification_service.dart:436`, routing to the session room, so tapping the notification takes the member to the session (FR-008d)
- [X] T048 [US3] Create the in-room departure dialog in `lib/features/session/presentation/widgets/partner_left_dialog.dart`: fires when `endedParticipants` gains an entry while the member has the room open, offers finish-too or carry-on, dismissable, dismiss equals carry on (FR-008a, FR-008e)
- [X] T049 [US3] Track acknowledged departures by leaver id in `SessionRoomPage` state so the dialog raises once per departure and survives stream re-emits and rebuilds without reappearing (FR-008g)
- [X] T050 [US3] Add the "left" avatar treatment — dimmed and desaturated with a clear left indicator, avatar still visible, glow animation stopped — in `lib/features/session/presentation/widgets/waiting_turn_screen.dart`, `parallel_gym_view.dart`, `parallel_cardio_view.dart` and `session_room_page.dart`. Coordinate with T037; both edit the same three widget files (FR-008f)
- [X] T051 [US3] Render the finish-or-continue choice from `endedParticipants` on the session document, never from notification receipt, so a member who missed or dismissed the notification still gets the choice on return (FR-008c)

### Session-ended notice

- [X] T052 [US3] Build one session-ended notice component on the landing screen covering all three reasons — expired, cancelled, member removed — driven by the `ResumeExpiredNotice` decision and the equivalent cancelled/removed cases, and confirm recorded work is preserved in each (FR-007b, FR-013)

### Telemetry

- [X] T053 [US3] Emit `session_resume_prompt_shown`, `session_resume_prompt_answered` (continue/discard), `session_partner_left_choice` (finish-too/carry-on) and `session_expired_swept`, and confirm all four fire with correct payloads (FR-024)

**Checkpoint**: All three stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T054 **BLOCKED — needs a physical handset.** Run every scenario in [quickstart.md](./quickstart.md) § Verify it works on a real device, including the force-close, quiet-return, expiry, partner-left and partner-away paths. Cannot be automated: the core case is swiping the app out of the recent-apps list, which no emulator or widget test reproduces faithfully. Every behaviour it checks has automated coverage (988 Flutter tests, 90 rules tests); this is the manual pre-release pass, and the last gate before cutover
- [X] T055 [P] Confirm offline cold start resumes from cache and that pending work is marked, coordinating with `006-offline-cache-sync`; if that branch has not merged, record the missing badge as a known gap (FR-012, SC-011, research R8)
- [X] T056 [P] Instrument the session-abandonment funnel — sessions started versus sessions completed — and capture a pre-release baseline, so the post-launch metric SC-014 can actually be measured
- [X] T057 Run `flutter analyze` and the full `flutter test` suite; confirm no regressions in the existing `test/features/session/` suites
- [X] T058 Update `specs/007-resume-active-session/checklists/requirements.md` with final validation status

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies, start immediately
- **Foundational (Phase 2)**: depends on Setup — **BLOCKS all user stories**
- **US1 (Phase 3)**: depends on Foundational only
- **US2 (Phase 4)**: depends on Foundational; independent of US1
- **US3 (Phase 5)**: depends on Foundational; independent of US1 and US2
- **Polish (Phase 6)**: depends on all shipped stories

### Hard ordering inside Phase 2

```
T004 → T005 → T006 → T009, T010
                └──► T007 → T008
```

T009 and T010 remove the only paths that close sessions. They must land with T006, never before it.
T008 verifies T007 in-phase because Constitution III requires authz regression evidence before
cutover.

### Merge gate (Constitution II)

The branch does not merge until **T020 and T021** are green. T009/T010 are legacy removal, and
Constitution II permits removal only alongside accepted cutover evidence.

### Cross-story notes

- US2's `canHoldTurn` (T032) and US3's `terminateForMember` (T044) both read `endedParticipants` from
  T004. Neither depends on the other's behaviour.
- **T037 and T050 edit the same three widget files** (`waiting_turn_screen.dart`,
  `parallel_gym_view.dart`, `parallel_cardio_view.dart`). Neither is marked `[P]`. Whoever lands
  second rebases; the two treatments must end up visually distinct (FR-020).

### Parallel opportunities

- T001, T003 — Setup (T002 is not parallel; T025 depends on it)
- T013, T014 — foundational tests
- T015, T016, T017, T018, T019 — all US1 tests
- T029, T030, T031 — all US2 tests
- T039, T040, T041 — all US3 tests
- T042, T045 — different files, no shared state
- T055, T056 — polish

---

## Parallel Example: User Story 1

```bash
# All five tests first, in parallel:
Task: "Unit-test resolveResumeDecision in test/features/session/domain/resume_decision_test.dart"
Task: "Widget-test the router redirect in test/features/session/presentation/resume_redirect_test.dart"
Task: "Test work preservation in test/features/session/presentation/resume_preserves_work_test.dart"
Task: "Test the launch-intent guard in test/features/session/presentation/launch_intent_test.dart"
Task: "Assert the startup budget in test/features/session/presentation/resume_timing_test.dart"

# Then T020 (pure domain file) proceeds while T021 is written against session_service.dart
Task: "Create ResumeDecision and resolveResumeDecision in lib/features/session/domain/resume_decision.dart"
```

---

## Implementation Strategy

### MVP first (User Story 1 only)

1. Phase 1 Setup
2. Phase 2 Foundational — **critical, blocks everything; T006 must land with T009/T010**
3. Phase 3 US1, **including T027 and T028** — the rollback rehearsal and telemetry verification are
   ship gates, not polish
4. **STOP and VALIDATE**: force-close mid-session, reopen, confirm the member lands back in the
   session with their work intact
5. Ship — this alone fixes the reported problem

### Incremental delivery

1. Setup + Foundational → sessions survive app close and expire on their own
2. + US1 → force-close and reopen returns the member to their workout (**MVP**)
3. + US2 → neither partner is blocked when the other closes the app
4. + US3 → quiet sessions ask first, expired sessions explain themselves, partner departures are
   communicated without ending anyone's workout

### Parallel team strategy

After Foundational: one developer per story. US1, US2 and US3 touch mostly separate files — the
overlap is the three parallel-view widgets (T037 and T050), which the US2 and US3 developers must
coordinate on.

---

## Notes

- [P] = different files, no dependencies on incomplete work
- Tests are included because Constitution II requires regression evidence before cutover
- Commit after each task or logical group
- Stop at any checkpoint to validate a story independently
- **The single most important ordering constraint**: never merge T009/T010 without T006

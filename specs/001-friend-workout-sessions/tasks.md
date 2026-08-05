# Tasks: Friend Workout Sessions

**Input**: Design documents from `specs/001-friend-workout-sessions/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/openapi.yaml`, `quickstart.md`
**Tests**: Included because the spec, constitution, and quickstart require regression evidence for primary and critical failure paths.
**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and does not depend on incomplete tasks.
- **[Story]**: Maps task to a user story from `spec.md`; only user story phases include story labels.
- Every task includes a concrete file path.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare shared test and source structure for the paired-session slice.

- [X] T001 Create session service test fixture helpers for two-user paired sessions in `test/services/session_service_test.dart`
- [X] T002 [P] Create session presentation pump helpers for paired-session widgets in `test/features/session/presentation/start_session_page_test.dart`
- [X] T003 [P] Add quickstart scenario references for this feature to `test/features/session/presentation/session_room_auth_contract_test.dart`
- [X] T004 [P] Review existing Firestore session rule coverage for paired-session access paths in `test/firebase/firestore_rules_contract_test.dart`
- [X] T005 Add a feature flag or guarded entry constant for paired friend sessions in `lib/core/constants/feature_flags.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain, service, telemetry, and access contracts that MUST be complete before any user story can be implemented.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 Add paired-session constants for bot id, invite timeout, partner kind, and session mode in `lib/core/constants/constants.dart`
- [X] T007 Extend session domain models for `partnerKind`, `partnerId`, explicit two-participant mode, invitation state, and shared clock metadata in `lib/core/models/models.dart`
- [X] T008 Add participant-owned plan fields for workout type, personal copy source, non-gym stages, targets, and update timestamp in `lib/features/session/domain/gym_session_plan.dart`
- [X] T009 Add participant progress value objects for gym, time, distance, round, and mobility summaries in `lib/core/models/models.dart`
- [X] T010 Implement one-to-one session validation helpers in `lib/services/session_service.dart`
- [X] T011 Implement mutual-follow and no-block invite eligibility checks using existing follow/block data in `lib/services/follow_service.dart`
- [X] T012 Add paired-session telemetry event names and payload helpers in `lib/services/session_analytics_service.dart`
- [X] T013 Add service-level tests for two-participant validation, mode derivation, and plan ownership in `test/services/session_service_test.dart`
- [X] T014 [P] Add model contract tests for paired session fields and participant progress serialization in `test/models/models_test.dart`
- [X] T015 [P] Add Firestore rule contract tests for invite eligibility and participant plan ownership in `test/firebase/firestore_rules_contract_test.dart`

**Checkpoint**: Foundation ready; user story implementation can now begin.

---

## Phase 3: User Story 1 - Practice With Bot Friend (Priority: P1) MVP

**Goal**: Every user can select a bot friend and run a simulated paired session, including fixed gym set values.

**Independent Test**: Choose the bot friend as partner, start a gym-style session, and confirm the bot completes turns using 7 seconds, 8 reps, and 80 kg.

### Tests for User Story 1

- [X] T016 [P] [US1] Add service test for creating a bot paired session without invitation eligibility in `test/services/session_service_test.dart`
- [X] T017 [P] [US1] Add widget test for selecting bot friend from session start flow in `test/features/session/presentation/start_session_page_test.dart`
- [X] T018 [P] [US1] Add widget test for fixed bot gym turn values in `test/features/session/presentation/widgets/active_turn_screen_test.dart`
- [X] T019 [P] [US1] Add widget test for bot progress in rep counter display in `test/features/session/presentation/widgets/rep_counter_screen_test.dart`

### Implementation for User Story 1

- [X] T020 [US1] Implement `BotFriend` domain representation and fixed gym simulation profile in `lib/core/models/models.dart`
- [X] T021 [US1] Add bot friend selection option and one-partner enforcement in `lib/features/session/presentation/start_session_page.dart`
- [X] T022 [US1] Implement bot paired-session creation path that skips invitation response in `lib/services/session_service.dart`
- [X] T023 [US1] Emit bot session start and bot simulation failure telemetry in `lib/services/session_analytics_service.dart`
- [X] T024 [US1] Display bot as the only partner in the session room header and participant list in `lib/features/session/presentation/session_room_page.dart`
- [X] T025 [US1] Render fixed bot gym turn values of 7 seconds, 8 reps, and 80 kg in `lib/features/session/presentation/widgets/active_turn_screen.dart`
- [X] T026 [US1] Render bot set completion and rep/weight feedback in `lib/features/session/presentation/widgets/rep_counter_screen.dart`
- [X] T027 [US1] Add type-appropriate non-gym bot progress summaries in `lib/services/session_service.dart`

**Checkpoint**: US1 is independently functional and demoable as the MVP.

---

## Phase 4: User Story 2 - Invite And Join A Real Friend (Priority: P1)

**Goal**: Host invites one eligible mutual follow, invitee receives a pop-up, accepts or declines, and both users join the same one-to-one session.

**Independent Test**: Use two users; send one invitation from host, verify invited user sees the pop-up within 5 seconds, accepts within 30 seconds, and appears as the only invited participant.

### Tests for User Story 2

- [X] T028 [P] [US2] Add service test for mutual-follow invitation success and non-mutual/block rejection in `test/services/session_invite_delivery_contract_test.dart`
- [X] T029 [P] [US2] Add service test for 30-second invitation expiry and late acceptance rejection in `test/services/session_service_test.dart`
- [X] T030 [P] [US2] Add widget test for one-friend selection limit and second-partner prevention in `test/features/session/presentation/start_session_page_test.dart`
- [X] T031 [P] [US2] Add widget test for invited-side pop-up accept and decline actions in `test/features/session/presentation/session_invite_acceptance_page_test.dart`
- [X] T032 [P] [US2] Add notification contract test for invite dialog payload fields in `test/services/notification_service_contract_test.dart`

### Implementation for User Story 2

- [X] T033 [US2] Replace multi-select friends behavior with exactly-one friend selection in `lib/features/session/presentation/start_session_page.dart`
- [X] T034 [US2] Enforce invite eligibility before invite creation in `lib/services/session_service.dart`
- [X] T035 [US2] Add 30-second invitation expiry fields and expiry handling in `lib/services/session_service.dart`
- [X] T036 [US2] Update invite notification payload for host name, session id, workout type, expiry, and one-to-one context in `lib/services/notification_service.dart`
- [X] T037 [US2] Show invitation pop-up and accept/decline/expired states for invited users in `lib/features/session/presentation/session_invite_acceptance_page.dart`
- [X] T038 [US2] Show host-side pending, accepted, declined, expired, and delivery-failed statuses in `lib/features/session/presentation/session_room_page.dart`
- [X] T039 [US2] Add user-facing errors for ineligible invitee, existing partner, expired invite, and delivery failure in `lib/features/session/presentation/start_session_page.dart`
- [X] T040 [US2] Emit invite created, eligibility rejected, shown, accepted, declined, expired, and delivery failed telemetry in `lib/services/session_analytics_service.dart`

**Checkpoint**: US2 invitation flow is independently functional for eligible and ineligible users.

---

## Phase 5: User Story 3 - Review Personal Workout Plan Before Starting (Priority: P1)

**Goal**: Same-gym invited friends can approve or personalize the host plan without changing the host plan, and both users must be ready before a turn-based gym session starts.

**Independent Test**: Host creates gym plan, invitee accepts and chooses gym, invitee modifies their own copy, host plan remains unchanged, both confirm, and turn-based session starts.

### Tests for User Story 3

- [X] T041 [P] [US3] Add service test for host gym plan copy and invited-user plan isolation in `test/services/session_service_test.dart`
- [X] T042 [P] [US3] Add widget test for invited same-gym plan review and personal modification in `test/features/session/presentation/gym_session_setup_page_test.dart`
- [X] T043 [P] [US3] Add widget test for readiness gate before session start in `test/features/session/presentation/session_room_auth_contract_test.dart`
- [X] T044 [P] [US3] Add turn-switch widget test for two-person gym flow in `test/features/session/presentation/widgets/active_turn_screen_test.dart`

### Implementation for User Story 3

- [X] T045 [US3] Implement host plan finalization and invited same-gym plan copy creation in `lib/services/session_service.dart`
- [X] T046 [US3] Update gym setup UI to show host plan review only when invited user chooses matching gym type in `lib/features/session/presentation/gym_session_setup_page.dart`
- [X] T047 [US3] Ensure invited-user modifications write only to the invited user's plan document in `lib/features/session/presentation/widgets/gym_plan_editor.dart`
- [X] T048 [US3] Add both-participants-ready gate before starting real friend sessions in `lib/services/session_service.dart`
- [X] T049 [US3] Update session room ready/start controls for host and invited user plan states in `lib/features/session/presentation/session_room_page.dart`
- [X] T050 [US3] Restrict turn switching to exactly two matching-gym participants in `lib/services/session_service.dart`
- [X] T051 [US3] Render active/waiting turn status for two-person gym sessions in `lib/features/session/presentation/widgets/waiting_turn_screen.dart`
- [X] T052 [US3] Emit plan copied, plan modified, plan ready, and readiness blocked telemetry in `lib/services/session_analytics_service.dart`

**Checkpoint**: US3 plan review and turn-based same-gym flow are independently functional.

---

## Phase 6: User Story 4 - Share Time Across Different Workout Types (Priority: P2)

**Goal**: Participants with different workout types share one clock, create independent plans, and see each other's type-specific progress in parallel mode.

**Independent Test**: Host chooses gym, invitee chooses another supported type, invitee creates own plan directly, session starts in parallel mode, and both users see type-specific progress within 3 seconds.

### Tests for User Story 4

- [X] T053 [P] [US4] Add service test for mixed workout-type mode derivation and shared clock start in `test/services/session_service_test.dart`
- [X] T054 [P] [US4] Add widget test that mixed-type invitee skips host plan review in `test/features/session/presentation/session_invite_acceptance_page_test.dart`
- [X] T055 [P] [US4] Add widget test for parallel gym partner progress display in `test/features/session/presentation/widgets/parallel_gym_view_test.dart`
- [X] T056 [P] [US4] Add widget test for parallel cardio/time partner progress display in `test/features/session/presentation/widgets/parallel_cardio_view_test.dart`
- [X] T057 [P] [US4] Add completion-history test for per-user workout type and plan summaries in `test/services/session_service_test.dart`

### Implementation for User Story 4

- [X] T058 [US4] Implement mixed workout-type plan creation path that skips host plan review in `lib/features/session/presentation/session_invite_acceptance_page.dart`
- [X] T059 [US4] Add type-appropriate personal plan stages and targets for non-gym types in `lib/features/session/domain/gym_session_plan.dart`
- [X] T060 [US4] Start mixed workout-type sessions in parallel mode with one shared clock in `lib/services/session_service.dart`
- [X] T061 [US4] Aggregate participant progress into gym, time, distance, round, and mobility summaries in `lib/services/session_service.dart`
- [X] T062 [US4] Render mixed-session partner progress with type labels and shared elapsed time in `lib/features/session/presentation/session_room_page.dart`
- [X] T063 [US4] Update parallel gym display for partner sets, reps, weight, and current exercise in `lib/features/session/presentation/widgets/parallel_gym_view.dart`
- [X] T064 [US4] Update parallel cardio/time display for duration, distance, stage, and status summaries in `lib/features/session/presentation/widgets/parallel_cardio_view.dart`
- [X] T065 [US4] Preserve separate per-user completion records with owner workout type, plan snapshot, and progress summary in `lib/services/session_service.dart`
- [X] T066 [US4] Render per-user workout history from owner completion records in `lib/features/session/presentation/recap_page.dart`
- [X] T067 [US4] Emit mixed session started, progress latency, disconnect, and completion write telemetry in `lib/services/session_analytics_service.dart`

**Checkpoint**: US4 mixed workout-type shared-time flow is independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Evidence, cleanup, operational safety, and documentation across all user stories.

- [X] T068 [P] Update quickstart validation notes after implementation in `specs/001-friend-workout-sessions/quickstart.md`
- [X] T069 [P] Add rollback verification test that disabling paired sessions hides bot/friend entry points and preserves solo sessions in `test/features/session/presentation/start_session_page_test.dart`
- [X] T070 [P] Add manual QA checklist for bot, invite, plan isolation, mixed progress, disconnection, and history in `specs/001-friend-workout-sessions/checklists/requirements.md`
- [X] T071 Run focused session test suite and record results in `specs/001-friend-workout-sessions/quickstart.md`
- [X] T072 Run `flutter test --reporter compact` and record pass/fail evidence in `specs/001-friend-workout-sessions/quickstart.md`
- [X] T073 Review telemetry output for invite, bot, readiness, progress, and completion events in `lib/services/session_analytics_service.dart`
- [X] T074 Remove or disable any obsolete group-invite UI labels that conflict with one-to-one paired sessions in `lib/features/session/presentation/start_session_page.dart`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: No dependencies; can start immediately.
- **Phase 2 Foundational**: Depends on Phase 1; blocks every user story.
- **Phase 3 US1**: Depends on Phase 2; recommended MVP.
- **Phase 4 US2**: Depends on Phase 2; can run after or alongside US1 if staffed, but real friend sessions benefit from shared one-to-one foundation.
- **Phase 5 US3**: Depends on Phase 2 and US2 acceptance path for real friend setup.
- **Phase 6 US4**: Depends on Phase 2 and US2 acceptance path; can proceed in parallel with US3 after invitation acceptance is available.
- **Phase 7 Polish**: Depends on desired stories being implemented.

### User Story Dependencies

- **US1 - Practice With Bot Friend**: Can start after foundation; no dependency on real friend invitation.
- **US2 - Invite And Join A Real Friend**: Can start after foundation; no dependency on bot.
- **US3 - Review Personal Workout Plan Before Starting**: Requires US2 accept/join path for real invited users.
- **US4 - Share Time Across Different Workout Types**: Requires US2 accept/join path and shared participant plan/progress foundation.

### Within Each User Story

- Tests first, and they should fail before implementation.
- Domain/model updates before service behavior.
- Service behavior before UI integration.
- UI integration before telemetry/evidence checkpoint.
- Story checkpoint must pass before treating the story as complete.

---

## Parallel Opportunities

- Setup tasks T002, T003, T004 can run in parallel.
- Foundational model/rules tests T014 and T015 can run in parallel after T006-T012 interfaces are sketched.
- US1 tests T016-T019 can run in parallel.
- US2 tests T028-T032 can run in parallel.
- US3 tests T041-T044 can run in parallel.
- US4 tests T053-T057 can run in parallel.
- US3 and US4 implementation can proceed in parallel after US2 accept/join behavior is available, as they primarily touch different setup/progress paths.
- Polish documentation tasks T068-T070 can run in parallel.

---

## Parallel Example: User Story 1

```text
Task: "T016 [P] [US1] Add service test for creating a bot paired session without invitation eligibility in test/services/session_service_test.dart"
Task: "T017 [P] [US1] Add widget test for selecting bot friend from session start flow in test/features/session/presentation/start_session_page_test.dart"
Task: "T018 [P] [US1] Add widget test for fixed bot gym turn values in test/features/session/presentation/widgets/active_turn_screen_test.dart"
Task: "T019 [P] [US1] Add widget test for bot progress in rep counter display in test/features/session/presentation/widgets/rep_counter_screen_test.dart"
```

## Parallel Example: User Story 2

```text
Task: "T028 [P] [US2] Add service test for mutual-follow invitation success and non-mutual/block rejection in test/services/session_invite_delivery_contract_test.dart"
Task: "T029 [P] [US2] Add service test for 30-second invitation expiry and late acceptance rejection in test/services/session_service_test.dart"
Task: "T030 [P] [US2] Add widget test for one-friend selection limit and second-partner prevention in test/features/session/presentation/start_session_page_test.dart"
Task: "T031 [P] [US2] Add widget test for invited-side pop-up accept and decline actions in test/features/session/presentation/session_invite_acceptance_page_test.dart"
```

## Parallel Example: User Story 3

```text
Task: "T041 [P] [US3] Add service test for host gym plan copy and invited-user plan isolation in test/services/session_service_test.dart"
Task: "T042 [P] [US3] Add widget test for invited same-gym plan review and personal modification in test/features/session/presentation/gym_session_setup_page_test.dart"
Task: "T043 [P] [US3] Add widget test for readiness gate before session start in test/features/session/presentation/session_room_auth_contract_test.dart"
Task: "T044 [P] [US3] Add turn-switch widget test for two-person gym flow in test/features/session/presentation/widgets/active_turn_screen_test.dart"
```

## Parallel Example: User Story 4

```text
Task: "T053 [P] [US4] Add service test for mixed workout-type mode derivation and shared clock start in test/services/session_service_test.dart"
Task: "T054 [P] [US4] Add widget test that mixed-type invitee skips host plan review in test/features/session/presentation/session_invite_acceptance_page_test.dart"
Task: "T055 [P] [US4] Add widget test for parallel gym partner progress display in test/features/session/presentation/widgets/parallel_gym_view_test.dart"
Task: "T056 [P] [US4] Add widget test for parallel cardio/time partner progress display in test/features/session/presentation/widgets/parallel_cardio_view_test.dart"
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1 setup.
2. Complete Phase 2 foundation.
3. Complete Phase 3 US1 bot friend flow.
4. Stop and validate Scenario 1 from `specs/001-friend-workout-sessions/quickstart.md`.
5. Demo bot friend paired workout before continuing to real friend flows.

### Incremental Delivery

1. Foundation ready: one-to-one model, access contract, telemetry names, and tests in place.
2. Deliver US1: bot friend session simulation.
3. Deliver US2: real friend invitation and acceptance.
4. Deliver US3: same-gym plan review and turn-based workout.
5. Deliver US4: mixed workout-type parallel session and separate histories.
6. Complete Phase 7 quickstart and rollback evidence.

### Parallel Team Strategy

1. One engineer owns service/domain foundation in `lib/services/session_service.dart` and `lib/core/models/models.dart`.
2. One engineer owns session start and invite UI in `lib/features/session/presentation/start_session_page.dart` and `lib/features/session/presentation/session_invite_acceptance_page.dart`.
3. One engineer owns gym setup/plan isolation in `lib/features/session/presentation/gym_session_setup_page.dart` and `lib/features/session/presentation/widgets/gym_plan_editor.dart`.
4. One engineer owns mixed progress displays in `lib/features/session/presentation/session_room_page.dart`, `parallel_gym_view.dart`, and `parallel_cardio_view.dart`.

---

## Notes

- `[P]` tasks use different files or can be written as independent tests before implementation.
- `[US1]`, `[US2]`, `[US3]`, and `[US4]` labels map directly to prioritized stories in `spec.md`.
- Preserve existing solo session behavior and feature-flag paired entry points for rollback.
- Do not reintroduce group invite behavior in this feature.
- Commit after each completed phase or coherent story checkpoint.

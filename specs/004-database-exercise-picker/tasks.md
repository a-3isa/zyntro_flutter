# Tasks: Database Exercise Picker

**Input**: Design documents from `specs/004-database-exercise-picker/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/
**Tests**: Included because the plan and constitution require regression evidence for primary paths, permission boundaries, and success criteria.
**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare catalog service, data contracts, and test surfaces used by all stories.

- [X] T001 Create `lib/services/exercise_catalog_service.dart` with empty service class, provider shell, and result/entity type placeholders
- [X] T002 [P] Create `test/services/exercise_catalog_service_test.dart` with test group scaffolding for catalog search, custom creation, and review submission
- [X] T003 [P] Create `test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart` cases placeholders for database-backed search and 1-20 set selection
- [X] T004 [P] Create Firestore rules contract test placeholders for exercise catalog, personal exercises, and review submissions in `test/firebase/firestore_rules_contract_test.dart`
- [X] T005 [P] Add a placeholder stub (3–5 lines) to `specs/004-database-exercise-picker/quickstart.md` reserving space for seed steps; note that full seed instructions and FR-013 minimum-coverage verification are written in T047

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data model, search service, and security boundaries that MUST be complete before user story UI flows.

**CRITICAL**: No user story implementation should begin until this phase is complete.

- [X] T006 Add catalog/custom source identity fields to `PlannedExercise` in `lib/features/session/domain/gym_session_plan.dart` for `exerciseId`, `personalExerciseId`, `sourceType`, and custom metadata persistence
- [X] T007 Add 1-20 `plannedSets` validation for all `PlannedExercise` factories and deserialization paths in `lib/features/session/domain/gym_session_plan.dart`
- [X] T008 [P] Add domain tests for catalog/custom identity and 1-20 set validation in `test/features/session/domain/gym_session_plan_test.dart`
- [X] T009 Implement `ExerciseCatalogEntry`, `PersonalExerciseEntry`, `ExerciseReviewSubmission`, and picker result models in `lib/services/exercise_catalog_service.dart`
- [X] T010 Implement case-insensitive normalization, tokenization, partial matching, and bounded typo-tolerant matching helpers in `lib/services/exercise_catalog_service.dart`
- [X] T011 Implement shared catalog search plus current-user personal exercise merge in `lib/services/exercise_catalog_service.dart`
- [X] T012 Implement custom exercise creation with personal entry plus pending review submission in `lib/services/exercise_catalog_service.dart`
- [X] T013 Add Firestore rules for active shared exercise catalog reads, user-owned personal exercise access, and review submission create/moderation boundaries in `firebase/firestore.rules`
- [X] T014 [P] Add service tests for search normalization, fuzzy matching, personal result isolation, and custom creation in `test/services/exercise_catalog_service_test.dart`
- [X] T015 [P] Add Firestore rules tests for catalog read, personal exercise isolation, and review approval denial in `test/firebase/firestore_rules_contract_test.dart`

**Checkpoint**: Database exercise search, personal custom exercise creation, review submission, set validation, and rules boundaries are ready for UI stories.

---

## Phase 3: User Story 1 - Choose Planned Exercises From Database (Priority: P1) MVP

**Goal**: Start-session gym planning opens the shared database picker, lets the user search/select an exercise, choose 1-20 sets, and add it to the plan with database/custom identity.

**Independent Test**: Start a gym session plan, tap "Add exercise", search `BeNcH`, select a result, choose a non-default set count, and confirm it appears in the plan with the chosen sets and identity.

### Tests for User Story 1

- [X] T016 [P] [US1] Add failing widget test for start-session "Add exercise" opening picker instead of inline free-text in `test/features/session/presentation/start_session_page_test.dart`
- [X] T017 [P] [US1] Add failing widget test for picker returning selected exercise with non-default 1-20 set count in `test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart`
- [X] T018 [P] [US1] Add failing widget test for start-session plan storing catalog identity after picker selection in `test/features/session/presentation/start_session_page_test.dart`

### Implementation for User Story 1

- [X] T019 [US1] Replace start-session inline exercise text field and suggestions with an "Add exercise" picker launch action in `lib/features/session/presentation/start_session_page.dart`
- [X] T020 [US1] Refactor `_plan` in `lib/features/session/presentation/start_session_page.dart` to retain `PlannedExercise` catalog/custom identity instead of downgrading every item to custom name-only entries
- [X] T021 [US1] Update `ExercisePlanItem` or remove its name-only usage in `lib/features/session/domain/exercise_plan_item.dart` so start-session plans preserve selected exercise identity and 1-20 sets
- [X] T022 [US1] Update `GymExercisePickerSheet` in `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart` to consume `ExerciseCatalogService`, display each result with the exercise name and at least one distinguishing detail (category, muscle group, or equipment) per FR-004, and return a selected exercise only after set count confirmation
- [X] T023 [US1] Add 1-20 set selector UI and validation messaging to `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`
- [X] T024 [US1] Preserve existing reorder, remove, and set edit behavior for selected exercises in `lib/features/session/presentation/start_session_page.dart`
- [X] T025 [US1] Ensure session creation writes selected catalog/custom identity into `GymSessionPlan` in `lib/features/session/presentation/start_session_page.dart`
- [X] T026 [US1] Run and satisfy `flutter test test/features/session/presentation/start_session_page_test.dart test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart`

**Checkpoint**: US1 is independently functional and testable as the MVP.

---

## Phase 4: User Story 2 - Add Exercises At Session End From Database (Priority: P2)

**Goal**: Late-session "Add exercise" opens the same picker and adds the selected exercise as planned remaining work, not completed sets.

**Independent Test**: Enter the session completion/add-more-exercise stage, tap "Add exercise", select an exercise and set count, confirm it appears as planned remaining work, then verify sets count only after normal logging.

### Tests for User Story 2

- [X] T027 [P] [US2] Add failing widget test for session-room late "Add Exercise" opening `GymExercisePickerSheet` in `test/features/session/presentation/session_room_auth_contract_test.dart`
- [X] T028 [P] [US2] Add failing widget test that late-added exercise is added as planned remaining work and not completed sets in `test/features/session/presentation/session_room_auth_contract_test.dart`
- [X] T029 [P] [US2] Add failing test that final summary only includes logged late-added sets in `test/features/session/presentation/recap_page_test.dart`

### Implementation for User Story 2

- [X] T030 [US2] Remove the simple add-exercise dialog flow from `lib/features/session/presentation/session_room_page.dart` and route late add through `GymExercisePickerSheet`
- [X] T031 [US2] Update late-add plan mutation in `lib/features/session/presentation/session_room_page.dart` to append selected catalog/custom exercise as planned remaining work with selected set count
- [X] T032 [US2] Ensure late-added exercise identity persists through `SessionService.saveGymPlan` in `lib/services/session_service.dart`
- [X] T033 [US2] Ensure turn/progress calculation treats late-added exercises as incomplete until set events are logged in `lib/features/session/domain/turn_plan_progress.dart`
- [X] T034 [US2] Update recap/session completion logic to count only logged late-added sets in `lib/features/session/presentation/recap_page.dart`
- [X] T035 [US2] Run and satisfy `flutter test test/features/session/presentation/session_room_auth_contract_test.dart test/features/session/presentation/recap_page_test.dart`

**Checkpoint**: US2 works without changing US1 behavior and preserves accurate session history.

---

## Phase 5: User Story 3 - Search Reliable Exercise Database (Priority: P3)

**Goal**: The picker returns consistent shared database and personal custom results across all add-exercise surfaces, including typo/case-insensitive search and custom exercise reuse/review.

**Independent Test**: Search the same known exercise in start-session and late-session picker surfaces; verify consistent details. Search no-match, create custom, and verify the creating user can reuse it later while another user cannot see it.

### Tests for User Story 3

- [X] T036 [P] [US3] Add failing picker test for consistent search details across start/setup/late consumers in `test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart`
- [X] T037 [P] [US3] Add failing service test for custom exercise reuse by owner and invisibility to another user in `test/services/exercise_catalog_service_test.dart`
- [X] T038 [P] [US3] Add failing service test for review submission creation after custom exercise creation in `test/services/exercise_catalog_service_test.dart`
- [X] T039 [P] [US3] Add failing widget tests for picker empty state and custom creation explicit action in `test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart`

### Implementation for User Story 3

- [X] T040 [US3] Add picker empty state with explicit custom exercise creation action in `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`
- [X] T041 [US3] Add custom exercise creation form with name and optional category/equipment fields in `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`
- [X] T042 [US3] Wire custom creation UI to `ExerciseCatalogService.createCustomExercise` in `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`
- [X] T043 [US3] Update existing setup and invite setup picker consumers to handle database/custom result identity in `lib/features/session/presentation/gym_session_setup_page.dart`
- [X] T044 [US3] Update invite acceptance picker consumer to handle database/custom result identity in `lib/features/session/presentation/session_invite_acceptance_page.dart`
- [X] T045 [US3] Add user-facing loading, retry, and no-results states for catalog failures in `lib/features/session/presentation/widgets/gym_exercise_picker_sheet.dart`
- [X] T046 [US3] Run and satisfy `flutter test test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart test/services/exercise_catalog_service_test.dart`

**Checkpoint**: US3 delivers consistent search/custom behavior across all picker consumers.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification, cleanup, rollback readiness, and documentation across all stories.

- [X] T047 [P] Finalize complete seed steps in `specs/004-database-exercise-picker/quickstart.md` (replaces T005 placeholder): step-by-step catalog population instructions from `lib/core/data/gym_exercises.dart`, FR-013 minimum-coverage checklist (≥40 exercises, ≥6 categories), and verification command to count catalog entries
- [X] T048 [P] Add telemetry events to `lib/services/exercise_catalog_service.dart` per constitution §IV: (a) error logging for catalog search failures and custom exercise creation failures; (b) success-rate logging on exercise-selection completion; (c) a fallback-trigger log entry when the local-catalog fallback path is activated
- [X] T049 Implement and test local-catalog fallback in `lib/services/exercise_catalog_service.dart`: when Firestore catalog read fails, serve results from `lib/core/data/gym_exercises.dart` local seed; add a service test in `test/services/exercise_catalog_service_test.dart` that stubs Firestore as unavailable and asserts fallback results are returned; document the fallback behavior and its trigger conditions in `specs/004-database-exercise-picker/quickstart.md` (tested rollback path per constitution §IV)
- [X] T050 Audit generated Firestore indexes or query constraints needed for exercise search and document them in `specs/004-database-exercise-picker/research.md`
- [ ] T054 Populate the shared exercise catalog in Firestore with a minimum of 40 named exercises spanning at least 6 primary muscle-group categories (per FR-013); verify exercise count and category distribution match FR-013 minimum coverage before T051 quickstart validation runs
- [X] T055 [P] Add widget or service test verifying paired-session plan exercise isolation is preserved after T006 identity-field additions and T031 late-add mutations: each participant's exercises remain attached to their own plan in `test/features/session/presentation/session_room_auth_contract_test.dart` (FR-012 regression)
- [X] T056 [P] Add SC-001 and SC-002 manual QA acceptance steps to `specs/004-database-exercise-picker/quickstart.md`: timed walkthrough for (a) adding a database exercise to the start-session plan in under 20 s after tapping "Add exercise" and (b) observing search results for a known exercise name in under 1 s under normal network conditions
- [ ] T051 Run quickstart validation scenarios from `specs/004-database-exercise-picker/quickstart.md`
- [X] T052 Run focused verification: `flutter test test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart test/features/session/presentation/start_session_page_test.dart test/features/session/presentation/session_room_auth_contract_test.dart test/services/exercise_catalog_service_test.dart test/firebase/firestore_rules_contract_test.dart`
- [X] T053 Run broader regression suite with `flutter test`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user story phases.
- **User Story 1 (Phase 3)**: Depends on Foundational; MVP.
- **User Story 2 (Phase 4)**: Depends on Foundational; can run after US1 for shared picker confidence, but remains independently testable.
- **User Story 3 (Phase 5)**: Depends on Foundational; can run in parallel with US1/US2 after shared service contracts stabilize.
- **Polish (Phase 6)**: Depends on selected story phases being complete. Within Phase 6: T049 (rollback implementation and test) and T054 (catalog seeding) MUST complete before T051 (quickstart validation).

### User Story Dependencies

- **US1 Choose Planned Exercises From Database**: Requires Foundation only.
- **US2 Add Exercises At Session End From Database**: Requires Foundation and shared picker behavior; does not require start-session implementation to be complete.
- **US3 Search Reliable Exercise Database**: Requires Foundation and strengthens the shared picker/service behavior used by US1 and US2.

### Within Each User Story

- Write failing tests before implementation tasks.
- Domain/model changes before service integration.
- Service behavior before UI wiring.
- UI wiring before end-to-end scenario verification.
- Story is complete only when its independent tests pass.

## Parallel Opportunities

- T002, T003, T004, and T005 can run in parallel after T001.
- T008, T014, and T015 can run in parallel with model/rules work once interfaces are agreed.
- US1 test tasks T016, T017, and T018 can run in parallel.
- US2 test tasks T027, T028, and T029 can run in parallel.
- US3 test tasks T036, T037, T038, and T039 can run in parallel.
- US2 and US3 implementation can proceed in parallel after Foundation if both coordinate changes to `GymExercisePickerSheet`.
- T055 and T056 can run in parallel after story phases complete.

## Parallel Example: User Story 1

```text
Task: "T016 [US1] Add failing widget test for start-session Add exercise opening picker in test/features/session/presentation/start_session_page_test.dart"
Task: "T017 [US1] Add failing widget test for picker returning selected exercise with non-default 1-20 set count in test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart"
Task: "T018 [US1] Add failing widget test for start-session plan storing catalog identity in test/features/session/presentation/start_session_page_test.dart"
```

## Parallel Example: User Story 2

```text
Task: "T027 [US2] Add failing widget test for session-room late Add Exercise opening GymExercisePickerSheet in test/features/session/presentation/session_room_auth_contract_test.dart"
Task: "T029 [US2] Add failing test that final summary only includes logged late-added sets in test/features/session/presentation/recap_page_test.dart"
```

## Parallel Example: User Story 3

```text
Task: "T037 [US3] Add failing service test for custom exercise reuse by owner and invisibility to another user in test/services/exercise_catalog_service_test.dart"
Task: "T039 [US3] Add failing widget tests for picker empty state and custom creation explicit action in test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart"
```

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3.
3. Validate start-session exercise selection independently with focused tests and quickstart Scenario 1.
4. Stop for demo/cutover decision if only MVP is needed.

### Incremental Delivery

1. Foundation: database catalog service, personal custom model, rules, validation.
2. US1: replace start-session planning add flow.
3. US2: reuse picker for late-session planned remaining work.
4. US3: complete custom creation/reuse, typo-tolerant search, and cross-surface consistency.
5. Polish: quickstart, telemetry, rules, and full regression evidence.

### Risk Controls

- Preserve existing session plan serialization compatibility while adding identity fields.
- Do not remove local seed catalog until shared catalog QA passes.
- Keep custom exercise creation explicit to avoid accidental free-text entries.
- Verify Firestore rules before allowing personal custom exercises or review submissions in cutover.

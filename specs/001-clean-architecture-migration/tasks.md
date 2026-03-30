# Tasks: Core Flows Clean Architecture Migration (Auth Slice)

**Input**: Design documents from `D:/zyntro_flutter/specs/001-clean-architecture-migration/`  
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Test tasks are included because the specification explicitly requires test evidence for primary and failure paths (`FR-007`).

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: User story label for story-phase tasks only (`[US1]`, `[US2]`, `[US3]`)
- Every task includes an exact file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare migration-governance module and test scaffolding

- [X] T001 Create migration governance module structure in `D:/zyntro_flutter/lib/core/migration/models/` and `D:/zyntro_flutter/lib/core/migration/services/`
- [X] T002 Create migration governance test structure in `D:/zyntro_flutter/test/core/migration/` and `D:/zyntro_flutter/integration_test/`
- [X] T003 [P] Add migration governance barrel export in `D:/zyntro_flutter/lib/core/migration/migration.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core assets required before user-story implementation

**CRITICAL**: Complete this phase before starting user story phases

- [X] T004 Create shared lifecycle enums and value objects in `D:/zyntro_flutter/lib/core/migration/models/migration_lifecycle.dart`
- [X] T005 [P] Implement shared transition guard utility in `D:/zyntro_flutter/lib/core/migration/services/migration_transition_guard.dart`
- [X] T006 [P] Implement shared evidence policy utility in `D:/zyntro_flutter/lib/core/migration/services/migration_evidence_policy.dart`
- [X] T007 Wire foundational migration providers in `D:/zyntro_flutter/lib/features/auth/auth_providers.dart`
- [X] T008 Add foundational unit tests for shared migration utilities in `D:/zyntro_flutter/test/core/migration/migration_foundation_test.dart`

**Checkpoint**: Foundation complete; user stories can proceed

---

## Phase 3: User Story 1 - Migrate Existing Core Feature (Priority: P1) MVP

**Goal**: Migrate auth core flows to governed clean architecture with validated cutover controls

**Independent Test**: Execute auth migration lifecycle and verify auth journeys remain intact before/after cutover using integration and regression evidence.

### Tests for User Story 1

- [X] T009 [P] [US1] Add migration state-machine unit tests in `D:/zyntro_flutter/test/core/migration/migration_state_machine_test.dart`
- [X] T010 [P] [US1] Add auth security regression and validation-evidence service unit tests in `D:/zyntro_flutter/test/core/migration/validation_evidence_service_test.dart`
- [X] T011 [P] [US1] Add auth migration integration test for no-downtime cutover and rollback readiness in `D:/zyntro_flutter/integration_test/auth_migration_flow_test.dart`

### Implementation for User Story 1

- [X] T012 [P] [US1] Create `MigrationSlice` model in `D:/zyntro_flutter/lib/core/migration/models/migration_slice.dart`
- [X] T013 [P] [US1] Create `LayerContract` model in `D:/zyntro_flutter/lib/core/migration/models/layer_contract.dart`
- [X] T014 [P] [US1] Create `ValidationReport` model in `D:/zyntro_flutter/lib/core/migration/models/validation_report.dart`
- [X] T015 [US1] Implement migration state machine in `D:/zyntro_flutter/lib/core/migration/services/migration_state_machine.dart`
- [X] T016 [US1] Implement validation evidence service in `D:/zyntro_flutter/lib/core/migration/services/validation_evidence_service.dart`
- [X] T017 [US1] Implement governance repository mapping for `/migration-slices`, `/state`, `/validation-reports`, `/telemetry-baseline`, `/cutover`, and `/rollback` in `D:/zyntro_flutter/lib/core/migration/services/migration_governance_repository.dart`
- [X] T018 [US1] Integrate migration readiness checks in `D:/zyntro_flutter/lib/features/auth/presentation/providers/auth_controller.dart`
- [X] T019 [US1] Enforce cutover guardrails in auth navigation flow in `D:/zyntro_flutter/lib/app/navigation/app_router.dart`
- [X] T020 [US1] Add auth-slice cutover checklist updates in `D:/zyntro_flutter/specs/001-clean-architecture-migration/quickstart.md`

**Checkpoint**: User Story 1 is independently functional and testable

---

## Phase 4: User Story 2 - Codify Standard Architecture for Future Features (Priority: P2)

**Goal**: Establish repeatable architecture workflow for future non-auth feature slices

**Independent Test**: Validate that a new feature proposal can be checked against the standard and logged as a follow-on migration backlog item.

### Tests for User Story 2

- [X] T021 [P] [US2] Add feature blueprint validator unit tests in `D:/zyntro_flutter/test/core/migration/feature_blueprint_validator_test.dart`
- [X] T022 [P] [US2] Add backlog service unit tests for deferred slice tracking in `D:/zyntro_flutter/test/core/migration/migration_backlog_service_test.dart`

### Implementation for User Story 2

- [X] T023 [P] [US2] Create `MigrationBacklogItem` model in `D:/zyntro_flutter/lib/core/migration/models/migration_backlog_item.dart`
- [X] T024 [P] [US2] Implement feature blueprint validator in `D:/zyntro_flutter/lib/core/migration/services/feature_blueprint_validator.dart`
- [X] T025 [US2] Implement backlog service mapped to `/migration-backlog-items` in `D:/zyntro_flutter/lib/core/migration/services/migration_backlog_service.dart`
- [X] T026 [US2] Add feature-layer validation script in `D:/zyntro_flutter/scripts/validate_feature_layers.ps1`
- [X] T027 [US2] Document reusable clean-architecture workflow in `D:/zyntro_flutter/docs/clean-architecture-feature-workflow.md`
- [X] T028 [US2] Link workflow and usage guidance in `D:/zyntro_flutter/README.md`

**Checkpoint**: User Story 2 is independently functional and testable

---

## Phase 5: User Story 3 - Ensure Consistent Error Experience (Priority: P3)

**Goal**: Deliver consistent domain-failure mapping, user messaging, and rollback-trigger observability for auth flows

**Independent Test**: Trigger representative auth failures and verify consistent user-facing messages, categorized failures, and rollback-trigger signal handling.

### Tests for User Story 3

- [X] T029 [P] [US3] Add domain-failure category mapper unit tests in `D:/zyntro_flutter/test/core/migration/domain_failure_category_mapper_test.dart`
- [X] T030 [P] [US3] Add telemetry baseline service unit tests in `D:/zyntro_flutter/test/core/migration/telemetry_baseline_service_test.dart`
- [X] T031 [P] [US3] Add auth error-surface widget tests in `D:/zyntro_flutter/test/features/auth/presentation/auth_error_surface_test.dart`

### Implementation for User Story 3

- [X] T032 [P] [US3] Create `DomainFailureCategory` model in `D:/zyntro_flutter/lib/core/migration/models/domain_failure_category.dart`
- [X] T033 [P] [US3] Create `TelemetryBaseline` model in `D:/zyntro_flutter/lib/core/migration/models/telemetry_baseline.dart`
- [X] T034 [P] [US3] Create `RollbackEvent` model in `D:/zyntro_flutter/lib/core/migration/models/rollback_event.dart`
- [X] T035 [US3] Implement domain failure mapper in `D:/zyntro_flutter/lib/core/migration/services/domain_failure_category_mapper.dart`
- [X] T036 [US3] Implement telemetry baseline and rollback-alert service in `D:/zyntro_flutter/lib/core/migration/services/telemetry_baseline_service.dart`
- [X] T037 [US3] Standardize auth error rendering in `D:/zyntro_flutter/lib/features/auth/presentation/login_page.dart`
- [X] T038 [US3] Standardize auth error rendering in `D:/zyntro_flutter/lib/features/auth/presentation/signup_page.dart`
- [X] T039 [US3] Standardize auth error rendering in `D:/zyntro_flutter/lib/features/auth/presentation/forgot_password_page.dart`
- [X] T040 [US3] Integrate rollback-trigger handling in `D:/zyntro_flutter/lib/features/auth/presentation/providers/auth_controller.dart`

**Checkpoint**: User Story 3 is independently functional and testable

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final hardening across stories

- [X] T041 [P] Align implementation with contract in `D:/zyntro_flutter/specs/001-clean-architecture-migration/contracts/auth-migration-governance.openapi.yaml`
- [X] T042 Run validation commands and capture outcomes in `D:/zyntro_flutter/specs/001-clean-architecture-migration/quickstart.md`
- [X] T043 [P] Add dedicated auth security regression integration suite in `D:/zyntro_flutter/integration_test/auth_security_regression_test.dart`
- [X] T044 Capture approved security regression evidence in `D:/zyntro_flutter/specs/001-clean-architecture-migration/security-regression-report.md`
- [X] T045 Create pre-cutover delivery-time baseline report in `D:/zyntro_flutter/specs/001-clean-architecture-migration/metrics/delivery-time-baseline.md`
- [X] T046 Track 5-business-day post-cutover critical regression SLA in `D:/zyntro_flutter/specs/001-clean-architecture-migration/metrics/post-cutover-critical-regressions.md`
- [X] T047 [P] Update cutover readiness evidence checklist in `D:/zyntro_flutter/specs/001-clean-architecture-migration/quickstart.md`
- [X] T048 [P] Normalize migration terminology across `D:/zyntro_flutter/specs/001-clean-architecture-migration/spec.md`, `D:/zyntro_flutter/specs/001-clean-architecture-migration/plan.md`, and `D:/zyntro_flutter/specs/001-clean-architecture-migration/data-model.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies
- **Phase 2 (Foundational)**: Depends on Phase 1 and blocks all story phases
- **Phase 3 (US1)**: Depends on Phase 2
- **Phase 4 (US2)**: Depends on Phase 2
- **Phase 5 (US3)**: Depends on Phase 2 and benefits from US1 auth lifecycle wiring
- **Phase 6 (Polish)**: Depends on completed story phases targeted for release

### User Story Dependencies

- **US1 (P1)**: Primary MVP slice; no dependency on other stories after foundation
- **US2 (P2)**: Can run independently after foundation; consumes lifecycle conventions
- **US3 (P3)**: Can start after foundation; integrates cleanly with US1 auth provider wiring

### Within Each User Story

- Tests first, implementation second
- Models before services
- Services before UI/provider integration
- Story checkpoint validation before moving forward

## Parallel Execution Examples

### User Story 1

- Run in parallel: `T009`, `T010`, `T011`
- Run in parallel: `T012`, `T013`, `T014`

### User Story 2

- Run in parallel: `T021`, `T022`
- Run in parallel: `T023`, `T024`

### User Story 3

- Run in parallel: `T029`, `T030`, `T031`
- Run in parallel: `T032`, `T033`, `T034`

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2
2. Complete Phase 3 (US1)
3. Validate US1 independently with `T009`-`T011`
4. Demo/release MVP auth migration slice

### Incremental Delivery

1. Deliver US1 (auth migration governance)
2. Deliver US2 (reusable architecture workflow for new features)
3. Deliver US3 (consistent error experience and rollback telemetry behavior)
4. Execute polish tasks before broad rollout

### Parallel Team Strategy

1. Team completes Setup + Foundational together
2. Then split by story:
   - Engineer A on US1
   - Engineer B on US2
   - Engineer C on US3
3. Rejoin for Phase 6 polish and release validation

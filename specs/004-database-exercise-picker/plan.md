# Implementation Plan: Database Exercise Picker

**Branch**: `004-database-exercise-picker` | **Date**: 2026-05-30 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/004-database-exercise-picker/spec.md`

## Summary

Replace ad hoc exercise entry in the gym start-session and late-session add flows with one database-backed exercise picker. The picker will search a shared exercise catalog plus the current user's personal custom exercises, allow a 1-20 set selection before confirmation, preserve database or custom identity in session plans, submit new custom exercises for review, and keep late-added exercises as planned remaining work until the user logs each set.

## Technical Context

**Language/Version**: Dart SDK `^3.10.4` with Flutter 3.10+  
**Primary Dependencies**: `flutter_riverpod`, `go_router`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `mocktail`, `flutter_test`, `integration_test`, existing session service and gym plan domain models  
**Storage**: Cloud Firestore: new shared exercise catalog collection, user-owned personal exercise collection/subcollection, exercise review submissions, existing `sessions/{sessionId}/plans/{userId}` and session events  
**Testing**: `flutter test`, focused widget tests for picker/setup/session-room flows, service tests with mocked Firestore dependencies, Firestore rules contract tests for catalog/personal/review access  
**Target Platform**: iOS and Android mobile app  
**Project Type**: Flutter mobile app with feature-first presentation code and shared services  
**Performance Goals**: 95% of known exercise searches return visible results in under 1 second; 95% of users can add a database exercise in under 20 seconds after tapping "Add exercise"  
**Constraints**: Preserve existing gym session setup, paired-session plan ownership, and late-session turn/progress behavior; no accidental free-text creation; set count restricted to 1-20; search must be case-insensitive and typo-tolerant where reasonable  
**Scale/Scope**: Gym exercise selection only; affects start-session planning, gym setup/invite setup where picker is already used, and session-room late add; shared catalog plus per-user custom exercises

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope Discipline | PASS | Scope is limited to gym exercise selection/catalog data and the two requested add-exercise entry points. Profile/history work and broader workout tracking remain out of scope. |
| II. Evidence-First Cutover | PASS | Success criteria map to search speed, selection completion, identity persistence, custom reuse, and set-count validation; plan requires widget, service, and rules evidence. |
| III. Security and Access Integrity | PASS | Shared catalog reads, personal custom exercise ownership, and review submission permissions are explicitly planned and must be regression-tested. |
| IV. Operational Safety and Reversibility | PASS | Existing session plan records remain compatible; rollout can fall back to local catalog/picker behavior if database catalog read fails before cutover (tested via T049 service test). |
| V. Independent Deliverability | PASS | Shared catalog search, start-session picker replacement, late-session add, and custom exercise persistence can be delivered and tested in order. |

No gate violations. Proceed to Phase 0 research.

### Post-Design Gate

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope Discipline | PASS | Design artifacts stay within exercise catalog, personal custom exercises, session plan selection, and Firestore rules. |
| II. Evidence-First Cutover | PASS | quickstart.md defines scenario evidence for start planning, late add, custom creation/reuse, and permission boundaries. |
| III. Security and Access Integrity | PASS | data-model.md and contracts document ownership and review-state boundaries; rules tests are required before cutover. |
| IV. Operational Safety and Reversibility | PASS | The plan preserves existing `PlannedExercise` source semantics and adds custom/catalog identity without destructive migration. |
| V. Independent Deliverability | PASS | Each story can be implemented after foundational catalog service work with focused acceptance tests. |

No gate violations after Phase 1 design.

## Project Structure

### Documentation (this feature)

```text
specs/004-database-exercise-picker/
|-- plan.md
|-- research.md
|-- data-model.md
|-- quickstart.md
|-- contracts/
|   `-- exercise-picker-contract.md
|-- checklists/
|   `-- requirements.md
`-- tasks.md
```

### Source Code (repository root)

```text
lib/core/data/
`-- gym_exercises.dart                  # seed/source catalog data during transition

lib/features/session/domain/
|-- exercise_plan_item.dart
|-- turn_plan_progress.dart             # existing; modified to treat late-added exercises as incomplete until sets are logged
`-- gym_session_plan.dart               # selected exercise identity/source/set count

lib/features/session/presentation/
|-- start_session_page.dart             # start-session add entry point
|-- session_room_page.dart              # late-session add entry point
|-- recap_page.dart                     # existing; modified to include only logged late-added sets in session summary
|-- gym_session_setup_page.dart         # existing setup picker consumer
|-- session_invite_acceptance_page.dart # existing invite setup picker consumer
`-- widgets/
    |-- gym_exercise_picker_sheet.dart  # shared picker UI
    `-- gym_plan_editor.dart

lib/services/
|-- exercise_catalog_service.dart       # new catalog/personal/review service
`-- session_service.dart                # existing plan persistence integration

firebase/
`-- firestore.rules                     # catalog, personal custom, review access

test/features/session/
|-- domain/
|   `-- gym_session_plan_test.dart      # existing; extended for catalog/custom identity and 1-20 set validation
|-- presentation/
|   |-- start_session_page_test.dart
|   |-- session_room_auth_contract_test.dart
|   |-- recap_page_test.dart            # existing; extended for late-add set logging summary
|   |-- gym_session_setup_page_test.dart
|   `-- widgets/gym_exercise_picker_sheet_test.dart
`-- services/
    `-- exercise_catalog_service_test.dart

test/firebase/
`-- firestore_rules_contract_test.dart
```

**Structure Decision**: Use the existing Flutter feature-first session structure. Add a shared `ExerciseCatalogService` under `lib/services/` because catalog reads, personal custom exercise persistence, and review submissions are shared by start-session, setup, invite, and session-room entry points. Keep the picker widget in `lib/features/session/presentation/widgets/` and reuse it across all add-exercise surfaces.

## Complexity Tracking

No constitution violations require justification.

# Implementation Plan: Friend Workout Sessions

**Branch**: `001-friend-workout-sessions` | **Date**: 2026-05-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-friend-workout-sessions/spec.md`

---

## Summary

Add one-to-one paired workout sessions with either one real invited friend or one built-in bot friend. Real friend invitations are limited to mutual follows with no block relationship, expire after 30 seconds, and must surface as an in-app invitation dialog. Matching gym sessions use turn-based flow and allow the invited friend to approve or personalize a copied host plan; mixed workout-type sessions run in parallel under a shared clock while each participant owns a type-appropriate plan and progress summary. The implementation will stay inside the existing Flutter session and service boundaries, tightening current multi-invite behavior to the clarified one-to-one product model.

---

## Technical Context

**Language/Version**: Dart SDK `^3.10.4` with Flutter 3.10+  
**Primary Dependencies**: `flutter_riverpod`, `go_router`, `firebase_auth`, `cloud_firestore`, `shared_preferences`, `mocktail`, `flutter_test`, `integration_test`, existing session/follow/notification/user-cache services  
**Storage**: Cloud Firestore collections already used by the app: `sessions`, session `plans` subcollection, session `events` subcollection, `workouts`, user follow/block data, notification data  
**Testing**: `flutter test`, focused widget tests for session invite/setup screens, service tests with mocked Firestore/service dependencies, integration tests for two-user invite/setup/session flow where feasible  
**Target Platform**: iOS and Android mobile app  
**Project Type**: Flutter mobile app with feature-first presentation code plus shared services  
**Performance Goals**: Invitation dialog appears for active invited users within 5 seconds; mixed-session progress visible within 3 seconds of session start; bot gym session visible within 30 seconds of selecting bot  
**Constraints**: Preserve existing clean-architecture migration direction; keep this slice in the session domain; no planned downtime; support rollback by preserving existing solo session behavior and avoiding destructive data migration  
**Scale/Scope**: One-to-one paired sessions only; one host plus one invited friend or one bot friend; workout types include gym, running, cycling, swimming, yoga, HIIT, walking, sports, and other

---

## Constitution Check

### Pre-Design Gate

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope Discipline | PASS | Scope is limited to paired workout sessions, invite eligibility/expiry, bot partner, plan confirmation, and progress display. Non-session social redesign is out of scope. |
| II. Evidence-First Cutover | PASS | Success criteria SC-001 through SC-007 map to bot simulation, invite delivery/expiry, plan isolation, mixed progress, usability, and history accuracy. Regression evidence is defined in quickstart.md. |
| III. Security and Access Integrity | PASS | Invite eligibility is restricted to mutual follows with no block relationship and must be regression-tested before cutover. |
| IV. Operational Safety and Reversibility | PASS | Existing solo session flow remains intact; paired session behavior can be gated and rolled back by disabling new invite/bot entry points while preserving existing session records. Telemetry is required for invite delivery, acceptance, expiry, plan readiness, and session start failures. |
| V. Independent Deliverability | PASS | User stories are independently deliverable: bot session, real friend invite, plan review, and mixed-type shared-time progress. Foundational session contract work precedes UI flows. |

No gate violations. Proceed to Phase 0 research.

### Post-Design Gate

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Feature-Slice Scope Discipline | PASS | Design artifacts keep changes in session, follow/block eligibility, notification, and existing progress surfaces. |
| II. Evidence-First Cutover | PASS | quickstart.md defines scenario evidence for each success criterion and key failure path. |
| III. Security and Access Integrity | PASS | Contracts and data model include invite eligibility checks, expired invites, and block relationship rejection. |
| IV. Operational Safety and Reversibility | PASS | Research and quickstart include telemetry and rollback triggers; no destructive migration is required. |
| V. Independent Deliverability | PASS | Data model and contracts support implementing user stories in priority order. |

No gate violations after Phase 1 design.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-friend-workout-sessions/
|-- plan.md
|-- research.md
|-- data-model.md
|-- quickstart.md
|-- contracts/
|   `-- openapi.yaml
|-- checklists/
|   `-- requirements.md
`-- tasks.md
```

### Source Code (repository root)

```text
lib/core/
|-- constants/constants.dart
`-- models/models.dart

lib/features/session/
|-- domain/
|   |-- exercise_plan_item.dart
|   `-- gym_session_plan.dart
|-- presentation/
|   |-- start_session_page.dart
|   |-- session_invite_acceptance_page.dart
|   |-- gym_session_setup_page.dart
|   |-- session_room_page.dart
|   |-- session_page.dart
|   |-- recap_page.dart
|   `-- widgets/
|       |-- active_turn_screen.dart
|       |-- waiting_turn_screen.dart
|       |-- parallel_cardio_view.dart
|       |-- parallel_gym_view.dart
|       `-- rep_counter_screen.dart

lib/services/
|-- follow_service.dart
|-- notification_service.dart
|-- session_service.dart
|-- session_analytics_service.dart
`-- user_cache_service.dart

test/features/session/
|-- presentation/
|-- services/
`-- integration/
```

**Structure Decision**: Use the existing Flutter feature-first session structure and shared services. This feature should not introduce a separate backend module; Firestore-facing behavior belongs in `SessionService` and related services already used by session screens.

---

## Complexity Tracking

No constitution violations require justification.

---

## Out-of-Scope Backlog

- Backlog item: Non-session social redesign is intentionally out of scope for this slice; broader friend, follower, profile, or social discovery changes should be planned as a separate feature.

---

## Phase 0: Research

**Status**: COMPLETE - see [research.md](research.md)

Key decisions:

1. Keep paired sessions one-to-one and reject current group-invite behavior for this feature.
2. Model bot friend as a synthetic partner inside the paired session domain, not as a normal social account.
3. Use Firestore-backed invitation state with a 30-second expiry and in-app notification/dialog presentation.
4. Keep matching gym sessions turn-based; run mixed workout-type sessions in parallel under one shared clock.
5. Preserve per-participant plan and history ownership to prevent invited-user modifications from changing the host plan.

---

## Phase 1: Design & Contracts

**Status**: COMPLETE - see [data-model.md](data-model.md), [contracts/openapi.yaml](contracts/openapi.yaml), and [quickstart.md](quickstart.md)

### Design Model

- `BotFriend`: built-in synthetic partner available to every user.
- `WorkoutInvitation`: invite lifecycle with mutual-follow/block eligibility and 30-second expiry.
- `SharedSession`: exactly two participants, shared clock, and session mode derived from participant workout types.
- `ParticipantPlan`: per-user owned plan with source, confirmation state, and workout type.
- `ParticipantProgress`: live per-user progress mapped to workout-type-specific metrics.

### Interface Contracts

`contracts/openapi.yaml` documents service-level contracts for session creation, bot session start, invite response, plan submission, session start, progress streaming, and completion. The contracts are descriptive for implementation planning and acceptance testing; the Flutter app may satisfy them through service methods rather than public HTTP endpoints.

### Implementation Order For /speckit.tasks

1. Foundation: paired session domain contract, one-to-one participant enforcement, invite eligibility, invite expiry, and telemetry events.
2. US1: bot friend selection and fixed gym simulation.
3. US2: real friend invite dialog, accept/decline/expiry states, and blocked/mutual-follow rejection.
4. US3: host plan completion, invited same-gym plan copy/review, personal modifications, and readiness gate.
5. US4: mixed workout-type setup, parallel shared clock, type-specific progress display, and per-user history.
6. Evidence: unit/widget/integration tests, quickstart manual checks, rollback verification, and analytics review.

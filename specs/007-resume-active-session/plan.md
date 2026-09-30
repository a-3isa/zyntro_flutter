# Implementation Plan: Resume Active Session on App Re-entry

**Branch**: `007-resume-active-session` | **Date**: 2026-08-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-resume-active-session/spec.md`

## Summary

A member who force-closes the app mid-workout currently loses the session outright: the session room
terminates it on `AppLifecycleState.detached`. This feature removes that termination, keeps the
session alive server-side, and returns the member to it on the next cold start — directly when the
session is warm, behind a continue-or-discard prompt when it has gone quiet. Sessions that nobody
returns to expire after 3 hours via a scheduled Cloud Function.

Four pieces of work: strip the two client-side termination paths, add per-member termination and
activity/occupancy timestamps to the session document, add a startup resume decision to the existing
`GoRouter` redirect chain, and add a scheduled expiry function modelled on the deployed
`expireStalePairedInvites`.

## Technical Context

**Language/Version**: Dart 3.x (Flutter), Node.js 20 (Cloud Functions)
**Primary Dependencies**: Flutter, Riverpod, GoRouter, cloud_firestore, firebase-functions v2, rxdart
**Storage**: Cloud Firestore — `sessions/{id}`, `sessions/{id}/presence/{userId}`, `sessions/{id}/events/{eventId}`
**Testing**: `flutter test` (unit + widget) under `test/features/session/` and `test/services/`; emulator-backed rules tests under `test/rules/` via `npm test`
**Target Platform**: Android and iOS
**Project Type**: Mobile app + Firebase backend
**Performance Goals**: Resume decision resolved inside the existing splash hold; member on the session screen within 2s of the app becoming usable (SC-002)
**Constraints**: Cold-start-only decision; no added splash-frame flash (FR-015); must work from cache offline (FR-012); expiry must not depend on any client running (A-009)
**Scale/Scope**: 8 Flutter files modified, 4 added; 11 test files added; 1 Cloud Function added; 2 composite indexes; 2 rules changes (per-member termination + the runtime flag document); 1 Firestore config document

## Constitution Check

*GATE: checked before Phase 0 research, re-checked after Phase 1 design.*

### Pre-design

| Principle | Assessment | Verdict |
|-----------|------------|---------|
| I. Feature-Slice Scope Discipline | One domain: session resume. Out-of-scope items listed in the spec. | PASS |
| II. Evidence-First Cutover | Regression evidence required for resume, prompt, expiry, and per-member terminate before cutover. No legacy removal beyond the two termination paths this feature replaces. | PASS |
| III. Security and Access Integrity | Feature reads sessions the member participates in; existing rules already gate reads on `hasParticipant`. Rules change needed for `endedParticipants`. | PASS — with the rules task below |
| IV. Operational Safety and Reversibility | Kill switch (R10) and four telemetry events (R9) specified before cutover. | PASS |
| V. Independent Deliverability | Three prioritized stories; foundational work isolated in a Phase 0 slice. | PASS |

### Post-design re-check

| Principle | Assessment | Verdict |
|-----------|------------|---------|
| I. Feature-Slice Scope Discipline | Design added per-member termination, which the spec had assumed pre-existing. Author confirmed in scope 2026-08-05; logged in Complexity Tracking. | PASS |
| II. Evidence-First Cutover | Contracts define the resume decision as a pure function over session state, so every branch is unit-testable without Firestore. | PASS |
| III. Security and Access Integrity | `endedParticipants` must be writable only by the member adding their own id; the flag document must be client-write-denied; expiry writes go through admin privileges in the Function, bypassing rules by design. | PASS |
| IV. Operational Safety and Reversibility | Confirmed expiry stays active with the kill switch off, so disabling resume cannot leak live sessions. | PASS |
| V. Independent Deliverability | US1 ships alone and is demonstrable; US2 and US3 layer on without modifying US1's decision path. | PASS |

### Post-analysis re-check (2026-08-05)

Cross-artifact analysis found four constitution violations, all sharing one root cause: every
mandated **pre-cutover** gate had been scheduled in the final polish phase, which by definition runs
after cutover. Resolved as follows.

| Was | Now | Principle |
|-----|-----|-----------|
| Rollback rehearsal in Phase 6, after MVP ship | Moved into Phase 3, gating the MVP ship | IV |
| Telemetry verification in Phase 6 | Moved into Phase 3, beside the events it verifies | IV |
| Security-rules verification in Phase 6 | Moved into Phase 2, beside the rules change | III |
| Kill switch not actually flippable without a release | Firestore-backed flag (Complexity Tracking) | IV |
| Legacy removal (termination-on-close, inactivity timer) landing before any cutover evidence | Foundational removals now explicitly gated on US1 evidence being green | II |

**Constitution II note on the legacy removals**: T009/T010 delete the only paths that currently close
a session, and they must land with the expiry Function to avoid leaking sessions — so they cannot be
deferred until after US1 ships. The resolution is a merge gate rather than a reorder: the branch does
not merge until US1's tests pass, so removal and evidence arrive together. Recorded here as an
explicit, bounded exception rather than a silent one.

## Project Structure

### Documentation (this feature)

```text
specs/007-resume-active-session/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── resume-decision.md
│   └── session-lifecycle.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Created by /speckit-tasks, not here
```

### Source Code (repository root)

```text
lib/
├── app/navigation/
│   └── app_router.dart                          # MODIFY — resume branch in redirect chain
├── core/constants/
│   └── feature_flags.dart                       # MODIFY — Firestore-backed resume flag provider
├── features/session/
│   ├── domain/
│   │   ├── resume_decision.dart                 # ADD — decision type + pure resolver
│   │   └── turn_eligibility.dart                # ADD — canHoldTurn predicate
│   └── presentation/
│       ├── session_room_page.dart               # MODIFY — drop termination-on-close and
│       │                                        #   the 10-min inactivity timer; add heartbeat;
│       │                                        #   solo override; partner-left dialog
│       └── widgets/
│           ├── resume_session_prompt.dart       # ADD — continue-or-discard prompt
│           ├── partner_left_dialog.dart         # ADD — finish-too or carry-on choice
│           ├── waiting_turn_screen.dart         # MODIFY — "away" + "left" avatar styles
│           ├── parallel_gym_view.dart           # MODIFY — "away" + "left" avatar styles
│           └── parallel_cardio_view.dart        # MODIFY — "away" + "left" avatar styles
├── services/
│   ├── session_service.dart                     # MODIFY — resumable-session query,
│   │                                            #   per-member terminate, activity stamping
│   ├── notification_service.dart                # MODIFY — partnerLeft type, tap routing,
│   │                                            #   launch-intent capture in init()
│   └── presence_service.dart                    # MODIFY — heartbeat + staleness helper
└── core/models/
    └── models.dart                              # MODIFY — new Session fields

functions/
└── index.js                                     # MODIFY — add expireStaleSessions

firebase/
├── firestore.rules                              # MODIFY — endedParticipants + config flag rules
└── firestore.indexes.json                       # MODIFY — resume query + expiry indexes

test/
├── services/
│   ├── session_expiry_test.dart                 # ADD — T013
│   ├── presence_service_test.dart               # ADD — T014
│   └── terminate_for_member_test.dart           # ADD — T040
└── features/session/
    ├── domain/
    │   ├── resume_decision_test.dart            # ADD — T015, every decision branch
    │   └── turn_eligibility_test.dart           # ADD — T029
    ├── presentation/
    │   ├── resume_redirect_test.dart            # ADD — T016, router integration
    │   ├── resume_preserves_work_test.dart      # ADD — T017
    │   ├── launch_intent_test.dart              # ADD — T018
    │   ├── resume_timing_test.dart              # ADD — T019, SC-002 budget
    │   ├── solo_when_partner_away_test.dart     # ADD — T030
    │   ├── partner_progress_test.dart           # ADD — T031
    │   ├── resume_prompt_test.dart              # ADD — T039
    │   └── partner_left_dialog_test.dart        # ADD — T041
    └── ...                                      # existing suites, unchanged
```

**Structure Decision**: Existing Flutter feature-slice layout under `lib/features/session/` plus the
shared `lib/services/` layer, with the Firebase side in `functions/` and `firebase/`. No new
top-level structure. Two new domain files — `resume_decision.dart` and `turn_eligibility.dart` — hold
the decision table and the turn predicate as pure functions, so both are testable without Firestore
or a widget tree.

## Implementation Phases

Phase numbering matches [tasks.md](./tasks.md) exactly. Task IDs are authoritative; this section is
the shape, not the checklist.

### Phase 1 — Setup

Indexes, the Firestore-backed flag document and its provider, analytics event constants.

### Phase 2 — Foundational (blocks everything)

New session fields and activity stamping; the `expireStaleSessions` scheduled Function; the security
rules for `endedParticipants` and the flag document, **verified in the same phase** (Constitution
III); removal of termination-on-close and the 10-minute inactivity timer; presence heartbeat and
staleness helper.

> [!warning] Two hard constraints in this phase
> The removals must land **with** the expiry Function, never before it, or live sessions leak with
> nothing to close them. And per Constitution II, the branch must not merge until US1's evidence is
> green — removal and evidence arrive together.

### Phase 3 — US1, direct resume (P1) 🎯 MVP

Pure resume decision and resolver; `findResumableSession`; launch-intent capture; the latched
cold-start decision in the router; kill-switch gating; telemetry **and its verification**; the
rollback rehearsal — both pre-cutover gates required by Constitution IV.

### Phase 4 — US2, shared-session correctness and continuing while a partner is away (P2)

`canHoldTurn`; turn handover skipping away participants; the solo-view override and its automatic
reversion; asymmetric flicker damping; the "away" avatar treatment; correct role resolution at mount.

### Phase 5 — US3, quiet prompt, expiry notice and partner departure (P3)

The continue-or-discard prompt; per-member termination; the `partner_left` notification type, its
tap routing and its stored delivery; the in-room dialog with once-per-departure semantics; the "left"
avatar treatment; the shared session-ended notice covering expired, cancelled and removed.

### Phase 6 — Polish

Quickstart validation on device, offline coordination with `006-offline-cache-sync`, the
abandonment-funnel instrumentation for the post-launch metric, analyze and full test run.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Per-member termination built here (research R3) | FR-008, FR-008a and the discard branch of FR-003b all write to it. `endSession` currently completes the session for every participant and logs workouts for all of them; no per-member path exists anywhere in `lib/`. | Dropping FR-008 would mean one member discarding a quiet session ends their partner's live workout — a correctness defect, not a simplification. **Author confirmed 2026-08-05**: build it. Terminating was always meant to end the session for the terminating member only; the remaining participant is notified their partner left and chooses whether to finish too or carry on. |
| Presence heartbeat added on top of existing presence (research R6) | A force-killed app leaves `status: 'online'` written forever, so the warm/quiet split would read every abandoned session as warm and skip the prompt entirely. | Trusting `status` alone inverts the agreed FR-003a behaviour. RTDB `onDisconnect` is the more robust fix but needs a second database provisioned for one flag; recorded as a follow-up. |
| Derived `expiresAt` field rather than evaluating FR-007's two conditions directly (research R4) | Firestore allows one range filter per query; the two conditions cannot both be expressed. | Two scheduled queries double reads and can double-write one doc per run. |
| Firestore-backed runtime flag, replacing this plan's earlier "remote-config-backed flag" (research R10) | The project has **no** runtime config mechanism: `firebase_remote_config` is absent, and `feature_flags.dart` is entirely compile-time `static bool get`. As originally written, rollback would have needed an app store release, failing Constitution IV. | Adding `firebase_remote_config` is the textbook fix but brings a new dependency and init path for one boolean; recorded as the upgrade if runtime flags become common. Leaving it compile-time was rejected outright — a multi-day store release is not a rollback path. |
| Launch intent captured in `NotificationService.init()` rather than sequenced against the router (research R11) | Cold-start notification navigation (`notification_service.dart:355-363`) and the resume redirect drive the same navigator from two unsequenced callbacks. `init()` already runs before `runApp()`, so capturing the fact is free. | Delaying notification navigation until the resume decision settles adds latency to the deep-link path and keeps the ordering assumption. Letting the redirect win and re-navigating produces the double navigation FR-015 forbids. |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `006-offline-cache-sync` not merged at ship time | FR-012 degrades — resume works from cache, pending-work badge missing | Ship anyway; badge lands with `006`. Not a blocker. |
| 15-minute expiry sweep leaves a window where an expired session is still `status: 'active'` | Member could be redirected into an expired session | Resume check evaluates `expiresAt` directly, never `status` alone (research R4) |
| Existing live sessions predate the new timestamp fields | Sweep cannot see them; they never expire | Treat a missing `expiresAt` as expired-on-read in the resume check; spec's Out of Scope already excludes retroactive expiry |
| Heartbeat cost on long sessions | One presence write per member per minute | Bounded and small; revisit only if it shows up in usage |

## Next

`/speckit-tasks` to generate the dependency-ordered task list.

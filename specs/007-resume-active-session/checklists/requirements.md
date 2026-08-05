# Specification Quality Checklist: Resume Active Session on App Re-entry

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-05
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Validation pass 1 found one issue: SC-007 originally read "drops measurably", which is not
  verifiable. Rewritten with a concrete target (20% reduction within 30 days). Re-validated: pass.
- Re-validated after the 2026-08-05 clarification session. All items still pass.
- The clarification session corrected a wrong premise in the original draft: it assumed a member
  could leave a live session without terminating it, and built a dismissal mechanism on top of that.
  No such state exists. FR-008/FR-008a, A-005, the Story 3 walk-away scenario, and SC-006 were all
  rewritten; the voided question is retained in the Clarifications log so the reversal is traceable.
- Two items grew beyond a pure read-only feature and were confirmed during planning:
  **occupancy tracking** (A-008 — presence already exists in `lib/services/presence_service.dart`,
  so this is a heartbeat and a staleness rule, not new infrastructure) and **member-independent
  expiry** (A-009 — a scheduled Cloud Function, modelled on the deployed `expireStalePairedInvites`).
- Planning also found that **per-member termination does not exist in the code** — `endSession`
  completes the session for every participant. The author confirmed on 2026-08-05 that this is in
  scope, together with a partner-left notification and a finish-or-continue choice for the remaining
  member (FR-008a, FR-008b). Out of Scope was corrected accordingly.
- FR-012 overlaps with the offline cache work on `006-offline-cache-sync`; T055 confirms whether that
  behaviour is already provided rather than rebuilt.

## Post-analysis validation (2026-08-05)

`/speckit-analyze` found 4 CRITICAL, 2 HIGH, 7 MEDIUM and 4 LOW issues. All resolved. Re-validated:
every checklist item above still passes.

**Root cause of all four CRITICALs**: every constitution-mandated *pre-cutover* gate had been
scheduled in the final polish phase, which by definition runs after cutover.

| Issue | Resolution |
|---|---|
| C1 rollback rehearsal after ship | Now T027, a US1 ship gate |
| C2 telemetry verification after ship | Now T028, a US1 ship gate |
| C3 rules verification after ship | Now T008, in the same phase as the rules change |
| C4 kill switch not runtime-flippable | Firestore `config/featureFlags` document. The project has **no** runtime config: `firebase_remote_config` absent, `feature_flags.dart` compile-time only (research R10) |
| I4 legacy removal before evidence | Explicit merge gate — branch does not merge until US1 evidence is green |
| G1 FR-010 signal never produced | Launch intent captured in `NotificationService.init()` before `runApp()` (research R11, T022) |
| G2 FR-005/FR-006 untested | T017, T031 |
| G3 partner-left tap routing | T047 |
| G5 SC-002 unmeasured | T019 |
| G6 SC-014 funnel uninstrumented | T056; SC-014 relabelled explicitly post-launch |
| G7 warm-while-prompting untested | Folded into T039 |
| A1/A2 unquantified timings | FR-021 (60s/90s), FR-021a (30s grace) |
| I1 misleading `[P]` on colliding tasks | `[P]` removed from both T037 and T050 |
| I2 success criteria misordered | Renumbered SC-001…SC-014 |
| I3 plan/tasks phase naming drift | plan.md now uses the tasks.md phase numbers |
| D1/D2 overlapping requirements | FR-013 now shares one notice component with FR-007b (T052); FR-008e explicitly refines FR-008a |

## Second analysis pass (2026-08-05)

Re-ran `/speckit-analyze` after the remediation above. **0 CRITICAL, 0 HIGH** — all 17 first-pass
issues verified resolved. Seven residual findings, now also resolved.

| Issue | Resolution |
|---|---|
| T1 FR-002 / FR-002a / FR-009 covered but never cited by ID | IDs added to T015 and T021 |
| T2 SC-001 / SC-005 / SC-006 / SC-007 same | IDs added to T015, T016, T040, T041 |
| U1 `turn_eligibility.dart` in tasks, absent from plan tree | Added to plan.md § Source Code |
| T3 T003, T007, T014, T045 carried no requirement reference | All four now cited |
| I5 plan tree listed 2 test files against 9 created | All 11 test files enumerated with their task IDs |
| I6 "wrap-up" / "recap" terminology | **Upgraded to a correctness fix — see below** |
| D3 FR-008b restated FR-008b-i | FR-008b trimmed to the two-route rule; delivery detail lives in 008b-i |

### I6 was not terminology drift

Querying the knowledge graph for `SessionPhase` showed the enum is
`{setup, live}` only (`lib/core/constants/constants.dart:280-282`). **There is no `recap` phase.**
The recap is a route, `/session/recap/:sessionId`, that a member is sent to after `endSession`.

The spec had described a three-stage lifecycle (setup → live → wrap-up) that does not exist, which
would have led to a phase check for a value no session ever holds. Corrected in spec.md (FR-002a
split into FR-002a/FR-002b, stages note added, Key Entities, two edge cases, SC-005, A-007),
data-model.md (state diagram now shows phase and status as two axes, not one chain),
contracts/resume-decision.md and tasks.md T015.

Note that behaviour was already correct — FR-002's `phase == live` and `status == active` conditions
excluded completed sessions regardless. The defect was in the description, and in a test that would
have asserted against a phase value that cannot occur.

**Final coverage**: 43 functional requirements (FR-002a split during this pass), 14 success criteria,
58 tasks. **100% ID traceability in both directions** — every FR and SC is cited by at least one
task, and every task cites at least one requirement, constitution gate, or design document. 13/13
release-gating success criteria covered; SC-014 is explicitly post-launch, with T056 providing its
instrumentation.

## Implementation status (2026-08-05)

57 of 58 tasks complete. **T054 (on-device validation) cannot be done here** — it needs a physical
handset to force-close the app from the recent-apps list. Everything it would check has automated
coverage; the device pass remains a manual pre-release step.

**Verification at completion**

| Gate | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | **988 passing, 0 failing** (8 pre-existing skips) |
| Firestore rules (emulator) | **90 passing, 0 failing** |

**Two defects the tests caught during implementation**, both of which would have shipped:

1. `isOwnTerminationUpdate()` was **vacuous**. `isParticipantSessionUpdate()` sits earlier in the
   rules OR-chain and only froze `hostId`, `invitedUserIds` and `invitationStatus` — so any
   participant could write their *partner's* uid into `endedParticipants` and end a workout that was
   not theirs. Fixed by freezing `endedParticipants` in that predicate.
2. The activity stamps were **rejected by the project's own rules**. `isGenericSelfJoinUpdate` and
   `isInviteAcceptUpdate` use `hasOnly([...])`, so adding `lastActivityAt`/`expiresAt` to those
   writes broke joining and invite acceptance until the allow-lists were extended.

**Deployment constraint**: T009/T010 removed the only client-side paths that close a session.
`expireStaleSessions` must deploy in the same release, or live sessions leak with nothing to close
them.

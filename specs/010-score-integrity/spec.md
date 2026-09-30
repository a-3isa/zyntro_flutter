# Feature Specification: Score integrity (phase 1)

**Feature Branch**: `010-score-integrity`  
**Created**: 2026-09-17  
**Status**: Implementing  
**Input**: Close **Z-DATA-001** phase 1 — deny client `workoutScore`/streak writes; stub CF grant; hide leaderboard until server authority (roadmap `L start`).

## User Scenarios & Testing

### User Story 1 - Clients cannot inflate scores (P1)

As a malicious client, I cannot update my own `workoutScore`, streaks, or related counters on `users/{uid}`.

**Acceptance**: Emulator rules deny owner updates that touch integrity fields.

### User Story 2 - Session end still completes (P1)

As a member ending a session, completion (session status, finish event, own workout log) succeeds without writing score/streak/PR fields.

### User Story 3 - Leaderboard gated (P2)

Friends/global leaderboard UI shows a temporary unavailable state while scores are not server-authoritative.

### User Story 4 - Server stub exists (P2)

Cloud Functions exports `applySessionScore` (callable/HTTP stub) documenting the future grant path; Admin SDK only.

## Requirements

- **FR-001**: Integrity fields on `users`: `workoutScore`, `totalWorkouts`, `buddyWorkouts`, `currentStreak`, `longestStreak`, `lastWorkoutDate`, `weeklyWorkouts`, `weekStartDate` — client create/update denied (same pattern as moderator flags).
- **FR-002**: `users/{uid}/stats/**` writes denied for clients (Admin/CF only).
- **FR-003**: `SessionService.endSession` stops writing integrity fields and PR docs; still computes score locally for recap UX.
- **FR-004**: Workout create requires `userId == auth.uid`; endSession only logs the caller's workout.
- **FR-005**: `User.toFirestore` omits integrity + privileged fields.
- **FR-006**: Leaderboard providers/UI return unavailable when `kServerScoresLive == false`.
- **FR-007**: Stub CF `applySessionScore` returns unimplemented; no client grant path.

## Success Criteria

- **SC-001**: Rules emulator: owner score inflate → fail.
- **SC-002**: `session_service_test`: endSession does not batch-update user score fields.
- **SC-003**: Grep: no client `'workoutScore':` writes under services except reads/models.
- **SC-004**: Rules deployed to zynrto after green tests.

## Out of scope (phase 2)

Full CF port of `computeWorkoutScore` / streak advance; re-enable leaderboard; payment grant CF.

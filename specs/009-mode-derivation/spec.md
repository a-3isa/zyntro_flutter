# Feature Specification: Session mode derivation

**Feature Branch**: `009-mode-derivation`  
**Created**: 2026-09-17  
**Status**: Draft → Implementing  
**Input**: Fix `Session.derivedMode` so same-type cardio is parallel; stop persisting `sessions.mode`; unify helpers (**Z-RT-001**, **Z-DATA-002**).

## User Scenarios & Testing

### User Story 1 - Cardio+cardio is parallel (P1)

As two members both doing running (or any non-gym same type), we train in **parallel** UI, not turn-based.

**Acceptance**:
1. Given both participantTypes are `running` (or other non-gym), When the room reads `derivedMode`, Then it is `parallel`.
2. Given both are `gym`, When derived, Then `turnBased`.
3. Given mixed types, Then `parallel`.

### User Story 2 - One derivation source of truth (P1)

`Session.derivedMode` and `SessionService.derivePairedSessionMode` always agree.

### User Story 3 - Mode is not stored (P2)

Session writes no longer set `sessions.mode`; rules no longer allow clients to mutate `mode` on live updates.

## Requirements

- **FR-001**: Turn-based iff every participant type is gym (and at least one type present); otherwise parallel (including empty → parallel for safety, or turnBased for solo gym-only — match service: empty types → parallel via `types.length == 1` false).
- **FR-002**: Single pure helper used by model getter and service.
- **FR-003**: Remove `mode` from session create/go-live/sharedClock field maps.
- **FR-004**: Remove `mode` from `participantLiveKeys` and invite transition allowlists in rules.
- **FR-005**: Unit tests cover gym/gym, running/running, gym/running, empty.

## Success Criteria

- **SC-001**: `running`+`running` → parallel in model and service tests.
- **SC-002**: Grep: no `'mode':` writes under session batch/set/update paths in `session_service.dart` (analytics payload mode OK).
- **SC-003**: Rules contract updated; emulator suite still green.

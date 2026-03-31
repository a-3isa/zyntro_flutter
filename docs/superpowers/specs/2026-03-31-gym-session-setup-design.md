# Gym Session Setup Flow Design

## Summary

Add a pre-start setup flow for gym sessions so the host defines the initial exercise list and planned set counts before the live session begins. Invited participants receive that host plan as a starting point, but each participant can edit their own copy without affecting anyone else. The live session starts only after each participant marks themselves ready. During the live session, participants log weight and reps set-by-set instead of planning them up front.

## Goals

- Let the host create the initial gym workout structure before the session goes live.
- Give each participant an independent editable copy of the host plan.
- Require explicit readiness before the live room starts.
- Keep set execution separate from set planning.
- Preserve the current cardio and non-gym flow.

## Non-Goals

- Shared collaborative editing of one master plan after the host publishes it.
- Reworking the session recap format for non-gym workouts.
- Full exercise-programming features such as supersets, rest timers, or notes.

## Product Behavior

### Session Creation

- When the selected workout type is `WorkoutType.gym`, pressing the start button creates the session and routes to a dedicated gym setup screen instead of the live room.
- The session remains `active` for compatibility with existing active-session checks, but gains a new `phase` field:
  - `setup`
  - `live`
- Solo gym sessions also use the setup screen. The host can define their plan and tap `Ready` to enter the live room immediately.
- Non-gym sessions continue to route directly to the current live room flow.

### Host Setup Experience

- The host lands on a gym setup page after session creation.
- The page lets the host build an ordered list of exercises.
- Each exercise includes:
  - `name`
  - `plannedSets`
- The host can add, remove, reorder, and edit exercises before marking ready.
- Once the host marks ready, their plan is locked unless they explicitly switch back to an edit state before the session moves to `live`.

### Participant Setup Experience

- Invited users who open the gym session during the setup phase see the host plan as their starting draft.
- The first time a participant enters setup, the app creates a personal copy of the host plan for that participant.
- Participants can change exercise names, remove exercises, add exercises, reorder items, and adjust planned set counts.
- Participant edits affect only that participant's personal plan and never overwrite the host plan or other participants' plans.

### Readiness and Session Start

- Each participant has an individual `isReady` flag.
- The setup screen shows readiness state for everyone currently in the session.
- The session moves from `phase=setup` to `phase=live` only when every joined participant is ready.
- When the phase becomes `live`, users navigate into the existing live session room.
- If a new invited participant joins before `phase=live`, they receive a personal copy of the host plan and must also mark ready before the session starts.

### Live Gym Session Experience

- The live room no longer asks gym users to define exercises and set counts from scratch.
- Instead, the room loads the participant's personal planned exercise list.
- The room should focus on execution:
  - choose the current exercise from the participant's plan
  - log one completed set at a time
  - enter `weight` and `reps` only when a set is finished
- Planned set count is treated as a target for progress display, not as pre-filled completed data.
- Completed sets accumulate into the existing local exercise summary and session analytics.

## Data Design

### Session Document

Add fields to the existing `sessions/{sessionId}` document:

- `phase: 'setup' | 'live'`
- `setupUpdatedAt`

The existing `status` field remains unchanged and continues to represent overall session lifecycle such as `active`, `paused`, and `completed`.

### Session Plan Subcollection

Add `sessions/{sessionId}/plans/{userId}` documents for personal gym plans.

Document shape:

- `userId`
- `source: 'host_template' | 'personal'`
- `isReady`
- `exercises`
- `createdAt`
- `updatedAt`

Each exercise entry:

- `id`
- `name`
- `plannedSets`
- `order`

The host plan document is the canonical template used to seed participant copies. After a participant copy is created, it is independent.

### Model Changes

Add lightweight planning models distinct from completed-set models:

- `PlannedExercise`
- `GymSessionPlan`

Do not overload the existing `Exercise` and `SetData` models with planning-only state. Those models currently represent completed session logging and should keep that responsibility.

## App Structure

### New Screen

Add a dedicated page for gym setup, for example:

- `lib/features/session/presentation/gym_session_setup_page.dart`

Responsibilities:

- load session and plan data
- create or hydrate personal plan documents
- manage ready state
- show participant readiness
- transition to live room when the session phase changes

### Routing

Add a route for the setup page, for example:

- `/session/setup/:sessionId`

Routing rules:

- `StartSessionPage` routes gym sessions to setup.
- Non-gym sessions still route to `/session/room/:sessionId`.
- If a gym session is already `phase=live`, opening its setup link should redirect to the live room.

### Service Layer

Extend `SessionService` with gym-setup specific methods:

- create gym session with `phase=setup`
- save host template plan
- create participant plan from host template
- save personal plan
- set participant ready state
- start live phase when all joined participants are ready
- listen to personal plan
- listen to participant readiness

Use Firestore transactions or batched writes when promoting the session from `setup` to `live` so the phase transition is atomic.

## Detailed Flow

### Host Starts a Gym Session

1. User selects `Gym` and taps start.
2. App creates the session with:
   - `status=active`
   - `phase=setup`
3. App navigates the host to the setup page.
4. Host creates the initial exercise list and planned sets.
5. Host taps `Ready`.
6. The host plan is saved and host readiness becomes `true`.
7. If all joined participants are ready, the session transitions to `phase=live`.

### Invited User Joins During Setup

1. Invited user opens the session.
2. App joins them to the session participant list if needed.
3. App checks for `plans/{userId}`.
4. If no personal plan exists, the app clones the host template into that document.
5. User edits their personal plan if desired.
6. User taps `Ready`.
7. When every joined participant is ready, the session becomes live.

### Logging During Live Session

1. Gym live room loads the participant's personal plan.
2. User selects the exercise they are currently performing.
3. User completes a set.
4. User enters weight and reps for that completed set.
5. The app logs the set with the current exercise name using the existing session event flow.

## Error Handling

- If the host has not created at least one exercise with at least one planned set, the host cannot mark ready.
- If a participant plan cannot be cloned from the host template, the setup page shows a retry state instead of navigating to live mode.
- If readiness updates fail, keep the user on the setup page and surface a snackbar with retry guidance.
- If the session phase changes to `live` while someone is still on setup, the page should redirect automatically into the live room.
- If a participant loses connectivity during setup, local edits should remain in the form until save succeeds, but the authoritative ready state remains server-backed.

## UI Notes

- Reuse the existing premium visual language from the session feature.
- Show a clear distinction between:
  - planned set count during setup
  - completed set count during the live session
- Setup should visually communicate:
  - whose plan is being edited
  - which participants are ready
  - whether the session is waiting on other people

## Testing Strategy

### Unit Tests

- plan model serialization and deserialization
- cloning host plan into a participant plan
- readiness aggregation logic
- promotion from `setup` to `live` only when all joined participants are ready

### Widget Tests

- gym start button routes to setup instead of live room
- host can add exercises and planned set counts
- participant sees host template as initial data
- participant edits do not affect host data
- ready button is disabled until the plan is valid

### Integration Coverage

- host creates a gym session, defines a plan, and reaches setup phase
- invitee joins, receives copied plan, edits their own plan, and marks ready
- once all joined participants are ready, both users land in the live room
- live room logs weight and reps against planned exercises

## Implementation Boundaries

- Keep the new planning logic additive so current non-gym sessions keep working without migration risk.
- Keep planning models and completed-set models separate.
- Avoid large-scale refactoring of `SessionRoomPage`; only extract the gym-specific live input behavior needed to consume planned exercises.

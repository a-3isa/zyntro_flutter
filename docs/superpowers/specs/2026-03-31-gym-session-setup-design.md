# Gym Session Flow And Session Theme Migration Design

## Summary

Migrate gym sessions from the current "start immediately and log freely" flow into a staged experience inspired by the approved Figma prototypes. The host defines an initial exercise plan and planned set counts by selecting from the exercise catalog, each participant receives a private editable copy, the session waits for everyone to mark themselves ready, and the live room shifts into guided set execution where reps and weight are entered only after a set is completed.

At the same time, update the session experience to use the approved Figma visual direction: deep navy surfaces, neon-green primary actions, and cleaner muted text instead of the current zinc-plus-purple session styling.

## Goals

- Align gym session behavior with the approved prototype flow while keeping the app's existing real session infrastructure.
- Add a pre-live gym setup phase with host-authored workout structure.
- Replace routine free-text exercise entry with exercise selection from the app's exercise database, while allowing a manual fallback when the needed exercise is missing.
- Give every participant an independent editable workout plan derived from the host template.
- Gate the live session behind explicit readiness from all joined participants.
- Change gym logging so planned sets are configured before the workout, while reps and weight are logged after each finished set.
- Apply the approved Figma navy and neon-green theme to the session journey.
- Preserve the current non-gym session flow.

## Non-Goals

- Rebuilding every prototype screen as a one-to-one Flutter route.
- Changing cardio or other non-gym session behavior in this project.
- Adding advanced workout-programming concepts such as supersets, timers, notes, or rest prescriptions.
- Performing a full-app visual redesign outside the session experience in this iteration.
- Creating a complex persisted backend state machine for every live room micro-state.

## Product Direction

### Source Of Truth

- The approved Figma prototypes are the source of truth for gym session behavior and visual tone.
- The existing Flutter app remains the source of truth for how sessions are created, joined, listened to, and stored.
- The target implementation is a merge of both:
  - prototype-driven gym UX
  - existing session backend and real-time architecture

### Gym Session Journey

For `WorkoutType.gym`, the session journey becomes:

1. Start session
2. Host selects exercises from the exercise database and defines planned set counts, with a manual fallback for missing exercises
3. Invited participants receive that list as their own editable starting draft
4. Everyone reviews their personal plan and taps `Ready`
5. The session transitions from `setup` to `live`
6. The live room guides exercise execution one set at a time
7. Reps and weight are captured only after a set is finished
8. When it is not the current user's turn, the room shifts into a partner watch or hype state instead of showing the same generic logging form

### Non-Gym Sessions

- Non-gym sessions continue to use the current start-to-room flow.
- This migration must be additive so existing cardio and general session behavior keeps working.

## Session Architecture

### Screen Strategy

Use three Flutter screens for the gym flow instead of recreating every prototype screen literally:

1. `StartSessionPage`
2. `GymSessionSetupPage`
3. `SessionRoomPage`

This keeps routing manageable while still delivering the important behavior from the prototypes.

### StartSessionPage

- Keep the current start experience as the entry point.
- When the selected type is `WorkoutType.gym`, pressing start creates a session in a setup phase and routes to the new setup page instead of directly to the room.
- For non-gym types, keep the current route to the live room.

### GymSessionSetupPage

This page merges the prototype setup steps into a guided setup experience with clear sections:

- exercise selection and ordering
- searchable exercise-database picker
- manual custom-exercise fallback when search does not find a match
- planned set counts
- personal plan review
- readiness visibility for all participants
- `Ready` action

Responsibilities:

- load session and participant data
- create or hydrate the current user's plan
- show the host template as the basis for participant plans
- let the user add exercises primarily from the catalog, with an explicit custom fallback
- save edits to the current user's personal plan only
- display participant readiness
- transition to the live room when the session phase becomes `live`

### SessionRoomPage For Gym

Keep the existing room route, but change the gym experience from a form-first logger into a guided live workout screen.

The room should show:

- active exercise
- current set number versus planned set count
- clear primary action for `Start Set` or `Finish Set`
- post-set logging for reps and optional weight
- partner turn and hype state when the user is not the active athlete

The room should no longer ask gym users to build their workout structure from scratch.

## Data And State Design

### Session Document

Extend `sessions/{sessionId}` with:

- `phase: 'setup' | 'live'`
- `setupUpdatedAt`

The existing `status` field remains responsible for lifecycle states such as `active`, `paused`, and `completed`.

### Per-User Gym Plans

Add `sessions/{sessionId}/plans/{userId}` documents.

Document shape:

- `userId`
- `source: 'host_template' | 'personal'`
- `isReady`
- `exercises`
- `createdAt`
- `updatedAt`

Each exercise entry:

- `id`
- `sourceType: 'catalog' | 'custom'`
- `exerciseId`
- `name`
- `muscleGroup`
- `equipment`
- `plannedSets`
- `order`

Rules:

- the host plan is the seed template
- the first time another participant joins during setup, their personal plan is cloned from the host template
- after cloning, edits affect only that participant's plan

### Modeling Boundary

Introduce planning models that are distinct from live logging models:

- `PlannedExercise`
- `GymSessionPlan`

Do not overload the existing completed-set models with setup-phase concerns.

### Exercise Catalog Source

Use the existing catalog in `lib/core/data/gym_exercises.dart` as the initial exercise database for the gym session flow.

The setup UI should read from that source and expose:

- search by name
- browse by muscle group
- optional filtering by equipment

This keeps the design database-backed from the user's point of view without expanding scope into a new remote exercise service in this iteration.

### Missing Exercise Fallback

If a user cannot find the exercise they need in the catalog:

- the setup UI should offer an explicit `Add Custom Exercise` action
- the user can type the exercise name manually
- the custom exercise is stored in the plan with `sourceType = custom`
- custom exercises remain valid for setup, readiness, and live logging

Behavior rules:

- catalog selection is the default path
- manual entry is the fallback path
- if the host adds a custom exercise before others clone the template, that custom exercise is copied into participant starter plans
- if a participant adds a custom exercise to their own plan, it affects only their personal plan

### UI-Owned Live State

The UI should own transient live-training state such as:

- whether the current user is timing a set
- whether the reps input step is open
- whether the weight entry step is open
- whether the user is currently in a watch or hype state

Firestore should own only the durable shared state:

- session phase
- participants
- personal plans
- readiness

This keeps the backend model simpler and avoids an unnecessary fine-grained live state machine.

## Detailed Behavior

### Session Creation

- Starting a gym session creates the session with:
  - `status = active`
  - `phase = setup`
- Solo gym sessions also pass through setup. A solo user can define their plan and tap `Ready` to move themselves into the live room.

### Host Setup

- The host lands on the setup page immediately after session creation.
- The host can add exercises by selecting them from the exercise database.
- If the desired exercise is missing, the host can add it manually as a custom exercise.
- The host can remove and reorder selected exercises.
- The host sets planned set counts for each exercise.
- The host cannot mark ready until at least one exercise exists and every exercise has a valid planned set count.

### Participant Setup

- Invited users joining during setup see the host plan as their starting draft.
- On first load, if no plan exists for that participant, the app clones the host template into `plans/{userId}`.
- Participants can:
  - add exercises from the same exercise database
  - manually add a custom exercise if the catalog does not contain it
  - remove exercises
  - reorder exercises
  - change planned set counts
- Those edits affect only their personal plan.

### Readiness And Live Start

- Each participant has their own `isReady` flag.
- The setup screen shows who is ready and who is still editing or missing.
- The session moves from `setup` to `live` only when every joined participant is ready.
- The phase transition should be atomic.
- If the session becomes live while someone is still viewing setup, that page should redirect them into the room automatically.

### Live Gym Loop

The live gym room should follow this loop:

1. Load the current user's personal plan
2. Show the active exercise and current set progress
3. Let the user start the set
4. Let the user finish the set
5. After the set is finished, prompt for reps
6. Prompt for optional weight
7. Log the completed set through the existing session event flow
8. Advance to the next set or next exercise
9. If applicable, show the partner turn or hype state between turns

Planned set count remains a target and progress indicator, not pre-completed data.

The live room should log sets against the selected exercise's stable identity:

- catalog exercises use their catalog `exerciseId`
- custom exercises use their plan entry `id`

The UI and event text should still show the human-readable exercise name.

## Visual Design Direction

### Session Palette

Adopt the approved Figma session palette:

- `navy-900`: `#0A0E27`
- `navy-800`: `#151B3D`
- `navy-700`: `#1E2749`
- `neon-green`: `#39FF14`
- `neon-green-hover`: `#2EE00F`
- `gray-400`: `#8B8B98`
- `gray-300`: `#A0A0AC`

### Visual Intent

The session experience should feel like:

- deep navy performance surfaces
- bright, high-contrast action moments
- cleaner and more focused than the current zinc and purple treatment
- athletic and energetic rather than glossy or ornamental

### Rollout Scope

Apply the new palette first to the session journey:

- `StartSessionPage`
- `GymSessionSetupPage`
- `SessionRoomPage` gym mode

Update shared theme tokens in `app_theme.dart` where that can be done safely without forcing a risky full-app repaint in the same iteration.

### UI Notes

- Clearly distinguish planned set counts from completed sets.
- Do not use free-text as the default exercise-entry path in the gym setup flow.
- Prefer a searchable selection sheet or full-screen picker backed by the exercise catalog.
- Show `Add Custom Exercise` only as a clear fallback when search does not find the needed movement.
- Use the neon green for primary action states such as start, ready, and finish.
- Use navy surfaces and subtle elevation instead of the current near-black and purple-heavy feel.
- Keep participant readiness and active-athlete focus visually obvious.

## Routing And Services

### Routing

Add a dedicated setup route, for example:

- `/session/setup/:sessionId`

Rules:

- gym start routes to setup
- non-gym start routes to room
- opening a setup route for a live gym session redirects to the room

### SessionService Changes

Extend `SessionService` with gym-specific capabilities:

- create gym sessions with `phase = setup`
- save the host template plan
- create a participant plan from the host template
- save personal plan edits
- set participant ready state
- determine when all joined participants are ready
- promote the session atomically to `phase = live`
- listen to personal plans
- listen to readiness state

Use transactions or batched writes for setup-to-live promotion.

## Error Handling

- If the host plan is empty or invalid, keep `Ready` disabled.
- If a participant plan cannot be cloned, show a retry state on setup instead of silently failing.
- If readiness cannot be saved, keep the user on setup and show retry guidance.
- If the session reaches `live` while a user is still editing, redirect automatically.
- If network connectivity drops during setup, preserve local edits in the form until save succeeds.
- If a partner has not finished setup yet, make the waiting state explicit instead of leaving the user on an ambiguous loading view.

## Testing Strategy

### Unit Tests

- planning model serialization and deserialization
- host-template cloning into participant plans
- readiness aggregation logic
- atomic promotion from `setup` to `live`

### Widget Tests

- gym start routes to setup instead of room
- host can build and validate a plan
- host selects exercises from the catalog instead of typing them
- missing catalog exercises can be added through the custom fallback
- participants receive a host-derived starting plan
- participant edits do not mutate host data
- ready is disabled until the plan is valid
- gym room shows guided live controls instead of the old free-form input flow

### Integration Coverage

- host creates a gym session and lands in setup
- invitee joins and receives a private copy of the host plan
- invitee edits their plan without affecting the host
- all joined participants tap ready and both users transition into the room
- live room logs completed sets using post-set reps and weight entry

## Implementation Boundaries

- Keep the migration gym-specific and additive.
- Reuse the existing session backend architecture rather than inventing a parallel system.
- Prefer one new setup page and a targeted gym-room upgrade over a large routing explosion.
- Keep planning state separate from completed-set state.
- Keep the session-theme rollout focused on the session journey first.

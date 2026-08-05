# Feature Specification: Friend Workout Sessions

**Feature Branch**: `001-friend-workout-sessions`  
**Created**: 2026-05-27  
**Status**: Draft  
**Input**: User description: "i want to add a bot friend that every user has to simulate the session feature with fixed 7 sec set time and 8 reps and weight 80kg, ensure also that the invite friend feature is correctly implemented( the host send invitation, it appears as a pop up dialog to the other side when h accecpt it he joins the session and after the host finishes the workout excersices plan it presentd to the invited side to approve it or made modification to suit him without changing the plan for the host then submit then they both start the session in turns) this if the workout is gym, brainstorm and adjust this for every other type, take in mind that the invited person can choose other type rather than the host type in this sitiuation they both will shar time and every side will see the othre's progress dpending on each on type"

## Clarifications

### Session 2026-05-27

- Q: How should paired session timing work when participants choose different workout types? → A: Matching gym sessions are turn-based; mixed workout-type sessions run in parallel with one shared clock.
- Q: Which users are eligible to receive workout session invitations? → A: Only mutual follows who are not blocked can be invited.
- Q: How long should a workout session invitation remain pending before expiring? → A: Invitation expires after 30 seconds.
- Q: How many real participants should a paired workout session support? → A: One-to-one only: host plus one invited friend or one bot friend.
- Q: What planning flow should invited friends follow when they choose a different workout type than the host? → A: Same workout type reviews host plan; different workout type creates own plan directly.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Practice With Bot Friend (Priority: P1)

As a user, I can start or preview a paired workout session with a built-in bot friend so I can experience the session flow even when no real friend is available.

**Why this priority**: The bot friend provides a reliable baseline for testing and demonstrating the session experience without depending on another online user.

**Independent Test**: Can be fully tested by choosing the bot friend as the partner, starting a gym-style session, and confirming the bot completes turns using the fixed sample values.

**Acceptance Scenarios**:

1. **Given** a user is preparing a paired gym workout, **When** they choose the bot friend, **Then** the bot is added as the only session partner without requiring an invitation response.
2. **Given** a bot friend is participating in a gym session, **When** the bot takes a set turn, **Then** the bot uses 7 seconds set time, 8 reps, and 80 kg as its displayed effort values.
3. **Given** a bot friend is participating in a non-gym workout, **When** the session starts, **Then** the bot simulates progress using the workout type's defined non-gym defaults and keeps pace with the shared session time.

---

### User Story 2 - Invite And Join A Real Friend (Priority: P1)

As a host, I can invite one friend to a session, and the invited friend sees a timely pop-up invitation that lets them accept and join the session.

**Why this priority**: Real-time invitations are the core social behavior needed before users can complete paired workouts together.

**Independent Test**: Can be fully tested with two users by sending an invitation from one account and confirming the other account receives a pop-up, accepts it, and appears as the only invited participant in the host's session room.

**Acceptance Scenarios**:

1. **Given** the host selects an available friend, **When** the host sends a workout invitation, **Then** the invited friend receives a visible pop-up dialog with the host name and workout context.
2. **Given** the invited friend accepts the invitation, **When** the acceptance is confirmed, **Then** both users see each other as session participants in the same shared session.
3. **Given** the invited friend declines, dismisses, or does not respond within 30 seconds, **When** the host views the session room, **Then** the host sees a clear non-joining status and can invite again or continue another way.

---

### User Story 3 - Review Personal Workout Plan Before Starting (Priority: P1)

As an invited user who chooses the same gym workout type as the host, I can review the host's planned gym workout after the host finishes setting it up, approve it, or modify my own version without changing the host's plan.

**Why this priority**: Each participant may need different exercises, weights, reps, or workout type while still sharing a session experience.

**Independent Test**: Can be fully tested by having a host create a gym plan, inviting a friend, and confirming the friend can approve or personalize their plan before both start.

**Acceptance Scenarios**:

1. **Given** the invited friend has accepted a gym invitation and chooses the same gym workout type, **When** the host completes the workout exercise plan, **Then** the invited friend is shown the host plan for approval before the session starts.
2. **Given** the invited friend modifies exercises, reps, weight, order, or rest preferences, **When** they submit their version, **Then** the host's plan remains unchanged and each user sees their own plan.
3. **Given** both users have submitted or approved their plans, **When** the session begins, **Then** gym participants alternate turns and see the other participant's current turn status and progress.

---

### User Story 4 - Share Time Across Different Workout Types (Priority: P2)

As two participants, we can join the same session even when each person chooses a different workout type, sharing session time while each side sees progress in the other person's relevant workout format.

**Why this priority**: Friends may want to work out together socially even when one is lifting, another is doing cardio, mobility, bodyweight, or another supported activity.

**Independent Test**: Can be fully tested by having the host choose gym and the invited friend choose a different supported workout type, then starting the shared session and confirming synchronized time plus type-specific progress views.

**Acceptance Scenarios**:

1. **Given** the host and invited friend choose different workout types, **When** both confirm their personal plans, **Then** the session starts in parallel mode with one shared elapsed time and separate progress displays for each type.
2. **Given** the invited friend chooses a different workout type than the host, **When** they continue setup, **Then** they create their own plan directly instead of reviewing the host's workout plan.
3. **Given** one participant is doing gym and the other is doing a time-based workout, **When** the gym participant completes sets, **Then** the other participant sees set progress while the gym participant sees elapsed time or stage progress for the time-based workout.
4. **Given** one participant is doing cardio, distance, mobility, bodyweight, or another supported workout type, **When** they update their progress, **Then** the other participant sees progress in a clear type-appropriate summary.

### Edge Cases

- If the invited friend is offline or unable to receive the pop-up, the invitation remains pending for 30 seconds and the host sees the pending state.
- If the invited friend accepts after the 30-second invitation expires or after the host cancels, the friend sees that the invitation is no longer available.
- If either participant leaves before both plans are confirmed, the remaining participant can invite someone else, switch to the bot friend, or continue solo if supported.
- If one participant changes workout type before submitting their plan, their personal plan resets only where needed for the new type and does not affect the other participant.
- If the invited friend changes to a different workout type than the host, the host plan is not shown for review and the invited friend creates a separate type-appropriate plan.
- If users have mismatched workout types, the session never forces one user's exercises, weights, reps, distance, or stages onto the other user.
- If a participant loses connection during an active session, the other participant sees the last known progress and a reconnecting or unavailable state.
- If the bot friend is selected for a non-gym session, bot progress uses the defined non-gym defaults for that workout type rather than the gym-specific 8 reps and 80 kg values.
- If a host attempts to invite another friend after a friend or bot partner is already selected, the system prevents adding a second partner and explains that paired sessions are one-to-one.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every user MUST have access to a built-in bot friend option for paired workout sessions.
- **FR-002**: The bot friend MUST be selectable anywhere a real friend can be selected as a session partner, unless the selected flow explicitly requires a real person.
- **FR-003**: In gym sessions, the bot friend MUST simulate each set with 7 seconds set time, 8 reps, and 80 kg.
- **FR-004**: For non-gym sessions, the bot friend MUST simulate progress using the selected workout type's defined sample progress defaults.
- **FR-005**: Each paired workout session MUST support exactly two participants: the host plus either one invited friend or one bot friend.
- **FR-006**: Hosts MUST be able to send a workout session invitation only to one selected real friend who is a mutual follow and has no block relationship with the host.
- **FR-007**: Invited friends MUST receive a visible pop-up invitation that identifies the host and summarizes the workout context.
- **FR-008**: Invited friends MUST be able to accept or decline the invitation from the invitation dialog.
- **FR-009**: Workout session invitations MUST expire automatically after 30 seconds if the invited friend has not accepted.
- **FR-010**: When an invitation is accepted, both users MUST appear as the only participants in the same shared session before workout start.
- **FR-011**: Hosts MUST complete and submit their workout plan before the invited friend is asked to choose their workout type and confirm their own plan.
- **FR-012**: Invited friends who choose the same gym workout type as the host MUST be able to approve the host's proposed gym plan as-is or create a personal modified version before starting.
- **FR-013**: Invited friends who choose a different workout type than the host MUST create their own type-appropriate plan directly without reviewing or modifying the host's plan.
- **FR-014**: Invited friend plan modifications MUST NOT change the host's workout plan.
- **FR-015**: Both participants MUST confirm their personal plan before a real friend session starts.
- **FR-016**: Gym sessions with matching gym workout types MUST support turn-based session flow where participants alternate active workout turns.
- **FR-017**: Sessions with different workout types MUST run in parallel mode with one common session clock while preserving each participant's own workout type, plan, and progress format.
- **FR-018**: Each participant MUST be able to see the other participant's current status and progress in a format appropriate to the other participant's workout type.
- **FR-019**: The system MUST distinguish at least these progress formats: gym sets/reps/weight, time-based duration or stage progress, distance or cardio progress, bodyweight round or exercise progress, and flexibility or mobility stage progress.
- **FR-020**: Participants MUST be able to start only after invitation status and plan confirmation states are complete.
- **FR-021**: The system MUST show clear states for pending invitation, accepted invitation, declined invitation, expired invitation, plan pending, plan submitted, active session, completed session, disconnected participant, and bot simulation.
- **FR-022**: The system MUST preserve separate session results for each participant so each user's workout history reflects their own plan, type, and performance.
- **FR-023**: Users MUST receive understandable feedback when an invitation cannot be delivered, accepted, or joined.

### Key Entities

- **Bot Friend**: A built-in simulated partner available to every user; includes display identity, supported workout behavior, and fixed gym simulation values.
- **Workout Invitation**: A request from host to invited friend; includes host, invitee, mutual-follow eligibility, block eligibility, workout context, invitation status, creation time, 30-second expiration state, and response.
- **Shared Session**: A social workout container shared by exactly two participants; includes host, partner, shared clock, invitation state, readiness state, active/completed status, and session outcome.
- **Participant Plan**: A participant-specific workout plan for a shared session; includes workout type, exercises or stages, targets, modifications, confirmation state, and ownership.
- **Participant Progress**: A participant-specific record of live and completed workout progress; includes current status, type-specific metrics, turn status where applicable, and completion state.

### Bot Friend Non-Gym Defaults

- **Running**: Bot progress shows elapsed time and distance, adding 0.02 km every 7 seconds.
- **Walking**: Bot progress shows elapsed time and distance, adding 0.01 km every 7 seconds.
- **Cycling**: Bot progress shows elapsed time and distance, adding 0.06 km every 7 seconds.
- **Swimming**: Bot progress shows completed lengths, adding 25 meters every 14 seconds.
- **Yoga**: Bot progress shows mobility stage completion, advancing one 30-second stage at a time.
- **HIIT**: Bot progress shows round completion using 20 seconds work and 10 seconds rest per round.
- **Sports**: Bot progress shows stage completion, advancing one 60-second activity stage at a time.
- **Other**: Bot progress shows elapsed time every 7 seconds and one generic stage completion every 60 seconds.

## Assumptions

- A "friend" means a mutual follow who has no block relationship with the host and is eligible to receive session invitations.
- Invitations should appear as an in-app pop-up when the invited friend is active; if not active, the invitation should be available when they return.
- Workout session invitations expire after 30 seconds if the invited friend does not accept.
- Gym workouts use turn-based flow because sets and reps map naturally to turns.
- Different workout types share time and social visibility through parallel progress rather than turn-taking.
- Invited friends review the host's plan only when they choose the same workout type; different workout types use independent plan creation.
- For non-gym workouts, progress is represented using the defined bot defaults and the most meaningful user-facing measure for that type.
- Bot friend behavior is primarily for session simulation and confidence testing, not for competitive ranking.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of users can start a bot friend gym session and see the bot's fixed 7-second, 8-rep, 80 kg set simulation within 30 seconds of choosing the bot.
- **SC-002**: 95% of real friend invitations show an invitation dialog to an active invited user within 5 seconds of the host sending the invitation and expire after 30 seconds without acceptance.
- **SC-003**: 90% of invited users can accept an invitation, review or modify their plan, and reach the ready-to-start state within 2 minutes.
- **SC-004**: 100% of invited-user plan modifications leave the host's original plan unchanged.
- **SC-005**: 95% of mixed workout-type sessions show a shared elapsed time and both participants' type-specific progress within 3 seconds of session start.
- **SC-006**: 90% of users in paired sessions can correctly identify whose turn or progress state is active without external help during usability testing.
- **SC-007**: Paired session completion records accurately reflect each participant's own workout type, plan, and progress in 100% of completed test sessions.

# Data Model: Friend Workout Sessions

## BotFriend

Represents the built-in simulated partner available to every user.

**Fields**
- `id`: stable reserved identifier for the synthetic partner.
- `displayName`: user-facing bot name.
- `isSynthetic`: always true.
- `supportedWorkoutTypes`: all current workout types.
- `gymSetDurationSeconds`: fixed value `7`.
- `gymReps`: fixed value `8`.
- `gymWeightKg`: fixed value `80`.
- `simulationProfile`: type-specific sample progress behavior for non-gym workouts.

**Validation Rules**
- Bot friend never requires invitation eligibility, follow status, block status, or an invitation response.
- A bot session still has exactly two participants: host plus bot friend.
- Bot friend cannot be used for flows explicitly requiring a real person.

**Relationships**
- Used as `SharedSession.partner` when `partnerKind = bot`.
- Produces `ParticipantProgress` events or display states like a normal partner.

## WorkoutInvitation

Represents a one-to-one invitation from host to one eligible real friend.

**Fields**
- `id`: unique invitation identifier.
- `sessionId`: owning shared session.
- `hostId`: inviting user.
- `inviteeId`: invited mutual follow.
- `hostWorkoutType`: host's selected workout type.
- `status`: `pending`, `accepted`, `declined`, `expired`, or `cancelled`.
- `createdAt`: invitation creation time.
- `expiresAt`: `createdAt + 30 seconds`.
- `respondedAt`: when accepted or declined.
- `eligibility`: records mutual-follow and no-block checks at creation.
- `deliveryStatus`: `queued`, `shown`, `failed`, or `unavailable`.

**Validation Rules**
- `inviteeId` must be a mutual follow of `hostId`.
- Neither user may have blocked the other.
- Exactly one invitee is allowed for a real friend session.
- Pending invitations expire after 30 seconds without acceptance.
- Acceptance after expiry or cancellation is rejected.

**State Transitions**
- `pending -> accepted`
- `pending -> declined`
- `pending -> expired`
- `pending -> cancelled`
- Terminal states: `accepted`, `declined`, `expired`, `cancelled`

## SharedSession

Represents the social workout container shared by exactly two participants.

**Fields**
- `id`: unique session identifier.
- `hostId`: user who created the session.
- `partnerId`: invited friend id or bot id.
- `partnerKind`: `realFriend` or `bot`.
- `participants`: exactly host plus partner.
- `hostWorkoutType`: host selected type.
- `participantTypes`: map of participant id to chosen workout type.
- `mode`: `turnBased` for matching gym sessions; `parallel` for mixed workout-type sessions.
- `sharedClockStartedAt`: shared session clock start time.
- `status`: `draft`, `inviting`, `setup`, `active`, `completed`, `cancelled`, or `abandoned`.
- `activeUserId`: set only for turn-based sessions.
- `invitationId`: present for real friend sessions.
- `createdAt`, `startedAt`, `endedAt`: lifecycle timestamps.

**Validation Rules**
- Participant count must be exactly two when session starts.
- Bot sessions skip invitation states and can move directly into setup or active state.
- Real friend sessions cannot start until invite is accepted and both participant plans are confirmed.
- Mixed workout-type sessions always run in parallel mode.
- Matching gym sessions always run in turn-based mode.

**State Transitions**
- Bot: `draft -> setup -> active -> completed`
- Real friend: `draft -> inviting -> setup -> active -> completed`
- Failure paths: `inviting -> cancelled`, `inviting -> abandoned`, `setup -> abandoned`, `active -> completed`

## ParticipantPlan

Represents a participant-owned workout plan for a shared session.

**Fields**
- `sessionId`: owning shared session.
- `userId`: plan owner.
- `workoutType`: chosen workout type.
- `source`: `hostTemplate`, `personalCopy`, or `personal`.
- `isReady`: whether the participant confirmed the plan.
- `exercises`: gym/bodyweight exercise entries when applicable.
- `stages`: time, distance, mobility, or sport stages when applicable.
- `targets`: participant-specific target values such as duration, distance, reps, sets, or rounds.
- `createdAt`, `updatedAt`: plan timestamps.

**Validation Rules**
- Each participant owns exactly one active plan per shared session.
- Invited same-gym participants may copy and modify the host plan.
- Invited mixed-type participants create a personal type-appropriate plan directly.
- Editing a participant plan never mutates another participant's plan.
- A real friend session cannot start until both participant plans have `isReady = true`.

## ParticipantProgress

Represents live and completed progress for one participant.

**Fields**
- `sessionId`: owning shared session.
- `userId`: participant whose progress this describes.
- `workoutType`: participant workout type.
- `status`: `waiting`, `active`, `resting`, `paused`, `disconnected`, `completed`.
- `turnStatus`: `activeTurn`, `waitingTurn`, or absent for parallel sessions.
- `sharedElapsedSeconds`: shared session clock value.
- `gymMetrics`: sets, reps, weight, current exercise, total volume.
- `timeMetrics`: elapsed duration, stage, remaining target time.
- `distanceMetrics`: distance, pace, speed, route summary when available.
- `roundMetrics`: rounds, exercises completed, work/rest interval.
- `mobilityMetrics`: stage, hold duration, completion.
- `updatedAt`: last progress update time.

**Validation Rules**
- Only metrics relevant to `workoutType` are required.
- Partner-facing progress must be readable without exposing unrelated private data.
- Disconnected users retain last known progress and a visible disconnected state.

## SessionCompletionRecord

Represents per-user completion history from a paired session.

**Fields**
- `sessionId`: source shared session.
- `userId`: owner of the workout history record.
- `partnerId`: paired partner id or bot id.
- `workoutType`: owner's workout type.
- `planSnapshot`: immutable copy of owner plan at completion.
- `progressSummary`: owner's type-specific completion metrics.
- `startedAt`, `endedAt`: workout timestamps.

**Validation Rules**
- One completion record is created per real participant.
- Each record uses the owner's plan and progress, not the partner's.
- Bot progress is not written as a normal user workout history record.


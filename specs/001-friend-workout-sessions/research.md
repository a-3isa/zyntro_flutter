# Phase 0 Research: Friend Workout Sessions

## Decision: Keep paired sessions one-to-one

**Rationale**: The clarified spec requires exactly two participants: host plus one invited friend or one bot friend. The existing start session flow has traces of multi-select invite behavior, but group sessions would expand turn order, progress layout, invite lifecycle, readiness gating, and test coverage beyond this slice.

**Alternatives considered**:
- Keep the current multi-select behavior up to 10 friends: rejected because it contradicts the clarified scope and creates unnecessary planning/test complexity.
- Support host plus up to 3 friends: rejected because the feature's value can be delivered with a simpler one-to-one model.

## Decision: Bot friend is a synthetic session partner, not a social user account

**Rationale**: The bot friend is available to every user for simulation and confidence testing. Treating it as a synthetic partner avoids needing follow/block eligibility, invitation delivery, profile privacy, or account lifecycle for the bot. Gym bot behavior is fixed at 7 seconds per set, 8 reps, and 80 kg; non-gym bot behavior uses type-appropriate sample progress.

**Alternatives considered**:
- Create a real user record for the bot: rejected because it introduces social graph, moderation, and privacy surface area without user value.
- Hard-code bot only in UI: rejected because session history, progress, and tests need a stable domain representation.

## Decision: Enforce invitation eligibility before session invite creation

**Rationale**: Invitations may only be sent to mutual follows with no block relationship. Enforcing this before invite creation prevents unauthorized pop-ups and reduces cleanup of invalid invitation records. This matches existing app concepts for mutual follows and blocked users.

**Alternatives considered**:
- Allow any follower/followee: rejected because it weakens privacy expectations.
- Allow any searchable user: rejected because it creates spam and harassment risk.
- Create invite then reject on accept: rejected because unauthorized users could still receive a disruptive dialog.

## Decision: Use a 30-second invite expiry state

**Rationale**: The spec requires invitations to expire after 30 seconds. Expiry should be represented in session/invitation state so both host and invited user see consistent pending, expired, declined, or accepted outcomes.

**Alternatives considered**:
- Pure client-side timer only: rejected because active screens could disagree after reconnect or app backgrounding.
- No expiry until host cancellation: rejected because hosts could be blocked waiting indefinitely.

## Decision: Same gym type is turn-based; mixed workout types are parallel

**Rationale**: Gym sets map naturally to alternating turns. Running, cycling, swimming, yoga, HIIT, walking, sports, and other activities map better to parallel progress under one shared clock. This preserves social presence without forcing mismatched activities into artificial set turns.

**Alternatives considered**:
- Turn-based for every workout type: rejected because time/distance/stage workouts would feel awkward.
- Host type controls the session mode: rejected because it would incorrectly impose the host's workout mechanics on the invited friend.
- Per-type pair matrix: rejected for this slice because it increases complexity without improving the clarified core behavior.

## Decision: Store and validate plans per participant

**Rationale**: The invited user may approve/adapt the host gym plan only when choosing the same gym type. If choosing another type, they create an independent type-appropriate plan directly. Per-user ownership prevents plan modifications from changing the host plan and supports accurate personal workout history.

**Alternatives considered**:
- Single shared plan document: rejected because it cannot support independent modifications.
- Host plan copied for all types: rejected because non-gym activities do not share gym exercise structure.

## Decision: Progress summaries should be type-specific but stream through one participant progress contract

**Rationale**: Session screens already aggregate event progress per participant. A common progress envelope with type-specific fields lets UI render gym sets/reps/weight, time/duration, distance/cardio, bodyweight rounds, or mobility stages while keeping the shared clock and partner visibility consistent.

**Alternatives considered**:
- Separate progress stream for each workout type: rejected because it fragments paired-session display and test coverage.
- Generic percentage only: rejected because it hides meaningful workout context.

## Decision: Add telemetry for invite and readiness failure points

**Rationale**: Constitution requires operational safety and rollback-trigger conditions. The critical points are invite creation rejection, invite delivery latency, invite acceptance/decline/expiry, plan readiness, session start, progress stream health, bot simulation start, and completion/history write.

**Alternatives considered**:
- Rely on debug logs only: rejected because debug output does not support production rollback decisions.
- Defer telemetry to a later slice: rejected because this feature changes access-sensitive social session behavior.


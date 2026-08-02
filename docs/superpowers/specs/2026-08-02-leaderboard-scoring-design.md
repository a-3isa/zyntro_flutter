# Leaderboard Scoring Design

## Goal

Replace the current flat `+10 points per completed workout` leaderboard score with a formula that rewards time spent, training with a real buddy, effort (sets/reps), and — the dominant factor — **genuine improvement over the user's own history**, without absolute lifting weight or speed creating an unfair advantage between users of different strength/fitness levels.

## Current state (what's being replaced)

- `lib/services/session_service.dart`'s `endSession()` increments `workoutScore` by a flat `10` on every completed session, ignoring duration, solo/buddy, sets/reps, and any notion of progress.
- `lib/services/user_service.dart`'s `updateWorkoutScore(userId, pointsToAdd)` is dead code — never called anywhere. It will be deleted; its role is absorbed into the new scoring logic.
- `lib/services/session_analytics_service.dart`'s `checkPersonalRecords(userId, exercises)` is also dead code — never called anywhere. It already writes to `users/{uid}/stats/prs`, a single document mapping `{exerciseNameLowercase: maxWeightEverUsed}`. It tracks raw max weight only (no rep-count normalization, so a 100kg×1 single and a 100kg×10 set register identically), which can't support this design's Epley-normalized, percentage-based progress math as-is. It will be deleted and its role absorbed into the new scoring logic, but its existing Firestore path (`users/{uid}/stats/prs`) is reused rather than replaced with a new one — see Data Model. Since it's dead code, no document has ever actually been written at that path in production, so redefining its value shape is free (no migration needed).
- `lib/services/leaderboard_service.dart` sorts by whatever `workoutScore` number is stored; it has no opinion on how that number is computed and needs no changes.

## Core invariant (non-negotiable)

**Absolute weight (strength) or absolute speed (cardio) must never directly affect a session's score relative to another user's.** Two users doing the identical exercise with identical sets/reps/duration but different absolute weights must score identically, regardless of who lifts more. This is achieved structurally, not by tuning:

- The **effort** term counts sets only — it never reads a weight or speed value.
- The **progress** term compares a user's performance only against **that same user's own history** (a percentage change), never against another user's numbers. Two different absolute weights that represent the same 0% (or same +X%) change relative to each person's own best produce the same progress score.

**Worked proof (from the requirements conversation):** Person A benches 50kg × 8 reps × 3 sets, matching their own prior best exactly. Person B benches 60kg × 8 reps × 3 sets, also matching their own prior best exactly. Effort score: identical (3 sets each, weight never read). Progress score: both 0% change vs. their own best → identical. **Total score: identical**, despite the 10kg gap. This exact scenario becomes a required test case (see Testing section).

## Formula

```
score = timePoints + buddyBonus + effortPoints + progressBonus
```

### 1. Time points

`min(sessionMinutes, 60) × 1` → **max 60 points**.

`sessionMinutes = session.endedAt.difference(session.startedAt).inMinutes`. Same formula for strength and cardio. Capped so leaving a session open and idle for hours earns nothing beyond a full hour.

### 2. Buddy bonus

`15` points if the session was paired with a **real human** partner (`session.partnerKind == PairedPartnerKind.realFriend`), else `0`.

A bot-paired session (`PairedPartnerKind.bot`) counts as **solo** for this bonus (confirmed decision) — only a real human partner earns it.

### 3. Effort points (small, deliberately weight/speed-blind)

- **Strength sessions** (`session.type == 'strength'`): `min(totalSetsThisSession, 20) × 2` → **max 40 points**. Counts sets only, from `SessionSummary.totalSets`. Never reads a weight value.
- **Cardio sessions** (`session.type == 'cardio'`): **0** — folded entirely into time points. No separate distance/speed-based effort term, because distance/speed covered is exactly the kind of "fitter person wins by default" metric this design avoids. Time capped at 60 min is effort enough for cardio.

### 4. Progress bonus (dominant term, relative-to-self)

This is the term that lets "improved a lot from a lower base" beat "strong/fast but flat" on the leaderboard.

**Strength**, per exercise attempted this session:
1. Compute the session's best set for that exercise using the Epley 1RM estimate: `estimate = weight × (1 + reps / 30)`, taking the max `estimate` across all sets logged for that exercise this session.
2. Compare against the user's **all-time personal best** `estimate` for that exact exercise (see Data Model below for where this is stored).
3. `pctImprovement = (todayEstimate − personalBestEstimate) / personalBestEstimate`, **floored at 0** (an off day never subtracts) and **capped at 0.20** (one data-entry typo can't blow up the score).
4. **First time ever doing this exercise** (no personal best exists yet): treat as a flat `pctImprovement = 0.05` (a modest guaranteed "improvement") rather than 0 or undefined — encourages trying new exercises without needing a fake baseline.
5. Average `pctImprovement` across every distinct exercise attempted this session (confirmed decision — not best-only, not summed).
6. `progressBonus = averagePctImprovement × 800` → e.g. a 10% average improvement = 80 points, the 20% cap = 160 points, the first-time-only floor = 40 points.

**Cardio**, per `activityType` (e.g. "running", "cycling") attempted this session — same mechanics, using **average speed (km/h)** instead of weight:
1. `todaySpeed = session.summary.averageSpeed` for that activity type this session.
2. Compare against the user's all-time personal best average speed for that same `activityType`.
3. Same floor (0%), same cap (20%), same first-time flat bonus (5%), same averaging-across-activity-types rule if a session somehow logs more than one (rare), same point multiplier (×800).

Speed, not distance, is deliberately the cardio progress metric — distance rewards raw endurance/fitness level (the cardio equivalent of absolute weight); speed-improvement rewards getting better, which is what the progress term exists to measure.

### Example totals

A capped-out single session: `60 (time) + 15 (buddy) + 40 (effort, strength) + 160 (progress, 20% cap) = 275`. Progress is ~58% of the maximum — the dominant term, as intended, without being the *only* term.

## Data model

**Reused, redefined: `users/{uid}/stats/prs`** (single document — the same path `checkPersonalRecords` already used, dead code being replaced, not a new path):

```
{
  strength: {
    "<exerciseNameLowercase>": { bestEstimate: number, achievedAt: Timestamp, sourceSessionId: string },
    ...
  },
  cardio: {
    "<activityType>": { bestEstimate: number, achievedAt: Timestamp, sourceSessionId: string },
    ...
  },
}
```

`bestEstimate` is the Epley estimate (strength) or average speed km/h (cardio) — replacing the old shape's raw `maxWeight` number, which couldn't support this design's rep-normalized, percentage-based math. One document per user (not a subcollection) matches the existing dead code's shape and keeps a whole user's PRs in a single read/write.

Rationale for a maintained record rather than scanning the `workouts` collection on every session-end: `workouts` already accumulates one document per participant per completed session with a full `summary`, but scanning all of a user's historical workouts for the max estimate on every session-end is O(sessions) and gets slower as a user's history grows. A maintained record is O(1) to read (one document) and O(1) to update, at the cost of a small amount of write complexity at session-end (read the one `stats/prs` doc, compare, merge-write updates alongside the score in the same batch).

**Existing, unchanged:** `Session.startedAt`/`endedAt`, `Session.partnerKind`, `SessionSummary.totalSets`, `SessionSummary.exercises` (`List<ExerciseSummary>`, each with `setDetails: List<SetSummary>` giving per-set `weight`/`reps`), `SessionSummary.averageSpeed`, `Session.type` (`'strength'`/`'cardio'`).

## Where scoring is computed

A new pure function, `computeWorkoutScore(...)`, in `lib/features/session/domain/workout_score.dart` (mirroring the existing `joint_post_draft.dart` pattern of pure, directly-unit-testable domain functions with no Firestore dependency). It takes the session, its summary, and a map of the user's current personal-best records (already read), and returns both the computed score and the list of any personal records that were just broken (so the caller can write the updates).

`lib/services/session_service.dart`'s `endSession()` calls it: before building the existing write batch, it reads the user's single `users/{uid}/stats/prs` document (one plain `.get()` — no transaction needed; a personal-record update losing a rare race is low-stakes, unlike the joint-post feature's consent guarantees), computes the score via the pure function, then adds the score increment and the merged `stats/prs` update to the same existing batch write. The dead `updateWorkoutScore` (`user_service.dart`) and `checkPersonalRecords` (`session_analytics_service.dart`) are both deleted — this fully replaces both of their intended roles with one coherent, actually-wired path.

## Out of scope / explicitly not doing

- No change to `leaderboard_service.dart` itself — it already just sorts by `workoutScore`.
- No anti-cheat/server-side verification of the score (a Cloud Function recomputing and verifying it). The existing flat `+10` system has the same client-trust model; this is a pre-existing acceptable-risk pattern for this app, not a new regression introduced by richer scoring. Worth revisiting later if leaderboard gaming becomes an actual problem, but not part of this design.
- No UI changes to show users a breakdown of their score (e.g. "you earned 40 for effort, 80 for progress"). Could be a good follow-up, not required for the scoring logic itself to ship.
- No retroactive recomputation of past sessions' scores — the new formula applies going forward only.

## Testing

- `computeWorkoutScore` is a pure function — fully unit-testable without Firestore, mirroring `joint_post_draft_test.dart`'s style.
- **Required test case**: the exact "identical sets/reps, different absolute weight → identical score" scenario from the Core Invariant section above, both at 0% and at some non-zero shared improvement percentage.
- Cap/floor boundary tests: negative raw pctImprovement floors to 0; a >20% raw improvement caps at 0.20; first-time-exercise flat bonus applies correctly; time caps at 60 minutes; effort caps at 20 sets.
- Multi-exercise averaging: a session with one exercise at 0% and another at 10% averages to 5%, not summed to 10% and not just the max.
- Bot-partner session scores identically to a solo session (no buddy bonus).
- Cardio parity tests mirroring the strength ones, using speed instead of weight.

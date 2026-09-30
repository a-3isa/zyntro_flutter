# Data Model: Database Exercise Picker

## ExerciseCatalogEntry

Shared exercise available to all authenticated users.

**Fields**
- `id`: stable catalog identifier.
- `name`: display name shown in picker and plans.
- `normalizedName`: normalized name used for case-insensitive search.
- `searchTokens`: searchable tokens for partial and typo-tolerant matching.
- `muscleGroup`: primary muscle group/category label.
- `equipment`: optional equipment labels.
- `secondaryMuscles`: optional secondary muscle labels.
- `description`: optional short help text.
- `tips`: optional coaching note.
- `isCompound`: optional compound/isolation flag.
- `isActive`: whether result should appear in user search.
- `createdAt`, `updatedAt`: catalog maintenance timestamps.

**Validation Rules**
- `id`, `name`, and `normalizedName` are required.
- `name` must not be blank.
- Searchable entries must have at least one `searchTokens` value.
- Only active entries appear in normal picker results.

## PersonalExerciseEntry

User-created exercise available immediately to the creating user.

**Fields**
- `id`: stable personal exercise identifier.
- `userId`: owner.
- `name`: user-entered display name.
- `normalizedName`: normalized name used for search.
- `searchTokens`: searchable tokens.
- `muscleGroup`: optional user-selected/category value.
- `equipment`: optional user-selected equipment value.
- `reviewSubmissionId`: optional linked review submission.
- `reviewStatus`: `pending`, `approved`, `rejected`, or `not_submitted`.
- `createdAt`, `updatedAt`: lifecycle timestamps.

**Validation Rules**
- `userId` must match the authenticated creator.
- `name` must not be blank.
- Personal entries are readable/searchable only by their owner.
- Custom exercise creation must be explicit from the picker empty/custom state.

## ExerciseReviewSubmission

Candidate custom exercise submitted for possible inclusion in the shared catalog.

**Fields**
- `id`: stable review submission identifier.
- `submittedBy`: user who created the custom exercise.
- `personalExerciseId`: linked personal exercise entry.
- `name`: submitted exercise name.
- `normalizedName`: normalized submitted name.
- `muscleGroup`: optional submitted category.
- `equipment`: optional submitted equipment.
- `status`: `pending`, `approved`, `rejected`, or `merged`.
- `reviewedBy`: optional reviewer/moderator user id.
- `reviewedAt`: optional review timestamp.
- `createdAt`, `updatedAt`: lifecycle timestamps.

**Validation Rules**
- Users may create submissions for their own personal exercises.
- Non-moderator users cannot approve, reject, merge, or alter another user's submission.
- Approved or merged submissions may create or link to an `ExerciseCatalogEntry`.

## SelectedExercise

Exercise chosen for a session plan or late-session remaining work.

**Fields**
- `id`: stable selected plan-entry identifier.
- `sourceType`: `catalog` or `custom`.
- `exerciseId`: shared catalog id when `sourceType` is `catalog`.
- `personalExerciseId`: personal exercise id when `sourceType` is `custom`.
- `name`: display name snapshot at selection time.
- `plannedSets`: set count chosen by the user.
- `order`: order within the user's plan.
- `muscleGroup`: optional display snapshot.
- `equipment`: optional display snapshot.

**Validation Rules**
- `plannedSets` must be between 1 and 20 inclusive.
- Catalog selections must include `exerciseId`.
- Custom selections must include enough identity to distinguish them from shared catalog entries.
- Late-session selections are planned remaining work until logged through normal set logging.

## SessionExercisePlan

Per-user ordered exercise plan for a gym session.

**Fields**
- `userId`: owner of the plan.
- `sessionId`: owning session.
- `source`: host template, personal, or personal copy.
- `isReady`: readiness state.
- `exercises`: ordered list of `SelectedExercise`.
- `updatedAt`: last modified time.

**Relationships**
- A session has one plan per participant.
- Plans may include both shared catalog selections and personal custom selections.
- Paired-session participants own separate plans; adding or editing one participant's exercises must not mutate the other participant's plan.

## State Transitions

```text
Catalog exercise selected
  -> SelectedExercise(sourceType: catalog)
  -> SessionExercisePlan updated
  -> Sets become completed only through set logging

No matching exercise found
  -> User explicitly creates custom exercise
  -> PersonalExerciseEntry created
  -> ExerciseReviewSubmission(status: pending) created
  -> SelectedExercise(sourceType: custom) added when confirmed

Late-session add
  -> SelectedExercise added to active plan as remaining work
  -> User logs each set
  -> Final summary includes logged sets only
```

# Quickstart: Database Exercise Picker

## Prerequisites

- Use branch `004-database-exercise-picker`.
- Run `flutter pub get` if dependencies are not installed.
- Ensure an authenticated test user exists for manual QA.
- Seed the shared exercise catalog with representative gym exercises before end-to-end QA.

## Catalog Seed Steps

These steps populate the Firestore `exerciseCatalog` collection from `lib/core/data/gym_exercises.dart`.

### 1. Seed via Firebase Console or CLI

For each `GymExercise` entry in `GymExercises.all` (75 exercises, 8 muscle groups), write a document to `exerciseCatalog/{id}` with these fields:

```json
{
  "id": "<exercise.id>",
  "name": "<exercise.name>",
  "normalizedName": "<exercise.name.toLowerCase()>",
  "searchTokens": ["<token1>", "<token2>"],
  "muscleGroup": "<exercise.muscleGroup.name>",
  "equipment": "<exercise.equipment.first.displayName or null>",
  "isActive": true,
  "createdAt": "<serverTimestamp>"
}
```

### 2. Seed via Dart Script (Recommended)

Run from the project root after setting `GOOGLE_APPLICATION_CREDENTIALS`:

```bash
dart run scripts/seed_exercise_catalog.dart
```

### 3. FR-013 Minimum-Coverage Checklist

Before cutover, verify:

- [ ] `exerciseCatalog` collection contains ≥ 40 documents with `isActive: true`
- [ ] At least 6 distinct `muscleGroup` values are present
- [ ] Muscle groups include: `chest`, `back`, `legs`, `shoulders`, `biceps`, `triceps`, `core`

### 4. Verification Command

```bash
# Count active catalog entries (requires Firebase CLI with project configured)
firebase firestore:query exerciseCatalog --filter "isActive==true" --count
```

The local seed data (`GymExercises.all`) contains 75 exercises across 8 muscle groups and already satisfies FR-013. It is used as the fallback when Firestore is unavailable.

## Scenario 1: Start-Session Database Selection

1. Open the gym start-session planning flow.
2. Tap "Add exercise".
3. Search for `bench` using mixed capitalization such as `BeNcH`.
4. Select a shared database result.
5. Set planned sets to a non-default value between 1 and 20.
6. Confirm.

**Expected evidence**
- The inline free-text add field is not used.
- Matching database result appears in under 1 second under normal app conditions.
- The plan shows the selected exercise and chosen set count.
- The selected plan entry preserves database identity.

## Scenario 2: Typo-Tolerant Search

1. Open the picker.
2. Search for a likely misspelling of a known exercise.
3. Review results.

**Expected evidence**
- Search ignores capitalization and reasonable spacing differences.
- Likely matches appear when the typo is close enough to a known exercise.
- Similar names show distinguishing details such as muscle group or equipment.

## Scenario 3: Custom Exercise Creation And Reuse

1. Open the picker.
2. Search for a name that does not exist.
3. Choose the custom exercise action.
4. Create the custom exercise.
5. Confirm it into the plan with a valid set count.
6. Open the picker again later as the same user and search for that custom exercise.

**Expected evidence**
- No-results state clearly offers custom creation.
- Custom exercise is added only after explicit user action.
- Custom entry is marked as custom in plan data.
- Custom entry is searchable for the creating user immediately.
- A review submission exists for possible shared database inclusion.

## Scenario 4: Late-Session Add

1. Start or resume a gym session.
2. Reach the session completion or late-add stage.
3. Tap "Add exercise".
4. Select a shared or custom exercise and choose a set count.
5. Confirm.
6. Finish only after logging the added exercise sets.

**Expected evidence**
- Same picker is used as start-session planning.
- Late-added exercise appears as planned remaining work.
- The selected set count does not appear as completed until each set is logged.
- Final summary includes only logged sets.

## Scenario 5: Set Count Validation

1. Open picker set selection.
2. Try to confirm fewer than 1 set.
3. Try to confirm more than 20 sets.
4. Confirm a valid value.

**Expected evidence**
- Invalid values are blocked in both start-session and late-session flows.
- Values from 1 to 20 are accepted.

## Scenario 6: Access And Rules

1. User A creates a custom exercise.
2. User B searches for User A's custom exercise.
3. User A searches for the same custom exercise.
4. A non-moderator attempts to approve or publish a review submission.

**Expected evidence**
- User B cannot see User A's personal custom exercise.
- User A can see and reuse their own custom exercise.
- Non-moderator review approval/publish is denied.
- Shared active catalog entries remain readable to authenticated users.

## SC-001 and SC-002 Manual QA Acceptance (T056)

### SC-001: Start-Session Exercise Add — Under 20 Seconds

**Acceptance criterion**: A user can add a database exercise to the start-session plan in under 20 seconds after tapping "Add exercise".

**Timed walkthrough**:

1. Open the app and navigate to start a gym session.
2. Start a stopwatch.
3. Tap "Add exercise".
4. Type a known exercise name (e.g., `Bench Press`).
5. Tap the result in the list.
6. Accept the default set count and tap "Confirm".
7. Stop the stopwatch.

**Pass condition**: Total elapsed time < 20 seconds. The selected exercise appears in the plan.

### SC-002: Search Results Appear Under 1 Second (Normal Network)

**Acceptance criterion**: Search results for a known exercise name appear in under 1 second under normal network conditions.

**Walkthrough**:

1. Open the exercise picker.
2. Observe any initial loading state.
3. Start a stopwatch.
4. Type a known exercise name (e.g., `Squat`).
5. Stop the stopwatch when results appear.

**Pass condition**: Results appear in < 1 second. If Firestore is unreachable, the fallback local catalog must appear within 2 seconds.

## Focused Verification Commands

```powershell
flutter test test/features/session/presentation/widgets/gym_exercise_picker_sheet_test.dart
flutter test test/features/session/presentation/start_session_page_test.dart
flutter test test/features/session/presentation/session_room_auth_contract_test.dart
flutter test test/services/exercise_catalog_service_test.dart
flutter test test/firebase/firestore_rules_contract_test.dart
```

Run broader `flutter test` before cutover.

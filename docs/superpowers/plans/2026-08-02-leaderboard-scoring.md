# Leaderboard Scoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat `+10 points per workout` leaderboard score with a formula rewarding time, a real-human buddy, sets/reps effort, and — the dominant factor — percentage improvement over the user's own history, structurally blind to absolute weight/speed.

**Architecture:** A new pure domain function (`computeWorkoutScore`) takes a session's known facts (duration, buddy type, session type, summary, current personal records) and returns a score plus any updated personal records — no Firestore dependency, fully unit-testable. `SessionService.endSession()` reads the user's single `users/{uid}/stats/prs` document, calls the pure function, and adds the score increment plus any updated PR fields to its existing batch write. Two dead methods that partially overlapped this role (`UserService.updateWorkoutScore`, `SessionAnalyticsService.checkPersonalRecords`) are deleted.

**Tech Stack:** Flutter, Cloud Firestore, mocktail (existing test convention in `session_service_test.dart` — do not introduce `fake_cloud_firestore` here, it would be inconsistent with this file's established mocking style).

## Global Constraints

- **Core invariant:** absolute weight/speed must never affect score relative to another user. Effort counts sets only (no weight/speed read). Progress compares a user only to their own history (percentage change), never to another user's numbers.
- Time points: `min(sessionMinutes, 60) × 1`, max 60.
- Buddy bonus: `15` if `session.partnerKind == PairedPartnerKind.realFriend`, else `0` (bot-paired counts as solo).
- Effort points: strength only, `min(totalSets, 20) × 2`, max 40. Cardio effort is `0` (folded into time).
- Progress bonus: per exercise (strength) or per cardio activity, `pctImprovement = (todayEstimate − personalBest) / personalBest`, floored at `0.0`, capped at `0.20`. No personal best yet → flat `0.05`. Average across all exercises/activities attempted. `progressBonus = averagePct × 800`.
- Strength estimate: Epley formula, `weight × (1 + reps / 30)`, using the best (max-estimate) set per exercise this session.
- Cardio estimate: `averageSpeed` (km/h) for the session's `activityType`.
- `sessionMinutes` is computed at the moment `endSession` runs as `DateTime.now().difference(session.startedAt).inMinutes`, clamped to a minimum of `0` — `session.endedAt` is not readable here since this same call is what sets it.
- Final score is rounded to the nearest integer before being written.
- `users/{uid}/stats/prs` document shape: `{ strength: { "<exerciseNameLowercase>": { bestEstimate, achievedAt, sourceSessionId } }, cardio: { "<activityType>": { bestEstimate, achievedAt, sourceSessionId } } }`.

---

## File Structure

- **Create:** `lib/features/session/domain/workout_score.dart` — pure scoring logic, no Firestore types.
- **Create:** `test/features/session/domain/workout_score_test.dart` — full unit coverage of the pure function.
- **Modify:** `lib/services/session_service.dart` — `endSession()` (~lines 815-877) reads `stats/prs`, calls `computeWorkoutScore`, replaces the flat `FieldValue.increment(10)` with the computed score, writes updated PRs.
- **Modify:** `test/services/session_service_test.dart` — extend the Firestore mock setup to distinguish the `users` collection from the `sessions` collection (currently both route through one generic mock — see Task 2), add coverage for the new score/PR write.
- **Modify:** `lib/services/user_service.dart` — delete the dead `updateWorkoutScore` method.
- **Modify:** `lib/services/session_analytics_service.dart` — delete the dead `checkPersonalRecords` method.

---

## Task 1: `computeWorkoutScore` pure domain function

**Files:**
- Create: `lib/features/session/domain/workout_score.dart`
- Test: `test/features/session/domain/workout_score_test.dart` (create)

**Interfaces:**
- Consumes: `SessionSummary`, `ExerciseSummary`, `SetSummary` from `lib/core/models/models.dart` (existing — `SessionSummary.totalSets: int?`, `.exercises: List<ExerciseSummary>?`, `.activityType: String?`, `.averageSpeed: double?`; `ExerciseSummary.name: String`, `.setDetails: List<SetSummary>`; `SetSummary.weight: double`, `.reps: int`).
- Produces: `class WorkoutScoreResult { final int score; final Map<String, double> updatedStrengthPrs; final Map<String, double> updatedCardioPrs; }` and top-level function `WorkoutScoreResult computeWorkoutScore({required Duration sessionDuration, required bool hasRealHumanBuddy, required String sessionType, required SessionSummary? summary, required Map<String, double> currentStrengthPrs, required Map<String, double> currentCardioPrs})`. `updatedStrengthPrs`/`updatedCardioPrs` contain ONLY the entries that changed (new or improved), keyed the same way as `currentStrengthPrs`/`currentCardioPrs` (exercise name lowercased for strength, `activityType` as-is for cardio) — Task 2 reads these to know what to write.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/session/domain/workout_score_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/session/domain/workout_score.dart';

SessionSummary _strengthSummary({
  required int totalSets,
  required List<ExerciseSummary> exercises,
}) {
  return SessionSummary(totalSets: totalSets, exercises: exercises);
}

ExerciseSummary _exercise(String name, List<SetSummary> sets) {
  return ExerciseSummary(name: name, sets: sets.length, setDetails: sets);
}

void main() {
  group('computeWorkoutScore - time points', () {
    test('awards 1 point per minute, capped at 60', () {
      final under = computeWorkoutScore(
        sessionDuration: const Duration(minutes: 30),
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: null,
        currentStrengthPrs: const {},
        currentCardioPrs: const {},
      );
      expect(under.score, 30);

      final over = computeWorkoutScore(
        sessionDuration: const Duration(minutes: 90),
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: null,
        currentStrengthPrs: const {},
        currentCardioPrs: const {},
      );
      expect(over.score, 60);
    });

    test('never goes negative on clock skew', () {
      final result = computeWorkoutScore(
        sessionDuration: const Duration(minutes: -5),
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: null,
        currentStrengthPrs: const {},
        currentCardioPrs: const {},
      );
      expect(result.score, 0);
    });
  });

  group('computeWorkoutScore - buddy bonus', () {
    test('adds 15 for a real human buddy', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: true,
        sessionType: 'strength',
        summary: null,
        currentStrengthPrs: const {},
        currentCardioPrs: const {},
      );
      expect(result.score, 15);
    });

    test('bot partner counts as solo - no bonus', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: null,
        currentStrengthPrs: const {},
        currentCardioPrs: const {},
      );
      expect(result.score, 0);
    });
  });

  group('computeWorkoutScore - effort points', () {
    test('strength: 2 points per set, capped at 20 sets (40 points)', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(totalSets: 8, exercises: const []),
        currentStrengthPrs: const {},
        currentCardioPrs: const {},
      );
      expect(result.score, 16);

      final capped = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(totalSets: 50, exercises: const []),
        currentStrengthPrs: const {},
        currentCardioPrs: const {},
      );
      expect(capped.score, 40);
    });

    test('cardio: zero effort points regardless of totalSets', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'cardio',
        summary: SessionSummary(totalSets: 20),
        currentStrengthPrs: const {},
        currentCardioPrs: const {},
      );
      expect(result.score, 0);
    });
  });

  group('computeWorkoutScore - core invariant: weight-blindness', () {
    test('identical sets/reps at different absolute weights score identically', () {
      // Person A: 50kg x 8 reps x 3 sets, matches their own prior best exactly.
      final resultA = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(
          totalSets: 3,
          exercises: [
            _exercise('Bench Press', [
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
            ]),
          ],
        ),
        currentStrengthPrs: {'bench press': 50 * (1 + 8 / 30)},
        currentCardioPrs: const {},
      );

      // Person B: same sets/reps, 60kg, also matches their own prior best exactly.
      final resultB = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(
          totalSets: 3,
          exercises: [
            _exercise('Bench Press', [
              SetSummary(reps: 8, weight: 60, durationSeconds: 0),
              SetSummary(reps: 8, weight: 60, durationSeconds: 0),
              SetSummary(reps: 8, weight: 60, durationSeconds: 0),
            ]),
          ],
        ),
        currentStrengthPrs: {'bench press': 60 * (1 + 8 / 30)},
        currentCardioPrs: const {},
      );

      expect(resultA.score, resultB.score);
      expect(resultA.updatedStrengthPrs, isEmpty); // 0% change, not a new PR
      expect(resultB.updatedStrengthPrs, isEmpty);
    });

    test('same percentage improvement at different absolute weights scores identically', () {
      // Both improve by exactly 10% over their own prior best.
      final resultA = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(
          totalSets: 1,
          exercises: [
            _exercise('Squat', [SetSummary(reps: 5, weight: 55, durationSeconds: 0)]),
          ],
        ),
        currentStrengthPrs: {'squat': 50 * (1 + 5 / 30)},
        currentCardioPrs: const {},
      );
      final resultB = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(
          totalSets: 1,
          exercises: [
            _exercise('Squat', [SetSummary(reps: 5, weight: 110, durationSeconds: 0)]),
          ],
        ),
        currentStrengthPrs: {'squat': 100 * (1 + 5 / 30)},
        currentCardioPrs: const {},
      );

      expect(resultA.score, resultB.score);
    });
  });

  group('computeWorkoutScore - progress bonus', () {
    test('floors negative improvement at 0%, no new PR recorded', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(
          totalSets: 1,
          exercises: [
            _exercise('Deadlift', [SetSummary(reps: 5, weight: 80, durationSeconds: 0)]),
          ],
        ),
        currentStrengthPrs: {'deadlift': 100 * (1 + 5 / 30)},
        currentCardioPrs: const {},
      );
      expect(result.score, 0);
      expect(result.updatedStrengthPrs, isEmpty);
    });

    test('caps improvement at 20% even when raw improvement is larger', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(
          totalSets: 1,
          exercises: [
            _exercise('Overhead Press', [
              SetSummary(reps: 5, weight: 100, durationSeconds: 0),
            ]),
          ],
        ),
        currentStrengthPrs: {'overhead press': 10}, // huge raw % jump
        currentCardioPrs: const {},
      );
      expect(result.score, 160); // 0.20 * 800, capped
      expect(
        result.updatedStrengthPrs['overhead press'],
        closeTo(100 * (1 + 5 / 30), 0.001),
      );
    });

    test('first time on an exercise gets a flat 5% equivalent bonus', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(
          totalSets: 1,
          exercises: [
            _exercise('Lunges', [SetSummary(reps: 10, weight: 20, durationSeconds: 0)]),
          ],
        ),
        currentStrengthPrs: const {}, // no prior record for lunges
        currentCardioPrs: const {},
      );
      expect(result.score, 40); // 0.05 * 800
      expect(result.updatedStrengthPrs.containsKey('lunges'), isTrue);
    });

    test('averages percentage improvement across multiple exercises, not sum or max', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'strength',
        summary: _strengthSummary(
          totalSets: 2,
          exercises: [
            // 0% improvement
            _exercise('Bench Press', [
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
            ]),
            // 10% improvement
            _exercise('Squat', [
              SetSummary(reps: 5, weight: 55, durationSeconds: 0),
            ]),
          ],
        ),
        currentStrengthPrs: {
          'bench press': 50 * (1 + 8 / 30),
          'squat': 50 * (1 + 5 / 30),
        },
        currentCardioPrs: const {},
      );
      // effort: 2 sets * 2 = 4. progress: avg(0%, 10%) = 5% * 800 = 40. Total 44.
      expect(result.score, 44);
    });

    test('cardio progress uses average speed vs personal best, same mechanics', () {
      final result = computeWorkoutScore(
        sessionDuration: Duration.zero,
        hasRealHumanBuddy: false,
        sessionType: 'cardio',
        summary: SessionSummary(activityType: 'running', averageSpeed: 11.0),
        currentStrengthPrs: const {},
        currentCardioPrs: {'running': 10.0}, // 10% improvement
      );
      expect(result.score, 80); // 0.10 * 800
      expect(result.updatedCardioPrs['running'], 11.0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/session/domain/workout_score_test.dart`
Expected: FAIL — `workout_score.dart` doesn't exist yet.

- [ ] **Step 3: Implement `workout_score.dart`**

```dart
// lib/features/session/domain/workout_score.dart
import 'dart:math' as math;

import '../../../core/models/models.dart';

class WorkoutScoreResult {
  final int score;
  final Map<String, double> updatedStrengthPrs;
  final Map<String, double> updatedCardioPrs;

  const WorkoutScoreResult({
    required this.score,
    required this.updatedStrengthPrs,
    required this.updatedCardioPrs,
  });
}

const int _timeCapMinutes = 60;
const int _buddyBonusPoints = 15;
const int _effortPointsPerSet = 2;
const int _effortSetCap = 20;
const double _progressFloor = 0.0;
const double _progressCap = 0.20;
const double _firstTimeBonusPct = 0.05;
const double _progressPointsMultiplier = 800;

double _epleyEstimate(double weight, int reps) => weight * (1 + reps / 30);

WorkoutScoreResult computeWorkoutScore({
  required Duration sessionDuration,
  required bool hasRealHumanBuddy,
  required String sessionType,
  required SessionSummary? summary,
  required Map<String, double> currentStrengthPrs,
  required Map<String, double> currentCardioPrs,
}) {
  final timePoints = math
      .max(0, math.min(sessionDuration.inMinutes, _timeCapMinutes));
  final buddyBonus = hasRealHumanBuddy ? _buddyBonusPoints : 0;

  var effortPoints = 0;
  if (sessionType == 'strength') {
    final totalSets = summary?.totalSets ?? 0;
    effortPoints = math.min(totalSets, _effortSetCap) * _effortPointsPerSet;
  }

  final updatedStrengthPrs = <String, double>{};
  final updatedCardioPrs = <String, double>{};
  final pctImprovements = <double>[];

  if (sessionType == 'strength') {
    for (final exercise in summary?.exercises ?? const <ExerciseSummary>[]) {
      if (exercise.setDetails.isEmpty) continue;
      final key = exercise.name.toLowerCase();
      final todayEstimate = exercise.setDetails
          .map((s) => _epleyEstimate(s.weight, s.reps))
          .reduce(math.max);
      final personalBest = currentStrengthPrs[key];

      double pct;
      if (personalBest == null || personalBest <= 0) {
        pct = _firstTimeBonusPct;
        updatedStrengthPrs[key] = todayEstimate;
      } else {
        final raw = (todayEstimate - personalBest) / personalBest;
        pct = raw.clamp(_progressFloor, _progressCap);
        if (todayEstimate > personalBest) {
          updatedStrengthPrs[key] = todayEstimate;
        }
      }
      pctImprovements.add(pct);
    }
  } else if (sessionType == 'cardio') {
    final activityType = summary?.activityType;
    final todaySpeed = summary?.averageSpeed;
    if (activityType != null && todaySpeed != null) {
      final personalBest = currentCardioPrs[activityType];
      double pct;
      if (personalBest == null || personalBest <= 0) {
        pct = _firstTimeBonusPct;
        updatedCardioPrs[activityType] = todaySpeed;
      } else {
        final raw = (todaySpeed - personalBest) / personalBest;
        pct = raw.clamp(_progressFloor, _progressCap);
        if (todaySpeed > personalBest) {
          updatedCardioPrs[activityType] = todaySpeed;
        }
      }
      pctImprovements.add(pct);
    }
  }

  final averagePct = pctImprovements.isEmpty
      ? 0.0
      : pctImprovements.reduce((a, b) => a + b) / pctImprovements.length;
  final progressBonus = averagePct * _progressPointsMultiplier;

  final total =
      (timePoints + buddyBonus + effortPoints + progressBonus).round();

  return WorkoutScoreResult(
    score: total,
    updatedStrengthPrs: updatedStrengthPrs,
    updatedCardioPrs: updatedCardioPrs,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/session/domain/workout_score_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/features/session/domain/workout_score.dart test/features/session/domain/workout_score_test.dart
git add lib/features/session/domain/workout_score.dart test/features/session/domain/workout_score_test.dart
git commit -m "feat(session): add pure computeWorkoutScore domain function"
```

---

## Task 2: Wire scoring into `endSession`, delete dead code

**Files:**
- Modify: `lib/services/session_service.dart` (`endSession`, ~lines 815-877)
- Modify: `lib/services/user_service.dart` (delete `updateWorkoutScore`)
- Modify: `lib/services/session_analytics_service.dart` (delete `checkPersonalRecords`)
- Test: `test/services/session_service_test.dart` (extend)

**Interfaces:**
- Consumes: `computeWorkoutScore`, `WorkoutScoreResult` from Task 1 (`lib/features/session/domain/workout_score.dart`).
- Produces: `endSession` now writes `workoutScore: FieldValue.increment(result.score)` instead of the flat `10`, and merge-writes `users/{uid}/stats/prs` with any changed PR entries (each stamped with `achievedAt: FieldValue.serverTimestamp()` and `sourceSessionId: sessionId` at the call site, not inside the pure function).

**Current code being replaced** (`lib/services/session_service.dart`, inside `endSession`'s participant loop):
```dart
      if (participantId == userId) {
        // Client rules only permit users to update their own aggregate stats.
        batch.update(_firestore.collection('users').doc(participantId), {
          'workoutScore': FieldValue.increment(10),
          'totalWorkouts': FieldValue.increment(1),
        });
      }
```

- [ ] **Step 1: Write the failing test**

First, extend the test file's mock setup so the `users` collection is distinguishable from the `sessions` collection — today `mockFirestore.collection(any())` always returns the same `mockSessionsCollection` mock (see the `// Simplified` comment in the existing `setUp`), which breaks once a test needs a session-doc read and a users-stats-doc read to return different data in the same test. Add this to the `late` variable declarations near the top of `main()`:

```dart
  late MockCollectionReference mockUsersCollection;
  late MockDocumentReference mockUserDoc;
  late MockCollectionReference mockUserStatsCollection;
  late MockDocumentReference mockUserPrsDoc;
  late MockDocumentSnapshot mockUserPrsSnapshot;
```

Replace the existing generic stub:
```dart
    when(
      () => mockFirestore.collection(any()),
    ).thenReturn(mockSessionsCollection);
```
with a branching stub that keeps 'sessions' (and everything else already relied on) going to `mockSessionsCollection`, and routes 'users' to the new dedicated chain:
```dart
    mockUsersCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockUserStatsCollection = MockCollectionReference();
    mockUserPrsDoc = MockDocumentReference();
    mockUserPrsSnapshot = MockDocumentSnapshot();

    when(() => mockFirestore.collection(any())).thenAnswer((invocation) {
      final name = invocation.positionalArguments.first as String;
      return name == 'users' ? mockUsersCollection : mockSessionsCollection;
    });
    when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);
    when(() => mockUserDoc.collection('stats')).thenReturn(mockUserStatsCollection);
    when(() => mockUserStatsCollection.doc('prs')).thenReturn(mockUserPrsDoc);
    when(() => mockUserPrsDoc.get()).thenAnswer((_) async => mockUserPrsSnapshot);
    when(() => mockUserPrsSnapshot.exists).thenReturn(false);
    when(() => mockUserPrsSnapshot.data()).thenReturn(null);
    when(() => mockBatch.set(any(), any(), any())).thenAnswer((_) async {});
```

`mockUserDoc.update(any())` needs the same generic stub `mockSessionDoc.update` already has:
```dart
    when(() => mockUserDoc.update(any())).thenAnswer((_) async {});
```

Then add the new test (in the existing `group('SessionService', ...)` block, alongside the other `endSession` test):

```dart
    test('endSession scores a solo strength session with no prior PRs', () async {
      final mockDocSnapshot = MockDocumentSnapshot();
      when(() => mockSessionDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn(kPairedSessionId);
      when(() => mockDocSnapshot.data()).thenReturn({
        ...buildPairedSessionData(),
        'type': 'strength',
        'startedAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 20))),
      });

      Map<String, dynamic>? capturedScoreUpdate;
      when(() => mockBatch.update(mockUserDoc, any())).thenAnswer((invocation) {
        capturedScoreUpdate =
            invocation.positionalArguments[1] as Map<String, dynamic>;
      });

      final summary = SessionSummary(
        totalSets: 3,
        exercises: [
          ExerciseSummary(
            name: 'Bench Press',
            sets: 3,
            setDetails: [
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
              SetSummary(reps: 8, weight: 50, durationSeconds: 0),
            ],
          ),
        ],
      );

      await sessionService.endSession(kPairedSessionId, kPairedHostId, summary);

      expect(capturedScoreUpdate, isNotNull);
      // 20 min time + 0 buddy (bot/solo) + 6 effort (3 sets * 2) + 40 progress
      // (first-time 5% * 800) = 66.
      expect(
        capturedScoreUpdate!['workoutScore'],
        FieldValue.increment(66),
      );
      verify(() => mockBatch.set(mockUserPrsDoc, any(), any())).called(1);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/session_service_test.dart`
Expected: FAIL — `endSession` still writes the flat `10`, and `mockBatch.set` for `mockUserPrsDoc` is never called.

- [ ] **Step 3: Implement**

In `lib/services/session_service.dart`, add the import:
```dart
import '../features/session/domain/workout_score.dart';
```

Replace the `endSession` method body's participant-stats section. Before the `for (final participantId in session.participants)` loop, add the read-and-compute step (after `final session = await getSession(sessionId);` and before `final batch = _firestore.batch();`):

```dart
    final durationMinutes = DateTime.now().difference(session.startedAt);
    final hasRealHumanBuddy = session.partnerKind == PairedPartnerKind.realFriend;

    final prsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('prs');
    final prsSnapshot = await prsRef.get();
    final prsData = prsSnapshot.exists
        ? prsSnapshot.data() as Map<String, dynamic>
        : <String, dynamic>{};
    final currentStrengthPrs = <String, double>{
      for (final entry in (prsData['strength'] as Map<String, dynamic>? ?? {}).entries)
        entry.key: ((entry.value as Map<String, dynamic>)['bestEstimate'] as num).toDouble(),
    };
    final currentCardioPrs = <String, double>{
      for (final entry in (prsData['cardio'] as Map<String, dynamic>? ?? {}).entries)
        entry.key: ((entry.value as Map<String, dynamic>)['bestEstimate'] as num).toDouble(),
    };

    final scoreResult = computeWorkoutScore(
      sessionDuration: durationMinutes,
      hasRealHumanBuddy: hasRealHumanBuddy,
      sessionType: session.type,
      summary: summary,
      currentStrengthPrs: currentStrengthPrs,
      currentCardioPrs: currentCardioPrs,
    );
```

Replace the old flat-increment block inside the participant loop:
```dart
      if (participantId == userId) {
        // Client rules only permit users to update their own aggregate stats.
        batch.update(_firestore.collection('users').doc(participantId), {
          'workoutScore': FieldValue.increment(scoreResult.score),
          'totalWorkouts': FieldValue.increment(1),
        });

        if (scoreResult.updatedStrengthPrs.isNotEmpty ||
            scoreResult.updatedCardioPrs.isNotEmpty) {
          batch.set(
            prsRef,
            {
              if (scoreResult.updatedStrengthPrs.isNotEmpty)
                'strength': {
                  for (final entry in scoreResult.updatedStrengthPrs.entries)
                    entry.key: {
                      'bestEstimate': entry.value,
                      'achievedAt': FieldValue.serverTimestamp(),
                      'sourceSessionId': sessionId,
                    },
                },
              if (scoreResult.updatedCardioPrs.isNotEmpty)
                'cardio': {
                  for (final entry in scoreResult.updatedCardioPrs.entries)
                    entry.key: {
                      'bestEstimate': entry.value,
                      'achievedAt': FieldValue.serverTimestamp(),
                      'sourceSessionId': sessionId,
                    },
                },
            },
            SetOptions(merge: true),
          );
        }
      }
```

Now delete the dead code. In `lib/services/user_service.dart`, delete the entire `updateWorkoutScore` method (including its doc comment):
```dart
  /// Update user's workout score after session completion.
  /// Used for leaderboard ranking.
  /// pointsToAdd: typically +10 per workout, +25 per challenge, +5 per judgment
  Future<void> updateWorkoutScore(String userId, int pointsToAdd) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'workoutScore': FieldValue.increment(pointsToAdd),
        'totalWorkouts': FieldValue.increment(1),
      });
    } catch (e) {
      // Log but don't fail - leaderboard score update is non-critical
      // debugPrint would need import, but we keep it simple
    }
  }
```

In `lib/services/session_analytics_service.dart`, delete the entire `checkPersonalRecords` method (including its doc comment, from `/// Check for Personal Records (PRs)...` through its closing `}`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/session_service_test.dart`
Expected: PASS.

Run: `flutter analyze lib/services/session_service.dart lib/services/user_service.dart lib/services/session_analytics_service.dart test/services/session_service_test.dart`
Expected: No issues (confirms no other code referenced the two deleted methods).

- [ ] **Step 5: Run the full suite and commit**

Run: `flutter test`
Expected: All passing (no regressions from the deleted methods or the changed `endSession` sign/behavior — nothing else should have called them per the earlier grep confirming both were dead code).

```bash
git add lib/services/session_service.dart lib/services/user_service.dart lib/services/session_analytics_service.dart test/services/session_service_test.dart
git commit -m "feat(session): wire computeWorkoutScore into endSession, remove superseded dead scoring code"
```

---

## Self-Review

- **Spec coverage:** time points ✓ (Task 1), buddy bonus ✓ (Task 1), effort points ✓ (Task 1), progress bonus incl. Epley estimate, floor/cap, first-time bonus, multi-exercise averaging, cardio parity ✓ (Task 1), core weight-blindness invariant ✓ (Task 1, explicit test), data model (`stats/prs` reuse) ✓ (Task 2), wiring into `endSession` ✓ (Task 2), deleting both dead methods ✓ (Task 2). No leaderboard_service.dart changes needed, per spec — none made.
- **Placeholder scan:** no TBD/TODO; every step has real code.
- **Type consistency:** `WorkoutScoreResult`, `computeWorkoutScore`'s parameter names, and `updatedStrengthPrs`/`updatedCardioPrs` are used identically across Task 1 (definition) and Task 2 (consumption).

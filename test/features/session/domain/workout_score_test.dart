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

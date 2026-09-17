import '../../../core/models/models.dart';
import '../domain/workout_score.dart';
import 'live_participant_progress.dart';

/// Builds the end-of-session [SessionSummary] (Z-ARCH-002).
SessionSummary buildSessionSummary({
  required String? cardioActivityType,
  required Duration wallClockElapsed,
  required LiveParticipantProgress? myProgress,
  required List<Exercise> exercises,
  required String Function(Duration) formatElapsed,
}) {
  final totalSets = myProgress?.totalSets ?? 0;
  final totalVolume = myProgress?.totalVolume ?? 0.0;
  final totalDistance = myProgress?.totalDistance ?? 0.0;
  final activityElapsed = myProgress != null
      ? Duration(minutes: myProgress.totalDuration)
      : wallClockElapsed;

  return SessionSummary(
    activityType: cardioActivityType,
    duration: formatElapsed(wallClockElapsed),
    totalSets: totalSets,
    totalExercises: exercises.length,
    totalVolume: totalVolume,
    distance: totalDistance,
    averageSpeed: averageSpeedKmh(
      distanceKm: totalDistance,
      elapsed: activityElapsed,
    ),
    exercises: exercises
        .map(
          (e) => ExerciseSummary(
            name: e.name,
            sets: e.sets.length,
            setDetails: e.sets
                .map(
                  (s) => SetSummary(
                    reps: s.reps,
                    weight: s.weight,
                    durationSeconds: s.durationSeconds,
                  ),
                )
                .toList(),
          ),
        )
        .toList(),
    activeCalories: null,
  );
}

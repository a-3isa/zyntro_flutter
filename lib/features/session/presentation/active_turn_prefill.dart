import '../../../core/models/models.dart';
import '../domain/gym_session_plan.dart';
import '../domain/turn_plan_progress.dart';

/// Prefill values for the active-turn logging screen (Z-ARCH-002).
class ActiveTurnPrefill {
  const ActiveTurnPrefill({
    required this.exerciseName,
    required this.setNumber,
    required this.lastReps,
    required this.lastWeight,
    this.plannedExercise,
  });

  final String exerciseName;
  final int setNumber;
  final int lastReps;
  final double lastWeight;
  final PlannedExercise? plannedExercise;
}

ActiveTurnPrefill resolveActiveTurnPrefill({
  required GymSessionPlan? plan,
  required Map<String, int> currentUserCounts,
  required List<Exercise> exercises,
  required String? fallbackExerciseName,
  required int fallbackSetNumber,
}) {
  final plannedState = plan != null
      ? TurnPlanProgress.participantState(plan, currentUserCounts)
      : null;
  final plannedExercise = plannedState?.currentExercise;
  final exerciseName =
      plannedExercise?.name ?? fallbackExerciseName ?? 'Workout';
  final setNumber = plannedState?.currentSetNumber ?? fallbackSetNumber;

  final exerciseEntry = exercises.firstWhere(
    (e) => e.name == exerciseName,
    orElse: () => Exercise(id: '', name: exerciseName, sets: const []),
  );
  final lastSet = exerciseEntry.sets.isNotEmpty
      ? exerciseEntry.sets.last
      : null;

  return ActiveTurnPrefill(
    exerciseName: exerciseName,
    setNumber: setNumber,
    lastReps: lastSet?.reps ?? 0,
    lastWeight: lastSet?.weight ?? 0.0,
    plannedExercise: plannedExercise,
  );
}

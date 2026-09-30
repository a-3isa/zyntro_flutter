import '../domain/gym_session_plan.dart';

/// Result of appending late-picked exercises onto a gym plan (Z-ARCH-002).
class LateAddPlanResult {
  const LateAddPlanResult({
    required this.updatedPlan,
    required this.extraExercises,
  });

  final GymSessionPlan updatedPlan;
  final List<PlannedExercise> extraExercises;
}

/// Appends [pickedExercises] to [currentPlan] with unique extra_* ids.
LateAddPlanResult appendLateExercisesToPlan({
  required GymSessionPlan currentPlan,
  required List<PlannedExercise> pickedExercises,
  DateTime? now,
  int Function()? microsecondStamp,
}) {
  final stamp = microsecondStamp ?? () => DateTime.now().microsecondsSinceEpoch;
  final at = now ?? DateTime.now();
  var nextOrder = currentPlan.exercises.isEmpty
      ? 0
      : currentPlan.exercises
                .map((exercise) => exercise.order)
                .reduce((a, b) => a > b ? a : b) +
            1;
  final extraExercises = <PlannedExercise>[];
  for (final picked in pickedExercises) {
    extraExercises.add(
      picked.copyWithPlanFields(
        id: 'extra_${stamp()}_$nextOrder',
        order: nextOrder,
      ),
    );
    nextOrder += 1;
  }
  return LateAddPlanResult(
    updatedPlan: GymSessionPlan(
      userId: currentPlan.userId,
      workoutType: currentPlan.workoutType,
      source: currentPlan.source,
      isReady: true,
      exercises: [...currentPlan.exercises, ...extraExercises],
      stages: currentPlan.stages,
      targets: currentPlan.targets,
      updatedAt: at,
    ),
    extraExercises: extraExercises,
  );
}

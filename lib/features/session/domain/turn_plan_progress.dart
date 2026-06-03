import 'gym_session_plan.dart';

class TurnPlanParticipantState {
  final PlannedExercise? currentExercise;
  final int currentSetNumber;
  final bool isComplete;
  final int completedSets;
  final int totalPlannedSets;

  const TurnPlanParticipantState({
    required this.currentExercise,
    required this.currentSetNumber,
    required this.isComplete,
    required this.completedSets,
    required this.totalPlannedSets,
  });
}

class TurnPlanProgress {
  const TurnPlanProgress._();

  static TurnPlanParticipantState participantState(
    GymSessionPlan plan,
    Map<String, int> completedSetsByExercise,
  ) {
    final exercises = _orderedExercises(plan);
    var completedSets = 0;
    var totalPlannedSets = 0;

    for (final exercise in exercises) {
      totalPlannedSets += exercise.plannedSets;
      final loggedForExercise =
          completedSetsByExercise[exercise.id] ??
          completedSetsByExercise[exercise.name] ??
          0;
      final cappedLogged = loggedForExercise.clamp(0, exercise.plannedSets);
      completedSets += cappedLogged;

      if (loggedForExercise < exercise.plannedSets) {
        return TurnPlanParticipantState(
          currentExercise: exercise,
          currentSetNumber: loggedForExercise + 1,
          isComplete: false,
          completedSets: completedSets,
          totalPlannedSets:
              totalPlannedSets + _remainingAfter(exercises, exercise),
        );
      }
    }

    return TurnPlanParticipantState(
      currentExercise: null,
      currentSetNumber: 0,
      isComplete: true,
      completedSets: completedSets,
      totalPlannedSets: totalPlannedSets,
    );
  }

  static bool isSessionComplete({
    required Map<String, GymSessionPlan> plans,
    required Map<String, Map<String, int>> completedSetsByUserAndExercise,
  }) {
    if (plans.isEmpty) return false;
    return plans.entries.every((entry) {
      return participantState(
        entry.value,
        completedSetsByUserAndExercise[entry.key] ?? const {},
      ).isComplete;
    });
  }

  static String? nextActiveParticipant({
    required String currentUserId,
    required List<String> participants,
    required Map<String, GymSessionPlan> plans,
    required Map<String, Map<String, int>> completedSetsByUserAndExercise,
  }) {
    if (participants.isEmpty) return null;
    final currentIndex = participants.indexOf(currentUserId);
    final startIndex = currentIndex == -1 ? 0 : currentIndex;

    for (var offset = 1; offset <= participants.length; offset += 1) {
      final candidate =
          participants[(startIndex + offset) % participants.length];
      final plan = plans[candidate];
      if (plan == null) continue;
      final state = participantState(
        plan,
        completedSetsByUserAndExercise[candidate] ?? const {},
      );
      if (!state.isComplete) return candidate;
    }

    return null;
  }

  static Map<String, int> incrementedCounts({
    required Map<String, int> counts,
    required PlannedExercise exercise,
  }) {
    return {
      ...counts,
      exercise.id: (counts[exercise.id] ?? counts[exercise.name] ?? 0) + 1,
    };
  }

  static List<PlannedExercise> _orderedExercises(GymSessionPlan plan) {
    final exercises = List<PlannedExercise>.from(plan.exercises);
    exercises.sort((a, b) {
      final orderCompare = a.order.compareTo(b.order);
      if (orderCompare != 0) return orderCompare;
      return a.name.compareTo(b.name);
    });
    return exercises;
  }

  static int _remainingAfter(
    List<PlannedExercise> exercises,
    PlannedExercise current,
  ) {
    var total = 0;
    var afterCurrent = false;
    for (final exercise in exercises) {
      if (afterCurrent) total += exercise.plannedSets;
      if (identical(exercise, current) || exercise.id == current.id) {
        afterCurrent = true;
      }
    }
    return total;
  }
}

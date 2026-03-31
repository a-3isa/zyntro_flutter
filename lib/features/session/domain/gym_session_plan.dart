enum GymSessionPlanSource {
  hostTemplate('host_template'),
  personal('personal');

  final String value;
  const GymSessionPlanSource(this.value);

  static GymSessionPlanSource fromString(String value) {
    return GymSessionPlanSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GymSessionPlanSource.personal,
    );
  }
}

enum PlannedExerciseSource {
  catalog('catalog'),
  custom('custom');

  final String value;
  const PlannedExerciseSource(this.value);

  static PlannedExerciseSource fromString(String value) {
    return PlannedExerciseSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PlannedExerciseSource.custom,
    );
  }
}

class PlannedExercise {
  final PlannedExerciseSource source;
  final String? exerciseId;
  final String? customName;

  const PlannedExercise({
    required this.source,
    this.exerciseId,
    this.customName,
  });

  factory PlannedExercise.fromMap(Map<String, dynamic> data) {
    return PlannedExercise(
      source: PlannedExerciseSource.fromString(data['source'] ?? 'custom'),
      exerciseId: data['exerciseId'],
      customName: data['customName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source.value,
      if (exerciseId != null) 'exerciseId': exerciseId,
      if (customName != null) 'customName': customName,
    };
  }
}

class GymSessionPlan {
  final String userId;
  final GymSessionPlanSource source;
  final bool isReady;
  final List<PlannedExercise> exercises;

  const GymSessionPlan({
    required this.userId,
    required this.source,
    required this.isReady,
    required this.exercises,
  });

  factory GymSessionPlan.fromMap(Map<String, dynamic> data) {
    return GymSessionPlan(
      userId: data['userId'] ?? '',
      source: GymSessionPlanSource.fromString(data['source'] ?? 'personal'),
      isReady: data['isReady'] ?? false,
      exercises:
          (data['exercises'] as List<dynamic>?)
              ?.map((e) => PlannedExercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'source': source.value,
      'isReady': isReady,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }
}

bool areAllJoinedGymParticipantsReady({
  required List<String> participants,
  required Map<String, GymSessionPlan> plans,
}) {
  return participants.every((userId) => plans[userId]?.isReady == true);
}

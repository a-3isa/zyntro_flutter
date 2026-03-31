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
  final String id;
  final PlannedExerciseSource source;
  final String? exerciseId;
  final String name;
  final int plannedSets;
  final int order;
  final String? muscleGroup;
  final String? equipment;

  const PlannedExercise._({
    required this.id,
    required this.source,
    required this.name,
    required this.plannedSets,
    required this.order,
    this.exerciseId,
    this.muscleGroup,
    this.equipment,
  });

  factory PlannedExercise.catalog({
    required String id,
    required String exerciseId,
    required String name,
    required int plannedSets,
    required int order,
    String? muscleGroup,
    String? equipment,
  }) {
    _validateCommonFields(
      id: id,
      name: name,
      plannedSets: plannedSets,
      order: order,
    );
    if (exerciseId.trim().isEmpty) {
      throw ArgumentError(
        'Catalog exercise must include a non-empty exerciseId',
      );
    }

    return PlannedExercise._(
      id: id,
      source: PlannedExerciseSource.catalog,
      exerciseId: exerciseId,
      name: name,
      plannedSets: plannedSets,
      order: order,
      muscleGroup: muscleGroup,
      equipment: equipment,
    );
  }

  factory PlannedExercise.custom({
    required String id,
    required String name,
    required int plannedSets,
    required int order,
    String? muscleGroup,
    String? equipment,
  }) {
    _validateCommonFields(
      id: id,
      name: name,
      plannedSets: plannedSets,
      order: order,
    );

    return PlannedExercise._(
      id: id,
      source: PlannedExerciseSource.custom,
      name: name,
      plannedSets: plannedSets,
      order: order,
      muscleGroup: muscleGroup,
      equipment: equipment,
    );
  }

  factory PlannedExercise.fromMap(Map<String, dynamic> data) {
    final source = PlannedExerciseSource.fromString(
      data['sourceType'] ?? data['source'] ?? 'custom',
    );
    final id = (data['id'] ?? '').toString();
    final name = (data['name'] ?? data['customName'] ?? '').toString();
    final plannedSets = (data['plannedSets'] as num?)?.toInt() ?? 0;
    final order = (data['order'] as num?)?.toInt() ?? 0;
    final muscleGroup = data['muscleGroup']?.toString();
    final equipment = data['equipment']?.toString();

    if (source == PlannedExerciseSource.catalog) {
      return PlannedExercise.catalog(
        id: id,
        exerciseId: (data['exerciseId'] ?? '').toString(),
        name: name,
        plannedSets: plannedSets,
        order: order,
        muscleGroup: muscleGroup,
        equipment: equipment,
      );
    }

    return PlannedExercise.custom(
      id: id,
      name: name,
      plannedSets: plannedSets,
      order: order,
      muscleGroup: muscleGroup,
      equipment: equipment,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourceType': source.value,
      'name': name,
      'plannedSets': plannedSets,
      'order': order,
      if (exerciseId != null) 'exerciseId': exerciseId,
      if (muscleGroup != null) 'muscleGroup': muscleGroup,
      if (equipment != null) 'equipment': equipment,
    };
  }

  static void _validateCommonFields({
    required String id,
    required String name,
    required int plannedSets,
    required int order,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Planned exercise id must be non-empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Planned exercise name must be non-empty');
    }
    if (plannedSets <= 0) {
      throw ArgumentError('plannedSets must be greater than 0');
    }
    if (order < 0) {
      throw ArgumentError('order must be 0 or greater');
    }
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

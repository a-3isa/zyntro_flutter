import '../../../core/constants/constants.dart';

enum GymSessionPlanSource {
  hostTemplate('host_template'),
  personal('personal'),
  personalCopy('personal_copy');

  final String value;
  const GymSessionPlanSource(this.value);

  static GymSessionPlanSource fromString(String value) {
    return GymSessionPlanSource.values.firstWhere(
      (entry) => entry.value == value,
      orElse: () => GymSessionPlanSource.personal,
    );
  }
}

enum PlanTargetKind {
  duration('duration'),
  distance('distance'),
  rounds('rounds'),
  stageCompletion('stage_completion');

  final String value;
  const PlanTargetKind(this.value);

  static PlanTargetKind fromString(String value) {
    return PlanTargetKind.values.firstWhere(
      (entry) => entry.value == value,
      orElse: () => PlanTargetKind.stageCompletion,
    );
  }
}

class PlannedWorkoutStage {
  final String id;
  final String label;
  final PlanTargetKind targetKind;
  final num targetValue;

  const PlannedWorkoutStage({
    required this.id,
    required this.label,
    required this.targetKind,
    required this.targetValue,
  });

  factory PlannedWorkoutStage.fromMap(Map<String, dynamic> data) {
    return PlannedWorkoutStage(
      id: (data['id'] ?? '').toString(),
      label: (data['label'] ?? '').toString(),
      targetKind: PlanTargetKind.fromString(
        (data['targetKind'] ?? 'stage_completion').toString(),
      ),
      targetValue: data['targetValue'] as num? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'targetKind': targetKind.value,
      'targetValue': targetValue,
    };
  }
}

enum PlannedExerciseSource {
  catalog('catalog'),
  custom('custom');

  final String value;
  const PlannedExerciseSource(this.value);

  static PlannedExerciseSource fromString(String value) {
    return PlannedExerciseSource.values.firstWhere(
      (entry) => entry.value == value,
      orElse: () => PlannedExerciseSource.custom,
    );
  }
}

class PlannedExercise {
  final String id;
  final PlannedExerciseSource source;
  final String? exerciseId;
  final String? personalExerciseId;
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
    this.personalExerciseId,
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
    _validate(id: id, name: name, plannedSets: plannedSets, order: order);
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
    String? personalExerciseId,
    String? muscleGroup,
    String? equipment,
  }) {
    _validate(id: id, name: name, plannedSets: plannedSets, order: order);
    return PlannedExercise._(
      id: id,
      source: PlannedExerciseSource.custom,
      name: name,
      plannedSets: plannedSets,
      order: order,
      personalExerciseId: personalExerciseId,
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
      personalExerciseId: data['personalExerciseId']?.toString(),
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
      if (personalExerciseId != null) 'personalExerciseId': personalExerciseId,
      if (muscleGroup != null) 'muscleGroup': muscleGroup,
      if (equipment != null) 'equipment': equipment,
    };
  }

  static void _validate({
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
      throw ArgumentError('plannedSets must be at least 1');
    }
    if (plannedSets > 20) {
      throw ArgumentError('plannedSets must be at most 20');
    }
    if (order < 0) {
      throw ArgumentError('order must be 0 or greater');
    }
  }
}

class GymSessionPlan {
  final String userId;
  final WorkoutType workoutType;
  final GymSessionPlanSource source;
  final bool isReady;
  final List<PlannedExercise> exercises;
  final List<PlannedWorkoutStage> stages;
  final Map<String, dynamic> targets;
  final DateTime? updatedAt;

  const GymSessionPlan({
    required this.userId,
    this.workoutType = WorkoutType.gym,
    required this.source,
    required this.isReady,
    required this.exercises,
    this.stages = const [],
    this.targets = const {},
    this.updatedAt,
  });

  factory GymSessionPlan.defaultPersonalPlan({
    required String userId,
    required WorkoutType workoutType,
  }) {
    final stages = _defaultStagesFor(workoutType);
    return GymSessionPlan(
      userId: userId,
      workoutType: workoutType,
      source: GymSessionPlanSource.personal,
      isReady: true,
      exercises: const [],
      stages: stages,
      targets: _defaultTargetsFor(workoutType),
      updatedAt: DateTime.now(),
    );
  }

  factory GymSessionPlan.fromMap(Map<String, dynamic> data) {
    return GymSessionPlan(
      userId: data['userId'] ?? '',
      workoutType: WorkoutType.fromString(data['workoutType'] ?? 'gym'),
      source: GymSessionPlanSource.fromString(data['source'] ?? 'personal'),
      isReady: data['isReady'] ?? false,
      exercises:
          (data['exercises'] as List<dynamic>?)
              ?.map(
                (entry) =>
                    PlannedExercise.fromMap(entry as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      stages:
          (data['stages'] as List<dynamic>?)
              ?.map(
                (entry) =>
                    PlannedWorkoutStage.fromMap(entry as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      targets: data['targets'] != null
          ? Map<String, dynamic>.from(data['targets'] as Map)
          : const {},
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'workoutType': workoutType.value,
      'source': source.value,
      'isReady': isReady,
      'exercises': exercises.map((exercise) => exercise.toMap()).toList(),
      'stages': stages.map((stage) => stage.toMap()).toList(),
      'targets': targets,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  static List<PlannedWorkoutStage> _defaultStagesFor(WorkoutType type) {
    switch (type) {
      case WorkoutType.running:
      case WorkoutType.walking:
      case WorkoutType.cycling:
        return [
          PlannedWorkoutStage(
            id: '${type.value}-distance',
            label: type.displayName,
            targetKind: PlanTargetKind.distance,
            targetValue: type == WorkoutType.cycling ? 10 : 3,
          ),
        ];
      case WorkoutType.swimming:
        return const [
          PlannedWorkoutStage(
            id: 'swimming-lengths',
            label: 'Lengths',
            targetKind: PlanTargetKind.distance,
            targetValue: 500,
          ),
        ];
      case WorkoutType.yoga:
        return const [
          PlannedWorkoutStage(
            id: 'yoga-flow',
            label: 'Flow',
            targetKind: PlanTargetKind.stageCompletion,
            targetValue: 1,
          ),
        ];
      case WorkoutType.hiit:
        return const [
          PlannedWorkoutStage(
            id: 'hiit-rounds',
            label: 'Rounds',
            targetKind: PlanTargetKind.rounds,
            targetValue: 8,
          ),
        ];
      case WorkoutType.sports:
      case WorkoutType.other:
        return [
          PlannedWorkoutStage(
            id: '${type.value}-activity',
            label: type.displayName,
            targetKind: PlanTargetKind.duration,
            targetValue: 1800,
          ),
        ];
      case WorkoutType.gym:
        return const [];
    }
  }

  static Map<String, dynamic> _defaultTargetsFor(WorkoutType type) {
    switch (type) {
      case WorkoutType.running:
      case WorkoutType.walking:
        return const {'distanceKm': 3, 'durationSeconds': 1800};
      case WorkoutType.cycling:
        return const {'distanceKm': 10, 'durationSeconds': 1800};
      case WorkoutType.swimming:
        return const {'distanceMeters': 500, 'durationSeconds': 1800};
      case WorkoutType.yoga:
        return const {'durationSeconds': 1800, 'stages': 1};
      case WorkoutType.hiit:
        return const {'rounds': 8, 'durationSeconds': 1200};
      case WorkoutType.sports:
      case WorkoutType.other:
        return const {'durationSeconds': 1800};
      case WorkoutType.gym:
        return const {};
    }
  }
}

DateTime? _dateTimeFromValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

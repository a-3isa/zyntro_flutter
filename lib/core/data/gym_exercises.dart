/// Comprehensive gym exercise dataset organized by muscle group.
/// Each exercise includes name, muscle group, equipment, and description.
library;

/// Muscle group enum for categorizing exercises.
enum MuscleGroup {
  chest('Chest', 'Push exercises targeting pectorals'),
  back('Back', 'Pull exercises targeting lats and upper back'),
  shoulders('Shoulders', 'Deltoid exercises for all three heads'),
  biceps('Biceps', 'Elbow flexion exercises'),
  triceps('Triceps', 'Elbow extension exercises'),
  legs('Legs', 'Lower body compound and isolation exercises'),
  core('Core', 'Abdominal and oblique exercises'),
  fullBody('Full Body', 'Compound movements targeting multiple groups');

  final String displayName;
  final String description;

  const MuscleGroup(this.displayName, this.description);
}

/// Equipment type for exercises.
enum Equipment {
  barbell('Barbell'),
  dumbbell('Dumbbell'),
  machine('Machine'),
  cables('Cables'),
  bodyweight('Bodyweight'),
  kettlebell('Kettlebell'),
  bench('Bench'),
  pullupBar('Pull-up Bar'),
  resistanceBand('Resistance Band'),
  other('Other');

  final String displayName;

  const Equipment(this.displayName);
}

/// Model representing a gym exercise.
class GymExercise {
  final String id;
  final String name;
  final MuscleGroup muscleGroup;
  final List<MuscleGroup> secondaryMuscles;
  final List<Equipment> equipment;
  final String? description;
  final String? tips;
  final bool isCompound;

  const GymExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.secondaryMuscles = const [],
    this.equipment = const [],
    this.description,
    this.tips,
    this.isCompound = false,
  });
}

/// Comprehensive list of gym exercises organized by muscle group.
class GymExercises {
  GymExercises._();

  // ============ CHEST EXERCISES ============
  static const List<GymExercise> chest = [
    GymExercise(
      id: 'bench_press',
      name: 'Bench Press',
      muscleGroup: MuscleGroup.chest,
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      equipment: [Equipment.barbell, Equipment.bench],
      description:
          'Classic chest builder targeting the entire pectoralis major.',
      tips: 'Keep your shoulder blades retracted and maintain a slight arch.',
      isCompound: true,
    ),
    GymExercise(
      id: 'incline_bench_press',
      name: 'Incline Bench Press',
      muscleGroup: MuscleGroup.chest,
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      equipment: [Equipment.barbell, Equipment.bench],
      description: 'Upper chest focused pressing movement.',
      isCompound: true,
    ),
    GymExercise(
      id: 'decline_bench_press',
      name: 'Decline Bench Press',
      muscleGroup: MuscleGroup.chest,
      secondaryMuscles: [MuscleGroup.triceps],
      equipment: [Equipment.barbell, Equipment.bench],
      description: 'Lower chest focused pressing movement.',
      isCompound: true,
    ),
    GymExercise(
      id: 'dumbbell_bench_press',
      name: 'Dumbbell Bench Press',
      muscleGroup: MuscleGroup.chest,
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      equipment: [Equipment.dumbbell, Equipment.bench],
      description: 'Greater range of motion than barbell version.',
      isCompound: true,
    ),
    GymExercise(
      id: 'dumbbell_flyes',
      name: 'Dumbbell Flyes',
      muscleGroup: MuscleGroup.chest,
      equipment: [Equipment.dumbbell, Equipment.bench],
      description: 'Isolation exercise for chest stretch and squeeze.',
    ),
    GymExercise(
      id: 'incline_dumbbell_flyes',
      name: 'Incline Dumbbell Flyes',
      muscleGroup: MuscleGroup.chest,
      equipment: [Equipment.dumbbell, Equipment.bench],
      description: 'Upper chest isolation with a great stretch.',
    ),
    GymExercise(
      id: 'cable_crossover',
      name: 'Cable Crossover',
      muscleGroup: MuscleGroup.chest,
      equipment: [Equipment.cables],
      description: 'Constant tension throughout the movement.',
    ),
    GymExercise(
      id: 'cable_flyes',
      name: 'Cable Flyes',
      muscleGroup: MuscleGroup.chest,
      equipment: [Equipment.cables],
      description: 'Cable variation for consistent resistance.',
    ),
    GymExercise(
      id: 'push_ups',
      name: 'Push-Ups',
      muscleGroup: MuscleGroup.chest,
      secondaryMuscles: [
        MuscleGroup.triceps,
        MuscleGroup.shoulders,
        MuscleGroup.core,
      ],
      equipment: [Equipment.bodyweight],
      description: 'Fundamental bodyweight pushing exercise.',
      isCompound: true,
    ),
    GymExercise(
      id: 'chest_dips',
      name: 'Chest Dips',
      muscleGroup: MuscleGroup.chest,
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      equipment: [Equipment.bodyweight],
      description: 'Lean forward to emphasize chest engagement.',
      isCompound: true,
    ),
    GymExercise(
      id: 'machine_chest_press',
      name: 'Machine Chest Press',
      muscleGroup: MuscleGroup.chest,
      secondaryMuscles: [MuscleGroup.triceps],
      equipment: [Equipment.machine],
      description: 'Guided movement path for beginners.',
    ),
    GymExercise(
      id: 'pec_deck_fly',
      name: 'Pec Deck Fly',
      muscleGroup: MuscleGroup.chest,
      equipment: [Equipment.machine],
      description: 'Machine fly for consistent chest isolation.',
    ),
  ];

  // ============ BACK EXERCISES ============
  static const List<GymExercise> back = [
    GymExercise(
      id: 'lat_pulldown',
      name: 'Lat Pulldown',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.biceps],
      equipment: [Equipment.cables, Equipment.machine],
      description: 'Vertical pulling for lat development.',
      isCompound: true,
    ),
    GymExercise(
      id: 'pull_ups',
      name: 'Pull-Ups',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.biceps, MuscleGroup.core],
      equipment: [Equipment.pullupBar, Equipment.bodyweight],
      description: 'King of back exercises for overall development.',
      isCompound: true,
    ),
    GymExercise(
      id: 'chin_ups',
      name: 'Chin-Ups',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.biceps],
      equipment: [Equipment.pullupBar, Equipment.bodyweight],
      description: 'Underhand grip targets biceps more.',
      isCompound: true,
    ),
    GymExercise(
      id: 'barbell_row',
      name: 'Barbell Row',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.biceps, MuscleGroup.core],
      equipment: [Equipment.barbell],
      description: 'Bent-over row for back thickness.',
      isCompound: true,
    ),
    GymExercise(
      id: 'dumbbell_row',
      name: 'Dumbbell Row',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.biceps],
      equipment: [Equipment.dumbbell, Equipment.bench],
      description: 'Unilateral rowing for muscle balance.',
      isCompound: true,
    ),
    GymExercise(
      id: 'cable_row',
      name: 'Seated Cable Row',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.biceps],
      equipment: [Equipment.cables],
      description: 'Horizontal pulling with constant tension.',
      isCompound: true,
    ),
    GymExercise(
      id: 't_bar_row',
      name: 'T-Bar Row',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.biceps],
      equipment: [Equipment.barbell, Equipment.machine],
      description: 'Heavy rowing for back thickness.',
      isCompound: true,
    ),
    GymExercise(
      id: 'deadlift',
      name: 'Deadlift',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.legs, MuscleGroup.core],
      equipment: [Equipment.barbell],
      description: 'Ultimate compound for posterior chain.',
      tips: 'Keep the bar close to your body throughout.',
      isCompound: true,
    ),
    GymExercise(
      id: 'face_pulls',
      name: 'Face Pulls',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.shoulders],
      equipment: [Equipment.cables],
      description: 'Rear deltoid and upper back health exercise.',
    ),
    GymExercise(
      id: 'straight_arm_pulldown',
      name: 'Straight Arm Pulldown',
      muscleGroup: MuscleGroup.back,
      equipment: [Equipment.cables],
      description: 'Lat isolation with arms straight.',
    ),
    GymExercise(
      id: 'machine_row',
      name: 'Machine Row',
      muscleGroup: MuscleGroup.back,
      secondaryMuscles: [MuscleGroup.biceps],
      equipment: [Equipment.machine],
      description: 'Guided rowing for consistent form.',
    ),
  ];

  // ============ SHOULDER EXERCISES ============
  static const List<GymExercise> shoulders = [
    GymExercise(
      id: 'overhead_press',
      name: 'Overhead Press',
      muscleGroup: MuscleGroup.shoulders,
      secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.core],
      equipment: [Equipment.barbell],
      description: 'Standing barbell press for shoulder strength.',
      isCompound: true,
    ),
    GymExercise(
      id: 'dumbbell_shoulder_press',
      name: 'Dumbbell Shoulder Press',
      muscleGroup: MuscleGroup.shoulders,
      secondaryMuscles: [MuscleGroup.triceps],
      equipment: [Equipment.dumbbell],
      description: 'Seated or standing dumbbell pressing.',
      isCompound: true,
    ),
    GymExercise(
      id: 'arnold_press',
      name: 'Arnold Press',
      muscleGroup: MuscleGroup.shoulders,
      secondaryMuscles: [MuscleGroup.triceps],
      equipment: [Equipment.dumbbell],
      description: 'Rotational press hitting all delt heads.',
      isCompound: true,
    ),
    GymExercise(
      id: 'lateral_raises',
      name: 'Lateral Raises',
      muscleGroup: MuscleGroup.shoulders,
      equipment: [Equipment.dumbbell],
      description: 'Side deltoid isolation for shoulder width.',
    ),
    GymExercise(
      id: 'front_raises',
      name: 'Front Raises',
      muscleGroup: MuscleGroup.shoulders,
      equipment: [Equipment.dumbbell, Equipment.barbell],
      description: 'Front deltoid isolation.',
    ),
    GymExercise(
      id: 'rear_delt_flyes',
      name: 'Rear Delt Flyes',
      muscleGroup: MuscleGroup.shoulders,
      equipment: [Equipment.dumbbell],
      description: 'Bent over rear delt isolation.',
    ),
    GymExercise(
      id: 'cable_lateral_raises',
      name: 'Cable Lateral Raises',
      muscleGroup: MuscleGroup.shoulders,
      equipment: [Equipment.cables],
      description: 'Constant tension lateral raise variation.',
    ),
    GymExercise(
      id: 'upright_rows',
      name: 'Upright Rows',
      muscleGroup: MuscleGroup.shoulders,
      secondaryMuscles: [MuscleGroup.biceps],
      equipment: [Equipment.barbell, Equipment.dumbbell],
      description: 'Trap and side delt compound movement.',
      isCompound: true,
    ),
    GymExercise(
      id: 'shrugs',
      name: 'Shrugs',
      muscleGroup: MuscleGroup.shoulders,
      equipment: [Equipment.barbell, Equipment.dumbbell],
      description: 'Trapezius isolation exercise.',
    ),
    GymExercise(
      id: 'machine_shoulder_press',
      name: 'Machine Shoulder Press',
      muscleGroup: MuscleGroup.shoulders,
      secondaryMuscles: [MuscleGroup.triceps],
      equipment: [Equipment.machine],
      description: 'Guided pressing movement.',
    ),
  ];

  // ============ BICEPS EXERCISES ============
  static const List<GymExercise> biceps = [
    GymExercise(
      id: 'barbell_curl',
      name: 'Barbell Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.barbell],
      description: 'Classic bicep builder with heavy weight.',
    ),
    GymExercise(
      id: 'dumbbell_curl',
      name: 'Dumbbell Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.dumbbell],
      description: 'Alternating or simultaneous curls.',
    ),
    GymExercise(
      id: 'hammer_curl',
      name: 'Hammer Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.dumbbell],
      description: 'Neutral grip targets brachialis.',
    ),
    GymExercise(
      id: 'preacher_curl',
      name: 'Preacher Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.barbell, Equipment.dumbbell, Equipment.bench],
      description: 'Strict isolation with arm support.',
    ),
    GymExercise(
      id: 'concentration_curl',
      name: 'Concentration Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.dumbbell],
      description: 'Seated single arm isolation.',
    ),
    GymExercise(
      id: 'cable_curl',
      name: 'Cable Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.cables],
      description: 'Constant tension throughout ROM.',
    ),
    GymExercise(
      id: 'incline_dumbbell_curl',
      name: 'Incline Dumbbell Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.dumbbell, Equipment.bench],
      description: 'Stretched position for long head emphasis.',
    ),
    GymExercise(
      id: 'ez_bar_curl',
      name: 'EZ Bar Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.barbell],
      description: 'Wrist-friendly curl variation.',
    ),
    GymExercise(
      id: 'spider_curl',
      name: 'Spider Curl',
      muscleGroup: MuscleGroup.biceps,
      equipment: [Equipment.dumbbell, Equipment.barbell],
      description: 'Incline bench position for peak contraction.',
    ),
  ];

  // ============ TRICEPS EXERCISES ============
  static const List<GymExercise> triceps = [
    GymExercise(
      id: 'tricep_pushdown',
      name: 'Tricep Pushdown',
      muscleGroup: MuscleGroup.triceps,
      equipment: [Equipment.cables],
      description: 'Cable pushdown with rope or bar.',
    ),
    GymExercise(
      id: 'skull_crushers',
      name: 'Skull Crushers',
      muscleGroup: MuscleGroup.triceps,
      equipment: [Equipment.barbell, Equipment.dumbbell],
      description: 'Lying tricep extension for long head.',
    ),
    GymExercise(
      id: 'close_grip_bench_press',
      name: 'Close Grip Bench Press',
      muscleGroup: MuscleGroup.triceps,
      secondaryMuscles: [MuscleGroup.chest],
      equipment: [Equipment.barbell, Equipment.bench],
      description: 'Heavy compound for tricep mass.',
      isCompound: true,
    ),
    GymExercise(
      id: 'tricep_dips',
      name: 'Tricep Dips',
      muscleGroup: MuscleGroup.triceps,
      secondaryMuscles: [MuscleGroup.chest, MuscleGroup.shoulders],
      equipment: [Equipment.bodyweight],
      description: 'Keep upright to target triceps.',
      isCompound: true,
    ),
    GymExercise(
      id: 'overhead_tricep_extension',
      name: 'Overhead Tricep Extension',
      muscleGroup: MuscleGroup.triceps,
      equipment: [Equipment.dumbbell, Equipment.cables],
      description: 'Long head emphasis with overhead position.',
    ),
    GymExercise(
      id: 'kickbacks',
      name: 'Tricep Kickbacks',
      muscleGroup: MuscleGroup.triceps,
      equipment: [Equipment.dumbbell],
      description: 'Isolation movement for tricep contraction.',
    ),
    GymExercise(
      id: 'diamond_push_ups',
      name: 'Diamond Push-Ups',
      muscleGroup: MuscleGroup.triceps,
      secondaryMuscles: [MuscleGroup.chest],
      equipment: [Equipment.bodyweight],
      description: 'Close hand position for tricep focus.',
      isCompound: true,
    ),
    GymExercise(
      id: 'rope_pushdown',
      name: 'Rope Pushdown',
      muscleGroup: MuscleGroup.triceps,
      equipment: [Equipment.cables],
      description: 'Cable pushdown with rope attachment.',
    ),
  ];

  // ============ LEGS EXERCISES ============
  static const List<GymExercise> legs = [
    GymExercise(
      id: 'squat',
      name: 'Barbell Squat',
      muscleGroup: MuscleGroup.legs,
      secondaryMuscles: [MuscleGroup.core],
      equipment: [Equipment.barbell],
      description: 'King of leg exercises for overall development.',
      tips: 'Push through your heels, keep chest up.',
      isCompound: true,
    ),
    GymExercise(
      id: 'front_squat',
      name: 'Front Squat',
      muscleGroup: MuscleGroup.legs,
      secondaryMuscles: [MuscleGroup.core],
      equipment: [Equipment.barbell],
      description: 'Quad-dominant squat variation.',
      isCompound: true,
    ),
    GymExercise(
      id: 'leg_press',
      name: 'Leg Press',
      muscleGroup: MuscleGroup.legs,
      equipment: [Equipment.machine],
      description: 'Heavy leg compound with back support.',
      isCompound: true,
    ),
    GymExercise(
      id: 'lunges',
      name: 'Lunges',
      muscleGroup: MuscleGroup.legs,
      secondaryMuscles: [MuscleGroup.core],
      equipment: [Equipment.dumbbell, Equipment.barbell, Equipment.bodyweight],
      description: 'Unilateral leg development.',
      isCompound: true,
    ),
    GymExercise(
      id: 'bulgarian_split_squat',
      name: 'Bulgarian Split Squat',
      muscleGroup: MuscleGroup.legs,
      secondaryMuscles: [MuscleGroup.core],
      equipment: [Equipment.dumbbell, Equipment.bench],
      description: 'Single leg squat with rear foot elevated.',
      isCompound: true,
    ),
    GymExercise(
      id: 'leg_extension',
      name: 'Leg Extension',
      muscleGroup: MuscleGroup.legs,
      equipment: [Equipment.machine],
      description: 'Quadriceps isolation exercise.',
    ),
    GymExercise(
      id: 'leg_curl',
      name: 'Leg Curl',
      muscleGroup: MuscleGroup.legs,
      equipment: [Equipment.machine],
      description: 'Hamstring isolation exercise.',
    ),
    GymExercise(
      id: 'romanian_deadlift',
      name: 'Romanian Deadlift',
      muscleGroup: MuscleGroup.legs,
      secondaryMuscles: [MuscleGroup.back],
      equipment: [Equipment.barbell, Equipment.dumbbell],
      description: 'Hip hinge for hamstring and glute development.',
      isCompound: true,
    ),
    GymExercise(
      id: 'calf_raises',
      name: 'Calf Raises',
      muscleGroup: MuscleGroup.legs,
      equipment: [Equipment.machine, Equipment.dumbbell],
      description: 'Standing or seated calf development.',
    ),
    GymExercise(
      id: 'goblet_squat',
      name: 'Goblet Squat',
      muscleGroup: MuscleGroup.legs,
      secondaryMuscles: [MuscleGroup.core],
      equipment: [Equipment.dumbbell, Equipment.kettlebell],
      description: 'Front-loaded squat for beginners.',
      isCompound: true,
    ),
    GymExercise(
      id: 'hack_squat',
      name: 'Hack Squat',
      muscleGroup: MuscleGroup.legs,
      equipment: [Equipment.machine],
      description: 'Machine squat with fixed path.',
      isCompound: true,
    ),
    GymExercise(
      id: 'hip_thrust',
      name: 'Hip Thrust',
      muscleGroup: MuscleGroup.legs,
      equipment: [Equipment.barbell, Equipment.bench],
      description: 'Glute-focused hip extension.',
      isCompound: true,
    ),
    GymExercise(
      id: 'step_ups',
      name: 'Step-Ups',
      muscleGroup: MuscleGroup.legs,
      equipment: [Equipment.dumbbell, Equipment.bench],
      description: 'Unilateral leg strength exercise.',
      isCompound: true,
    ),
  ];

  // ============ CORE EXERCISES ============
  static const List<GymExercise> core = [
    GymExercise(
      id: 'plank',
      name: 'Plank',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.bodyweight],
      description: 'Isometric core stability exercise.',
    ),
    GymExercise(
      id: 'crunches',
      name: 'Crunches',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.bodyweight],
      description: 'Classic abdominal exercise.',
    ),
    GymExercise(
      id: 'hanging_leg_raises',
      name: 'Hanging Leg Raises',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.pullupBar],
      description: 'Lower ab focused exercise.',
    ),
    GymExercise(
      id: 'cable_woodchops',
      name: 'Cable Woodchops',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.cables],
      description: 'Rotational core exercise.',
    ),
    GymExercise(
      id: 'ab_wheel_rollout',
      name: 'Ab Wheel Rollout',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.other],
      description: 'Advanced core stability exercise.',
    ),
    GymExercise(
      id: 'russian_twists',
      name: 'Russian Twists',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.bodyweight, Equipment.dumbbell],
      description: 'Oblique-focused rotational exercise.',
    ),
    GymExercise(
      id: 'dead_bug',
      name: 'Dead Bug',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.bodyweight],
      description: 'Anti-extension core stability.',
    ),
    GymExercise(
      id: 'mountain_climbers',
      name: 'Mountain Climbers',
      muscleGroup: MuscleGroup.core,
      secondaryMuscles: [MuscleGroup.legs, MuscleGroup.shoulders],
      equipment: [Equipment.bodyweight],
      description: 'Dynamic core and cardio exercise.',
    ),
    GymExercise(
      id: 'bicycle_crunches',
      name: 'Bicycle Crunches',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.bodyweight],
      description: 'Oblique-targeting crunch variation.',
    ),
    GymExercise(
      id: 'side_plank',
      name: 'Side Plank',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.bodyweight],
      description: 'Lateral core stability.',
    ),
    GymExercise(
      id: 'cable_crunch',
      name: 'Cable Crunch',
      muscleGroup: MuscleGroup.core,
      equipment: [Equipment.cables],
      description: 'Weighted ab exercise with cable.',
    ),
  ];

  /// Get all exercises combined.
  static List<GymExercise> get all => [
    ...chest,
    ...back,
    ...shoulders,
    ...biceps,
    ...triceps,
    ...legs,
    ...core,
  ];

  /// Get exercises by muscle group.
  static List<GymExercise> byMuscleGroup(MuscleGroup group) {
    switch (group) {
      case MuscleGroup.chest:
        return chest;
      case MuscleGroup.back:
        return back;
      case MuscleGroup.shoulders:
        return shoulders;
      case MuscleGroup.biceps:
        return biceps;
      case MuscleGroup.triceps:
        return triceps;
      case MuscleGroup.legs:
        return legs;
      case MuscleGroup.core:
        return core;
      case MuscleGroup.fullBody:
        return all.where((e) => e.isCompound).toList();
    }
  }

  /// Search exercises by name.
  static List<GymExercise> search(String query) {
    if (query.isEmpty) return all;
    final lowerQuery = query.toLowerCase();
    return all.where((e) => e.name.toLowerCase().contains(lowerQuery)).toList();
  }

  /// Get compound exercises only.
  static List<GymExercise> get compounds =>
      all.where((e) => e.isCompound).toList();

  /// Get exercises by equipment type.
  static List<GymExercise> byEquipment(Equipment equipment) {
    return all.where((e) => e.equipment.contains(equipment)).toList();
  }
}

import 'package:uuid/uuid.dart';

class ExercisePlanItem {
  final String id;
  final String name;
  int sets;

  ExercisePlanItem({String? id, required this.name, this.sets = 3})
      : id = id ?? const Uuid().v4();
}

final kDefaultPlan = [
  ExercisePlanItem(name: 'Bench Press', sets: 4),
  ExercisePlanItem(name: 'Squat', sets: 4),
  ExercisePlanItem(name: 'Overhead Press', sets: 3),
];

const kExerciseSuggestions = [
  'Bench Press',
  'Squat',
  'Deadlift',
  'Overhead Press',
  'Pull-up',
  'Barbell Row',
  'Dumbbell Curl',
  'Tricep Pushdown',
  'Leg Press',
  'Romanian Deadlift',
  'Incline Press',
  'Lat Pulldown',
  'Face Pull',
  'Lateral Raise',
  'Hip Thrust',
  'Calf Raise',
  'Plank',
  'Cable Fly',
  'Dumbbell Row',
  'Leg Extension',
];

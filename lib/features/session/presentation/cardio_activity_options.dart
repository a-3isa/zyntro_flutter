import 'package:flutter/material.dart';

import '../../../core/constants/constants.dart';

/// Cardio activity choices and their presentation, for the session room.
///
/// These were methods on session_room_page's State, which put pure mapping
/// logic behind 3,400 lines of widget and made it unreachable from a test.
/// They depend on nothing but their arguments.

List<Map<String, dynamic>> cardioActivityOptions(WorkoutType workoutType) {
  switch (workoutType) {
    case WorkoutType.running:
      return [
        {
          'value': 'running',
          'label': 'Running',
          'icon': Icons.directions_run,
        },
        {
          'value': 'jogging',
          'label': 'Jogging',
          'icon': Icons.directions_run,
        },
      ];
    case WorkoutType.cycling:
      return [
        {
          'value': 'cycling',
          'label': 'Cycling',
          'icon': Icons.directions_bike,
        },
        {
          'value': 'stationary',
          'label': 'Stationary',
          'icon': Icons.pedal_bike,
        },
      ];
    case WorkoutType.swimming:
      return [
        {'value': 'swimming', 'label': 'Swimming', 'icon': Icons.pool},
        {'value': 'laps', 'label': 'Laps', 'icon': Icons.pool},
      ];
    case WorkoutType.walking:
      return [
        {
          'value': 'walking',
          'label': 'Walking',
          'icon': Icons.directions_walk,
        },
        {'value': 'hiking', 'label': 'Hiking', 'icon': Icons.terrain},
      ];
    default:
      // For generic cardio or other types, show common options
      return [
        {
          'value': 'running',
          'label': 'Running',
          'icon': Icons.directions_run,
        },
        {
          'value': 'cycling',
          'label': 'Cycling',
          'icon': Icons.directions_bike,
        },
        {'value': 'swimming', 'label': 'Swimming', 'icon': Icons.pool},
        {
          'value': 'walking',
          'label': 'Walking',
          'icon': Icons.directions_walk,
        },
      ];
  }
}

/// Get icon for activity type.
IconData cardioActivityIcon(String activityType) {
  switch (activityType) {
    case 'running':
    case 'jogging':
      return Icons.directions_run;
    case 'cycling':
    case 'stationary':
      return Icons.directions_bike;
    case 'swimming':
    case 'laps':
      return Icons.pool;
    case 'walking':
    case 'hiking':
      return Icons.directions_walk;
    default:
      return Icons.fitness_center;
  }
}

/// Get display label for activity type.
String cardioActivityLabel(String? activityType) {
  if (activityType == null) return 'Activity';
  // Capitalize first letter
  return activityType[0].toUpperCase() + activityType.substring(1);
}

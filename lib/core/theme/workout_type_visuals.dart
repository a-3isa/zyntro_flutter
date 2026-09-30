import 'package:flutter/material.dart';

/// Icon per workout type, keyed by [WorkoutType.value] or by category.
///
/// Two screens kept their own copy of this map and had already drifted — hiit
/// was `Icons.bolt` on the profile and `Icons.flash_on` in the feed — and
/// neither covered running, walking, sports or other, so those fell back to a
/// dumbbell. Colours are the companion to this and live in
/// [AppColors.typeColors].
const Map<String, IconData> workoutTypeIcons = {
  'gym': Icons.fitness_center,
  'running': Icons.directions_run,
  'walking': Icons.directions_walk,
  'cycling': Icons.directions_bike,
  'swimming': Icons.pool,
  'yoga': Icons.self_improvement,
  'hiit': Icons.bolt,
  'sports': Icons.sports_basketball,
  'other': Icons.fitness_center,
  // Category keys, for callers holding a post's category rather than its type.
  'strength': Icons.fitness_center,
  'cardio': Icons.directions_run,
  'flexibility': Icons.self_improvement,
  'mixed': Icons.bolt,
};

/// Icon for [type], which may be a [WorkoutType.value] or a category.
IconData workoutTypeIcon(String type) =>
    workoutTypeIcons[type.toLowerCase()] ?? Icons.fitness_center;

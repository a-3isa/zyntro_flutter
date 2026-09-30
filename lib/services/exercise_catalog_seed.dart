import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/data/gym_exercises.dart';
import 'exercise_catalog_service.dart';

/// Seeds the Firestore `exerciseCatalog` collection from [GymExercises.all].
///
/// Safe to call multiple times — checks for existing documents before writing.
/// Uses batch writes (max 500 per batch) for efficiency.
Future<void> seedExerciseCatalog(FirebaseFirestore db) async {
  final collection = db.collection('exerciseCatalog');

  // Skip seeding if the collection already has documents.
  final existing = await collection.limit(1).get();
  if (existing.docs.isNotEmpty) return;

  const uuid = Uuid();
  final exercises = GymExercises.all;
  const batchSize = 500;

  for (var i = 0; i < exercises.length; i += batchSize) {
    final batch = db.batch();
    final chunk = exercises.sublist(
      i,
      (i + batchSize).clamp(0, exercises.length),
    );

    for (final exercise in chunk) {
      // Inline normalization (same logic as catalogNormalizeQuery in the service)
      final normalized = exercise.name.toLowerCase().trim();
      final tokens = _buildSearchTokens(normalized);

      final entry = ExerciseCatalogEntry(
        id: uuid.v4(),
        name: exercise.name,
        normalizedName: normalized,
        searchTokens: tokens,
        muscleGroup: exercise.muscleGroup.name,
        equipment: exercise.equipment.isNotEmpty
            ? exercise.equipment.first.name
            : null,
        isActive: true,
      );

      batch.set(collection.doc(entry.id), entry.toMap());
    }

    await batch.commit();
  }
}

List<String> _buildSearchTokens(String normalized) {
  final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();
  final tokens = <String>{normalized, ...words};
  // Add prefix tokens for partial matching
  for (final word in words) {
    for (var len = 2; len < word.length; len++) {
      tokens.add(word.substring(0, len));
    }
  }
  return tokens.toList();
}

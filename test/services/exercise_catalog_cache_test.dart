import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/exercise_catalog_service.dart';

/// Counts reads per collection so a test can assert that a second search does
/// not hit Firestore again.
class _CountingFirestore extends FakeFirebaseFirestore {
  final Map<String, int> reads = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    reads[path] = (reads[path] ?? 0) + 1;
    return super.collection(path);
  }
}

void main() {
  late _CountingFirestore firestore;
  late ExerciseCatalogService service;
  const userId = 'user-1';

  setUp(() async {
    // The caches are static, so one test would otherwise leak into the next.
    ExerciseCatalogService.invalidateCaches();
    firestore = _CountingFirestore();
    service = ExerciseCatalogService(firestore);

    await firestore.collection('exerciseCatalog').doc('bench').set({
      'name': 'Bench Press',
      'normalizedName': 'bench press',
      'searchTokens': ['bench', 'press'],
      'muscleGroup': 'chest',
      'equipment': 'barbell',
      'isActive': true,
    });
    await firestore.collection('exerciseCatalog').doc('squat').set({
      'name': 'Back Squat',
      'normalizedName': 'back squat',
      'searchTokens': ['back', 'squat'],
      'muscleGroup': 'legs',
      'equipment': 'barbell',
      'isActive': true,
    });
    firestore.reads.clear();
  });

  tearDown(ExerciseCatalogService.invalidateCaches);

  test('the first search reads the catalog', () async {
    final results = await service.search(userId, 'bench');

    expect(results.map((r) => r.name), contains('Bench Press'));
    expect(firestore.reads['exerciseCatalog'], 1);
  });

  test('repeated searches reuse the cached catalog', () async {
    // The picker's field fires per keystroke. Typing "bench press" previously
    // meant a full catalog read per character.
    for (final query in ['b', 'be', 'ben', 'benc', 'bench']) {
      await service.search(userId, query);
    }

    expect(
      firestore.reads['exerciseCatalog'],
      1,
      reason: 'five keystrokes must not cost five catalog reads',
    );
  });

  test('cached results are still filtered per query', () async {
    await service.search(userId, 'bench');
    final squat = await service.search(userId, 'squat');

    expect(squat.map((r) => r.name), ['Back Squat']);
    expect(firestore.reads['exerciseCatalog'], 1);
  });

  test('an empty query returns the whole cached catalog', () async {
    final all = await service.search(userId, '');

    expect(all.length, greaterThanOrEqualTo(2));
  });

  test('invalidateCaches forces the next search to read again', () async {
    await service.search(userId, 'bench');
    ExerciseCatalogService.invalidateCaches();
    await service.search(userId, 'bench');

    expect(firestore.reads['exerciseCatalog'], 2);
  });

  test('a newly created custom exercise is searchable immediately', () async {
    // Creating an exercise must drop the user's cached personal list, or the
    // thing they just added would be missing until the TTL expired.
    await service.search(userId, 'thruster');

    await service.createCustomExercise(userId: userId, name: 'Thruster');

    final results = await service.search(userId, 'thruster');
    expect(results.map((r) => r.name), contains('Thruster'));
  });

  test('one user\'s custom exercise does not appear for another', () async {
    await service.createCustomExercise(userId: userId, name: 'Thruster');
    await service.search(userId, 'thruster');

    final otherResults = await service.search('user-2', 'thruster');
    expect(otherResults, isEmpty);
  });
}

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/data/gym_exercises.dart';

// ---------------------------------------------------------------------------
// Entity types (T009)
// ---------------------------------------------------------------------------

class ExerciseCatalogEntry {
  final String id;
  final String name;
  final String normalizedName;
  final List<String> searchTokens;
  final String? muscleGroup;
  final String? equipment;
  final bool isActive;

  const ExerciseCatalogEntry({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.searchTokens,
    this.muscleGroup,
    this.equipment,
    this.isActive = true,
  });

  factory ExerciseCatalogEntry.fromMap(String id, Map<String, dynamic> data) {
    return ExerciseCatalogEntry(
      id: id,
      name: (data['name'] ?? '').toString(),
      normalizedName: (data['normalizedName'] ?? '').toString(),
      searchTokens: List<String>.from(data['searchTokens'] ?? <String>[]),
      muscleGroup: data['muscleGroup']?.toString(),
      equipment: data['equipment']?.toString(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'normalizedName': normalizedName,
        'searchTokens': searchTokens,
        if (muscleGroup != null) 'muscleGroup': muscleGroup,
        if (equipment != null) 'equipment': equipment,
        'isActive': isActive,
      };
}

class PersonalExerciseEntry {
  final String id;
  final String userId;
  final String name;
  final String normalizedName;
  final List<String> searchTokens;
  final String? muscleGroup;
  final String? equipment;
  final String reviewStatus; // pending | approved | rejected | not_submitted
  final DateTime createdAt;

  const PersonalExerciseEntry({
    required this.id,
    required this.userId,
    required this.name,
    required this.normalizedName,
    required this.searchTokens,
    this.muscleGroup,
    this.equipment,
    required this.reviewStatus,
    required this.createdAt,
  });

  factory PersonalExerciseEntry.fromMap(String id, Map<String, dynamic> data) {
    return PersonalExerciseEntry(
      id: id,
      userId: (data['userId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      normalizedName: (data['normalizedName'] ?? '').toString(),
      searchTokens: List<String>.from(data['searchTokens'] ?? <String>[]),
      muscleGroup: data['muscleGroup']?.toString(),
      equipment: data['equipment']?.toString(),
      reviewStatus: (data['reviewStatus'] ?? 'not_submitted').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'normalizedName': normalizedName,
        'searchTokens': searchTokens,
        if (muscleGroup != null) 'muscleGroup': muscleGroup,
        if (equipment != null) 'equipment': equipment,
        'reviewStatus': reviewStatus,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class ExerciseReviewSubmission {
  final String id;
  final String submittedBy;
  final String personalExerciseId;
  final String name;
  final String? normalizedName;
  final String? muscleGroup;
  final String? equipment;
  final String status; // pending | approved | rejected | merged
  final DateTime submittedAt;

  const ExerciseReviewSubmission({
    required this.id,
    required this.submittedBy,
    required this.personalExerciseId,
    required this.name,
    this.normalizedName,
    this.muscleGroup,
    this.equipment,
    required this.status,
    required this.submittedAt,
  });

  factory ExerciseReviewSubmission.fromMap(
      String id, Map<String, dynamic> data) {
    return ExerciseReviewSubmission(
      id: id,
      submittedBy: (data['submittedBy'] ?? '').toString(),
      personalExerciseId: (data['personalExerciseId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      normalizedName: data['normalizedName']?.toString(),
      muscleGroup: data['muscleGroup']?.toString(),
      equipment: data['equipment']?.toString(),
      status: (data['status'] ?? 'pending').toString(),
      submittedAt: data['submittedAt'] is Timestamp
          ? (data['submittedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'submittedBy': submittedBy,
        'personalExerciseId': personalExerciseId,
        'name': name,
        if (normalizedName != null) 'normalizedName': normalizedName,
        if (muscleGroup != null) 'muscleGroup': muscleGroup,
        if (equipment != null) 'equipment': equipment,
        'status': status,
        'submittedAt': FieldValue.serverTimestamp(),
      };
}

// ---------------------------------------------------------------------------
// Picker result type
// ---------------------------------------------------------------------------

enum ExerciseResultSource { catalog, custom }

class ExercisePickerResult {
  final String id;
  final ExerciseResultSource source;
  final String name;
  final String? muscleGroup;
  final String? equipment;

  const ExercisePickerResult({
    required this.id,
    required this.source,
    required this.name,
    this.muscleGroup,
    this.equipment,
  });
}

// ---------------------------------------------------------------------------
// Search helpers (T010) — @visibleForTesting to allow direct unit tests
// ---------------------------------------------------------------------------

/// Lowercase and collapse whitespace.
@visibleForTesting
String catalogNormalizeQuery(String input) {
  return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Split into word tokens.
@visibleForTesting
List<String> catalogTokenize(String normalized) {
  if (normalized.isEmpty) return [];
  return normalized.split(' ').where((t) => t.isNotEmpty).toList();
}

/// True when [candidate] starts with [prefix] (both normalized).
/// Requires prefix.length >= 2.
@visibleForTesting
bool catalogPrefixMatches(String candidate, String prefix) {
  if (prefix.length < 2) return false;
  return candidate.startsWith(prefix);
}

/// Levenshtein edit distance between [a] and [b].
@visibleForTesting
int catalogLevenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);

  for (int i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = math.min(
        math.min(curr[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    prev.setAll(0, curr);
  }
  return prev[b.length];
}

/// True when any token in [candidate] is within Levenshtein-2 of [query].
/// Only applies for queries of 5+ chars.
@visibleForTesting
bool catalogFuzzyMatches(String candidate, String query) {
  if (query.length < 5) return false;
  for (final token in catalogTokenize(candidate)) {
    if (catalogLevenshtein(token, query) <= 2) return true;
  }
  return false;
}

bool _entryMatchesQuery(
  String normalizedName,
  List<String> searchTokens,
  String normalizedQuery,
) {
  if (normalizedQuery.isEmpty) return true;
  final queryTokens = catalogTokenize(normalizedQuery);
  if (queryTokens.isEmpty) return true;

  final candidateTokens = <String>{
    ...catalogTokenize(normalizedName),
    ...searchTokens,
  };

  return queryTokens.every((qt) {
    for (final ct in candidateTokens) {
      if (ct == qt) return true;
      if (qt.length >= 2 && catalogPrefixMatches(ct, qt)) return true;
      if (qt.length >= 5 && catalogLevenshtein(ct, qt) <= 2) return true;
    }
    return false;
  });
}

// ---------------------------------------------------------------------------
// Service (T011, T012)
// ---------------------------------------------------------------------------

class ExerciseCatalogService {
  final FirebaseFirestore? _firestore;
  static const _uuid = Uuid();

  ExerciseCatalogService([this._firestore]);

  /// Search shared catalog + user's personal exercises (T011).
  Future<List<ExercisePickerResult>> search(
      String userId, String query) async {
    final normalized = catalogNormalizeQuery(query);
    List<ExercisePickerResult> results = [];

    final db = _firestore;
    if (db == null) return _fallbackSearch(normalized);

    try {
      final catalogSnap = await db
          .collection('exerciseCatalog')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in catalogSnap.docs) {
        final entry = ExerciseCatalogEntry.fromMap(doc.id, doc.data());
        if (_entryMatchesQuery(
            entry.normalizedName, entry.searchTokens, normalized)) {
          results.add(ExercisePickerResult(
            id: entry.id,
            source: ExerciseResultSource.catalog,
            name: entry.name,
            muscleGroup: entry.muscleGroup,
            equipment: entry.equipment,
          ));
        }
      }

      final personalSnap = await db
          .collection('users')
          .doc(userId)
          .collection('personalExercises')
          .get();

      for (final doc in personalSnap.docs) {
        final entry = PersonalExerciseEntry.fromMap(doc.id, doc.data());
        if (_entryMatchesQuery(
            entry.normalizedName, entry.searchTokens, normalized)) {
          results.add(ExercisePickerResult(
            id: entry.id,
            source: ExerciseResultSource.custom,
            name: entry.name,
            muscleGroup: entry.muscleGroup,
            equipment: entry.equipment,
          ));
        }
      }
    } catch (e) {
      // T048/T049: error log + fallback trigger telemetry.
      debugPrint('[ExerciseCatalogService] search error ($e); '
          'activating local-catalog fallback.');
      results = _fallbackSearch(normalized);
      FirebaseAnalytics.instance.logEvent(
        name: 'exercise_catalog_fallback_used',
      );
    }

    // Activate local fallback when Firestore returns 0 results (not just on
    // exceptions). Placed after BOTH the catalog loop and the personal-exercises
    // loop so personal exercises are never mixed with fallback entries.
    if (results.isEmpty) {
      results = _fallbackSearch(normalized);
      FirebaseAnalytics.instance.logEvent(
        name: 'exercise_catalog_fallback_used',
      );
    } else {
      FirebaseAnalytics.instance.logEvent(
        name: 'exercise_catalog_firestore_hit',
      );
    }

    // T048: success-rate log — one line per completed search.
    debugPrint('[ExerciseCatalogService] search("$normalized") → '
        '${results.length} results.');
    return results;
  }

  /// Create custom exercise → personal entry + pending review submission (T012).
  Future<ExercisePickerResult> createCustomExercise({
    required String userId,
    required String name,
    String? muscleGroup,
    String? equipment,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Exercise name must not be blank');
    }

    final normalized = catalogNormalizeQuery(trimmedName);
    final tokens = catalogTokenize(normalized);
    final personalId = _uuid.v4();
    final submissionId = _uuid.v4();

    final personalEntry = PersonalExerciseEntry(
      id: personalId,
      userId: userId,
      name: trimmedName,
      normalizedName: normalized,
      searchTokens: tokens,
      muscleGroup: muscleGroup,
      equipment: equipment,
      reviewStatus: 'pending',
      createdAt: DateTime.now(),
    );

    final submission = ExerciseReviewSubmission(
      id: submissionId,
      submittedBy: userId,
      personalExerciseId: personalId,
      name: trimmedName,
      normalizedName: normalized,
      muscleGroup: muscleGroup,
      equipment: equipment,
      status: 'pending',
      submittedAt: DateTime.now(),
    );

    final db = _firestore;
    if (db == null) {
      // T048: log creation failure when Firebase is unavailable.
      debugPrint('[ExerciseCatalogService] createCustomExercise skipped: '
          'Firebase not initialized.');
      throw StateError('Firebase not initialized');
    }
    final batch = db.batch();
    batch.set(
      db
          .collection('users')
          .doc(userId)
          .collection('personalExercises')
          .doc(personalId),
      personalEntry.toMap(),
    );
    batch.set(
      db.collection('exerciseReviewSubmissions').doc(submissionId),
      submission.toMap(),
    );
    try {
      await batch.commit();
    } catch (e) {
      // T048: log creation failure.
      debugPrint('[ExerciseCatalogService] createCustomExercise failed ($e).');
      rethrow;
    }

    // T048: success log.
    debugPrint('[ExerciseCatalogService] createCustomExercise succeeded: '
        '"$trimmedName" for user $userId.');
    return ExercisePickerResult(
      id: personalId,
      source: ExerciseResultSource.custom,
      name: trimmedName,
      muscleGroup: muscleGroup,
      equipment: equipment,
    );
  }

  // T049: local-catalog fallback using gym_exercises.dart seed data.
  List<ExercisePickerResult> _fallbackSearch(String normalizedQuery) {
    final localResults = GymExercises.search(normalizedQuery);
    return localResults
        .map(
          (e) => ExercisePickerResult(
            id: 'local-${e.id}',
            source: ExerciseResultSource.catalog,
            name: e.name,
            muscleGroup: e.muscleGroup.name,
            equipment:
                e.equipment.isNotEmpty ? e.equipment.first.displayName : null,
          ),
        )
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final exerciseCatalogServiceProvider = Provider<ExerciseCatalogService>((ref) {
  try {
    return ExerciseCatalogService(FirebaseFirestore.instance);
  } catch (_) {
    return ExerciseCatalogService();
  }
});

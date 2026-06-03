import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/constants/constants.dart';

enum PairedSessionAnalyticsEvent {
  botSessionStarted('paired_bot_session_started'),
  botSimulationFailed('paired_bot_simulation_failed'),
  inviteCreated('paired_invite_created'),
  inviteEligibilityRejected('paired_invite_eligibility_rejected'),
  inviteShown('paired_invite_shown'),
  inviteAccepted('paired_invite_accepted'),
  inviteDeclined('paired_invite_declined'),
  inviteExpired('paired_invite_expired'),
  inviteDeliveryFailed('paired_invite_delivery_failed'),
  planCopied('paired_plan_copied'),
  planModified('paired_plan_modified'),
  planReady('paired_plan_ready'),
  readinessBlocked('paired_readiness_blocked'),
  mixedSessionStarted('paired_mixed_session_started'),
  progressLatency('paired_progress_latency'),
  partnerDisconnected('paired_partner_disconnected'),
  completionWrite('paired_completion_write');

  final String value;
  const PairedSessionAnalyticsEvent(this.value);
}

/// Analytics service for session data analysis and PR tracking.
class SessionAnalyticsService {
  final FirebaseFirestore _firestore;

  SessionAnalyticsService(this._firestore);

  static Map<String, dynamic> pairedSessionEventPayload({
    required PairedSessionAnalyticsEvent eventName,
    required String sessionId,
    required String hostId,
    required String partnerId,
    required String partnerKind,
    required String mode,
    Map<String, dynamic> extra = const {},
  }) {
    return {
      'type': eventName.value,
      'sessionId': sessionId,
      'hostId': hostId,
      'partnerId': partnerId,
      'partnerKind': partnerKind,
      'mode': mode,
      ...extra.map(
        (key, value) => MapEntry(key, _serializeAnalyticsValue(value)),
      ),
    };
  }

  static dynamic _serializeAnalyticsValue(dynamic value) {
    if (value is WorkoutType) return value.value;
    if (value is Enum) return value.name;
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _serializeAnalyticsValue(nestedValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_serializeAnalyticsValue).toList();
    }
    return value;
  }

  Future<void> trackPairedSessionEvent(Map<String, dynamic> payload) async {
    try {
      await _firestore.collection('analytics').add({
        ...payload,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[SessionAnalyticsService] Error tracking paired event: $e');
    }
  }

  // ==================== SESSION DATA CALCULATION ====================

  /// Calculate total volume (tonnage) for a session.
  /// Volume = weight * reps for all sets.
  double calculateVolume(List<ExerciseSummary> exercises) {
    // Note: ExerciseSummary in models.dart only tracks 'sets' count.
    // We need detailed set data to calculate volume.
    // Assuming this is called with detailed local exercise data, or we fetch workout log.
    // For now, returning 0 if we only have summaries.
    // To properly calculate, we need `List<Exercise>` (with sets).
    return 0.0;
  }

  /// Calculate volume from detailed exercise list (local model).
  double calculateVolumeFromDetailed(
    List<Exercise> exercises, {
    String? userId,
  }) {
    double totalVolume = 0;
    for (final exercise in exercises) {
      for (final set in exercise.sets) {
        totalVolume += (set.weight * set.reps);
      }
    }
    return totalVolume;
  }

  /// Calculate volume per user from timeline events.
  Map<String, double> calculatePerUserVolume(List<TimelineEvent> events) {
    final volumes = <String, double>{};

    for (final event in events) {
      if (event.type == SessionEventType.setLogged) {
        final userId = event.userId;
        final data = event.data;

        final weight = (data?['weight'] as num?)?.toDouble() ?? 0;
        final reps = (data?['reps'] as num?)?.toInt() ?? 0;
        volumes[userId] = (volumes[userId] ?? 0) + (weight * reps);
      }
    }

    return volumes;
  }

  /// Calculate exercises and sets per user from timeline events.
  Map<String, Map<String, int>> calculatePerUserExercises(
    List<TimelineEvent> events,
  ) {
    final userExercises = <String, Map<String, int>>{};

    for (final event in events) {
      if (event.type == SessionEventType.setLogged) {
        final userId = event.userId;
        final exercise = event.data?['exercise'] as String?;

        if (exercise != null) {
          userExercises.putIfAbsent(userId, () => <String, int>{});
          userExercises[userId]![exercise] =
              (userExercises[userId]![exercise] ?? 0) + 1;
        }
      }
    }

    return userExercises;
  }

  /// Get session comparison for buddy sessions.
  /// Returns comparison metrics between participants.
  Future<Map<String, dynamic>> getSessionComparison(String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('events')
          .where('type', isEqualTo: 'setLogged')
          .get();

      final events = snapshot.docs
          .map((doc) => TimelineEvent.fromFirestore(doc))
          .toList();

      final volumes = calculatePerUserVolume(events);
      final exercises = calculatePerUserExercises(events);
      final setCounts = <String, int>{};

      for (final event in events) {
        setCounts[event.userId] = (setCounts[event.userId] ?? 0) + 1;
      }

      // Find leader in each category
      String? volumeLeader;
      double maxVolume = 0;
      for (final entry in volumes.entries) {
        if (entry.value > maxVolume) {
          maxVolume = entry.value;
          volumeLeader = entry.key;
        }
      }

      String? setLeader;
      int maxSets = 0;
      for (final entry in setCounts.entries) {
        if (entry.value > maxSets) {
          maxSets = entry.value;
          setLeader = entry.key;
        }
      }

      return {
        'volumes': volumes,
        'setCounts': setCounts,
        'exercises': exercises,
        'volumeLeader': volumeLeader,
        'setLeader': setLeader,
        'totalVolume': volumes.values.fold<double>(0.0, (acc, v) => acc + v),
        'totalSets': setCounts.values.fold<int>(0, (acc, c) => acc + c),
      };
    } catch (e) {
      debugPrint('[SessionAnalyticsService] Error getting comparison: $e');
      return {};
    }
  }

  /// Calculate active calories based on volume and duration.
  /// Uses a simplified MET estimate (Strength ~5, Cardio ~8).
  int calculateActiveCalories({
    required String type,
    required Duration duration,
    double? volumeKg,
    double userWeightKg = 75.0, // Default if not available
  }) {
    final hours = duration.inMinutes / 60.0;
    double met = type == 'cardio' ? 8.0 : 5.0;

    // Adjust MET slightly based on intensity (volume density) if available
    // For now, simple formula: Calories = MET * Weight * Hours
    final calories = met * userWeightKg * hours;
    return calories.round();
  }

  /// Check for Personal Records (PRs) in a completed session.
  /// Returns a list of strings describing new PRs.
  Future<List<String>> checkPersonalRecords(
    String userId,
    List<Exercise> exercises,
  ) async {
    final newPrs = <String>[];

    // Fetch existing PRs for user
    // We assume a 'stats' subcollection or 'personalRecords' document
    final statsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('prs');

    final statsDoc = await statsRef.get();
    final currentPrs = statsDoc.exists
        ? statsDoc.data() as Map<String, dynamic>
        : {};

    final batch = _firestore.batch();
    bool updated = false;

    for (final exercise in exercises) {
      // normalize name
      final exerciseKey = exercise.name.toLowerCase().trim();

      // Calculate max weight used in this session for this exercise (1RM estimate or just max weight)
      // We'll track Max Weight for simplicity.
      double maxWeight = 0;
      for (final set in exercise.sets) {
        if (set.weight > maxWeight) maxWeight = set.weight;
      }

      if (maxWeight > 0) {
        final previousBest =
            (currentPrs[exerciseKey] as num?)?.toDouble() ?? 0.0;

        if (maxWeight > previousBest) {
          updated = true;
          newPrs.add('${exercise.name}: ${maxWeight}kg'); // Localize unit later
          currentPrs[exerciseKey] = maxWeight;
        }
      }
    }

    if (updated) {
      batch.set(statsRef, currentPrs, SetOptions(merge: true));
      // Also log specific PR events?
      // For now just update the stats doc.
      await batch.commit();
    }

    return newPrs;
  }

  /// Update user workout streaks and weekly stats.
  /// Called when session ends.
  Future<void> updateWorkoutStats(String userId, Session session) async {
    // Logic to update streaks
    // We check 'users/{userId}/stats/activity'
    // We check 'users/{userId}/stats/activity'
    // final activityRef = _firestore
    //     .collection('users')
    //     .doc(userId)
    //     .collection('stats')
    //     .doc('activity');

    // Implementation placeholder: Update total workouts, streaks logic
    // This duplicates SessionService logic partially (SessionService increments totalWorkouts).
    // AnalyticsService can handle more complex like "Current Streak".
  }

  // ==================== AUTOCOMPLETE ====================

  /// Fetch recent unique exercises for autocomplete.
  Future<List<String>> getRecentExercises(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('workouts')
          .where('userId', isEqualTo: userId)
          .orderBy('endedAt', descending: true)
          .limit(20)
          .get();

      final exercises = <String>{};

      for (final doc in snapshot.docs) {
        final summaryData = doc.data()['summary'] as Map<String, dynamic>?;
        if (summaryData != null) {
          final summary = SessionSummary.fromMap(summaryData);
          if (summary.exercises != null) {
            for (final ex in summary.exercises!) {
              if (ex.name.isNotEmpty) {
                exercises.add(ex.name);
              }
            }
          }
        }
      }

      return exercises.toList();
    } catch (e) {
      debugPrint(
        '[SessionAnalyticsService] Error fetching recent exercises: $e',
      );
      return [];
    }
  }

  // ==================== PHOTO UPLOAD ANALYTICS ====================

  /// Track photo upload started event
  Future<void> trackPhotoUploadStarted({
    required String userId,
    required String postId,
    required int originalSizeBytes,
  }) async {
    try {
      await _firestore.collection('analytics').add({
        'type': 'photo_upload_started',
        'userId': userId,
        'postId': postId,
        'originalSizeBytes': originalSizeBytes,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[SessionAnalyticsService] Error tracking upload start: $e');
    }
  }

  /// Track photo upload completed event
  Future<void> trackPhotoUploadCompleted({
    required String userId,
    required String postId,
    required int uploadDurationMs,
    required int finalSizeBytes,
    int? originalSizeBytes,
    bool wasCompressed = false,
  }) async {
    try {
      final compressionRatio =
          (originalSizeBytes != null && originalSizeBytes > 0)
          ? (originalSizeBytes - finalSizeBytes) / originalSizeBytes * 100
          : 0.0;

      await _firestore.collection('analytics').add({
        'type': 'photo_upload_completed',
        'userId': userId,
        'postId': postId,
        'uploadDurationMs': uploadDurationMs,
        'finalSizeBytes': finalSizeBytes,
        'originalSizeBytes': originalSizeBytes,
        'wasCompressed': wasCompressed,
        'compressionReductionPercent': compressionRatio,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint(
        '[SessionAnalyticsService] Error tracking upload complete: $e',
      );
    }
  }

  /// Track photo upload failed event
  Future<void> trackPhotoUploadFailed({
    required String userId,
    required String postId,
    required String errorType,
    required String errorMessage,
    int? attemptNumber,
  }) async {
    try {
      await _firestore.collection('analytics').add({
        'type': 'photo_upload_failed',
        'userId': userId,
        'postId': postId,
        'errorType': errorType,
        'errorMessage': errorMessage,
        'attemptNumber': attemptNumber,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[SessionAnalyticsService] Error tracking upload failure: $e');
    }
  }

  /// Track photo compression applied event
  Future<void> trackPhotoCompression({
    required String userId,
    required int originalSizeBytes,
    required int compressedSizeBytes,
    required int originalWidth,
    required int originalHeight,
  }) async {
    try {
      final reductionPercent = originalSizeBytes > 0
          ? (originalSizeBytes - compressedSizeBytes) / originalSizeBytes * 100
          : 0.0;

      await _firestore.collection('analytics').add({
        'type': 'photo_compression_applied',
        'userId': userId,
        'originalSizeBytes': originalSizeBytes,
        'compressedSizeBytes': compressedSizeBytes,
        'sizeReductionPercent': reductionPercent,
        'originalDimensions': '${originalWidth}x$originalHeight',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[SessionAnalyticsService] Error tracking compression: $e');
    }
  }

  /// Get photo upload success rates for a user
  Future<Map<String, dynamic>> getPhotoUploadStats(String userId) async {
    try {
      final completedQuery = await _firestore
          .collection('analytics')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'photo_upload_completed')
          .get();

      final failedQuery = await _firestore
          .collection('analytics')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'photo_upload_failed')
          .get();

      final completed = completedQuery.docs.length;
      final failed = failedQuery.docs.length;
      final total = completed + failed;
      final successRate = total > 0 ? completed / total * 100 : 100.0;

      // Calculate average upload duration
      int totalDuration = 0;
      for (final doc in completedQuery.docs) {
        totalDuration += (doc.data()['uploadDurationMs'] as int?) ?? 0;
      }
      final avgDurationMs = completed > 0 ? totalDuration ~/ completed : 0;

      return {
        'totalUploads': total,
        'successfulUploads': completed,
        'failedUploads': failed,
        'successRatePercent': successRate,
        'avgUploadDurationMs': avgDurationMs,
      };
    } catch (e) {
      debugPrint('[SessionAnalyticsService] Error getting upload stats: $e');
      return {};
    }
  }
}

/// Analytics service provider.
final sessionAnalyticsServiceProvider = Provider<SessionAnalyticsService>((
  ref,
) {
  return SessionAnalyticsService(FirebaseFirestore.instance);
});

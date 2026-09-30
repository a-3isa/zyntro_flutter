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

/// Telemetry for the resume-active-session feature.
///
/// Constitution IV requires success rate, error rate and rollback-trigger
/// conditions to be observable before cutover, so every outcome of the resume
/// decision emits one of these.
enum ResumeSessionAnalyticsEvent {
  /// A warm session took the member straight back in, with no prompt.
  redirect('session_resume_redirect'),

  /// A quiet session asked the member to continue or discard.
  promptShown('session_resume_prompt_shown'),

  /// The member answered that prompt. Payload carries `choice`:
  /// `continue` or `discard`.
  promptAnswered('session_resume_prompt_answered'),

  /// A member chose what to do after their partner left. Payload carries
  /// `choice`: `finish_too` or `carry_on`.
  partnerLeftChoice('session_partner_left_choice'),

  /// The scheduled sweep closed a session that had gone stale.
  expiredSwept('session_expired_swept'),

  /// The resume lookup failed and start-up fell back to the landing screen.
  /// This is the rollback trigger — a spike here means flip the kill switch.
  error('session_resume_error'),

  /// A session went live. The denominator of the abandonment rate.
  sessionStarted('session_started'),

  /// A session reached a real ending — someone finished it deliberately.
  /// The numerator, together with [sessionExpiredAbandoned].
  sessionCompleted('session_completed'),

  /// A session ended because nobody came back to it. This is the abandonment
  /// the feature is meant to reduce: before it existed, force-closing the app
  /// destroyed the session outright and the member had no way back.
  sessionExpiredAbandoned('session_expired_abandoned');

  final String value;
  const ResumeSessionAnalyticsEvent(this.value);
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

  /// Records an outcome of the resume decision.
  ///
  /// Constitution IV requires success rate, error rate and rollback-trigger
  /// conditions to be observable before cutover — a spike in
  /// [ResumeSessionAnalyticsEvent.error] is what tells an operator to flip the
  /// kill switch.
  ///
  /// Best-effort by design: telemetry must never take down a start-up path.
  Future<void> trackResumeEvent(
    ResumeSessionAnalyticsEvent event, {
    String? sessionId,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      await _firestore.collection('analytics').add({
        'type': event.value,
        'sessionId': ?sessionId,
        ...extra.map(
          (key, value) => MapEntry(key, _serializeAnalyticsValue(value)),
        ),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[SessionAnalyticsService] Error tracking resume event: $e');
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

}

/// Analytics service provider.
final sessionAnalyticsServiceProvider = Provider<SessionAnalyticsService>((
  ref,
) {
  return SessionAnalyticsService(FirebaseFirestore.instance);
});

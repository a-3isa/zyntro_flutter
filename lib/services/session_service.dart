import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../core/models/models.dart';
import '../core/constants/constants.dart';
import '../features/session/domain/gym_session_plan.dart';
import '../utils/retry_helper.dart';
import '../utils/offline_manager.dart';
import '../features/auth/auth_providers.dart';
import 'notification_service.dart';
import 'user_cache_service.dart';

/// Session service for managing workout sessions.
/// Matches React Native sessionService.ts behavior.
class SessionService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  SessionService(this._firestore, this._ref);

  /// Check if user already has an active session.
  /// Matches RN checkActiveSession.
  Future<String?> checkActiveSession(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .where('participants', arrayContains: userId)
          .where('status', isEqualTo: 'active')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error checking active session: $e');
      return null;
    }
  }

  /// Create a new session.
  /// Matches RN createSession with retry logic and batched writes.
  Future<String> createSession({
    required String hostId,
    required String type,
    required String title,
    String? buddyPairId,
    List<String>? invitedUserIds,
    SessionMode mode = SessionMode.turnBased,
    SessionPhase phase = SessionPhase.live,
  }) async {
    // Check for existing active session
    final existingSessionId = await checkActiveSession(hostId);
    if (existingSessionId != null) {
      throw Exception(
        'You already have an active session. Please end it before starting a new one.',
      );
    }

    // Get host display name
    final hostUser = await _ref.read(userCacheServiceProvider).getUser(hostId);
    final hostName = hostUser?.displayName ?? 'User';

    // Create session document with batched write for atomicity
    final batch = _firestore.batch();
    final sessionRef = _firestore.collection('sessions').doc();
    final sessionId = sessionRef.id;

    // Batch: session doc + start event
    batch.set(sessionRef, {
      'type': type,
      'title': title,
      'hostId': hostId,
      'participants': [hostId],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'buddyPairId': buddyPairId,
      'mode': mode.value,
      'activeUserId': mode == SessionMode.turnBased ? hostId : null,
      'phase': phase.value,
    });

    final startEventRef = sessionRef
        .collection('events')
        .doc('start_${hostId}_${DateTime.now().millisecondsSinceEpoch}');
    batch.set(startEventRef, {
      'type': 'start',
      'userId': hostId,
      'text': '$hostName started $type session',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Use circuit breaker for resilient operation with queuing fallback
    try {
      await withRetryCircuitBreakerVoid(
        () => batch.commit(),
        operationType: 'session_create',
        maxFailures: 5,
        cooldownDuration: const Duration(seconds: 30),
        onCircuitOpen: () {
          debugPrint(
            '[SessionService] Circuit open for createSession, queuing operation',
          );
        },
      );
    } on CircuitOpenException {
      // Circuit is open - cannot queue a createSession as it needs to return sessionId
      throw Exception(
        'Service temporarily unavailable. Please try again in a moment.',
      );
    }

    // Notify invited users with enhanced group context and error tracking
    if (invitedUserIds != null && invitedUserIds.isNotEmpty) {
      final totalInvites = invitedUserIds.length;

      // Fetch all invited user names for group context
      final invitedUserNames = <String>[];
      for (final uid in invitedUserIds) {
        final user = await _ref.read(userCacheServiceProvider).getUser(uid);
        invitedUserNames.add(user?.displayName ?? 'User');
      }

      // Create group context message
      final int groupSize = (invitedUserIds.length) + 1; // +1 for host

      for (int i = 0; i < invitedUserIds.length; i++) {
        final invitedUserId = invitedUserIds[i];

        // Build custom message with group context
        final otherNamesPreview = invitedUserNames
            .where((name) => name != invitedUserNames[i])
            .take(2)
            .join(', ');

        unawaited(
          _ref
              .read(notificationServiceProvider)
              .notifySessionInvite(
                recipientId: invitedUserId,
                inviterName: hostName,
                sessionId: sessionId,
                sessionType: type,
                groupSize: groupSize,
                otherParticipantNames: otherNamesPreview,
              )
              .catchError(
                (e) => debugPrint(
                  '[SessionService] Notify error for $invitedUserId: $e',
                ),
              ),
        );
      }

      // Log group invite summary
      debugPrint('[SessionService] Group invite: $totalInvites invites sent');
    }

    // Warm cache for participants (host and invited users will be fetched eventually)
    // We can't warm participants from the session doc yet because we just created it and it has only host.
    // But if we invited users, we might want to warm them?
    // The requirement says "when a session is created...".
    // Since only host is in participants initially, this mostly warms host.
    // Invited users are not in 'participants' array yet until they join?
    // Wait, createSession sets 'participants': [hostId].
    // So calling warmSessionParticipants will just fetch the host (who is likely cached).
    // But we should follow instructions.
    _ref.read(userCacheServiceProvider).warmSessionParticipants(sessionId);

    return sessionId;
  }

  /// Join an existing session.
  /// Matches RN joinSession.
  Future<void> joinSession(String sessionId, String userId) async {
    // Get user display name
    final user = await _ref.read(userCacheServiceProvider).getUser(userId);
    final userName = user?.displayName ?? 'User';

    // Add user to participants with circuit breaker
    await withRetryCircuitBreakerVoid(
      () => _firestore.collection('sessions').doc(sessionId).update({
        'participants': FieldValue.arrayUnion([userId]),
      }),
      operationType: 'session_join',
      maxFailures: 5,
      cooldownDuration: const Duration(seconds: 30),
    );

    // Create join event
    await addSessionEvent(
      sessionId: sessionId,
      type: SessionEventType.join,
      userId: userId,
      text: '$userName joined the session',
    );

    // Warm cache with new participants
    _ref.read(userCacheServiceProvider).warmSessionParticipants(sessionId);
  }

  /// Pause the session (host only).
  Future<void> pauseSession(String sessionId, String userId) async {
    await withRetry(
      () => _firestore.collection('sessions').doc(sessionId).update({
        'status': 'paused',
      }),
    );

    await addSessionEvent(
      sessionId: sessionId,
      type: SessionEventType
          .cheer, // Or custom 'pause' event type if available, reusing cheer for generic for now
      userId: userId,
      text: 'Session paused',
    );
  }

  /// Resume the session (host only).
  Future<void> resumeSession(String sessionId, String userId) async {
    await withRetry(
      () => _firestore.collection('sessions').doc(sessionId).update({
        'status': 'active',
      }),
    );

    await addSessionEvent(
      sessionId: sessionId,
      type: SessionEventType.cheer,
      userId: userId,
      text: 'Session resumed',
    );
  }

  /// Add a session event.
  /// Matches RN addSessionEvent with performance monitoring.
  /// Queues operation if circuit breaker is open.
  Future<void> addSessionEvent({
    required String sessionId,
    required SessionEventType type,
    required String userId,
    required String text,
    Map<String, dynamic>? data,
  }) async {
    final startTime = DateTime.now();
    final eventId =
        '${type.value}_${userId}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      await withRetryCircuitBreakerVoid(
        () => _firestore
            .collection('sessions')
            .doc(sessionId)
            .collection('events')
            .doc(eventId)
            .set({
              'type': type.value,
              'userId': userId,
              'text': text,
              'timestamp': FieldValue.serverTimestamp(),
              if (data != null) 'data': data,
            }),
        operationType: 'session_event',
        maxFailures: 5,
        cooldownDuration: const Duration(seconds: 30),
        onCircuitOpen: () {
          debugPrint(
            '[SessionService] Circuit open for addSessionEvent, queuing',
          );
        },
      );

      final latency = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('[SessionService] addSessionEvent latency: ${latency}ms');

      // Log warning if >1s latency
      if (latency > 1000) {
        debugPrint(
          '[SessionService] WARNING: High latency detected: ${latency}ms',
        );
      }
    } on CircuitOpenException {
      // Circuit is open - queue the operation for later sync
      debugPrint('[SessionService] Circuit open, queuing session event');
      await _ref.read(offlineManagerProvider).queueOperation('session_event', {
        'sessionId': sessionId,
        'type': type.value,
        'userId': userId,
        'text': text,
        if (data != null) 'data': data,
      });
      // Re-throw to notify caller that operation was queued
      rethrow;
    }
  }

  /// Batch add session events (for offline sync or bulk logs).
  Future<void> addBatchSessionEvents(
    String sessionId,
    List<Map<String, dynamic>> events,
  ) async {
    final batch = _firestore.batch();

    for (final event in events) {
      final userId = event['userId'] as String;
      final type = event['type'] as String;
      final timestamp = event['timestamp'] as DateTime? ?? DateTime.now();
      final eventId = '${type}_${userId}_${timestamp.millisecondsSinceEpoch}';

      final docRef = _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('events')
          .doc(eventId);

      batch.set(docRef, {
        ...event,
        'timestamp': event['timestamp'] ?? FieldValue.serverTimestamp(),
      });
    }

    await withRetry(() => batch.commit());
  }

  /// End a session.
  /// Matches RN endSession with batched writes for atomicity.
  Future<void> endSession(
    String sessionId,
    String userId,
    SessionSummary? summary,
  ) async {
    // Get session data for workout logging
    final session = await getSession(sessionId);
    if (session == null) return;

    final batch = _firestore.batch();

    // 1. Update session status
    batch.update(_firestore.collection('sessions').doc(sessionId), {
      'status': 'completed',
      'endedAt': FieldValue.serverTimestamp(),
      if (summary != null) 'summary': summary.toMap(),
    });

    // 2. Add finish event
    final finishEventRef = _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('events')
        .doc('finish_${userId}_${DateTime.now().millisecondsSinceEpoch}');
    batch.set(finishEventRef, {
      'type': SessionEventType.finish.value,
      'userId': userId,
      'text': 'Session completed',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 3. Log workouts for all participants
    for (final participantId in session.participants) {
      final workoutRef = _firestore.collection('workouts').doc();
      batch.set(workoutRef, {
        'userId': participantId,
        'sessionId': sessionId,
        'type': session.type,
        'title': session.title,
        'summary': summary?.toMap(),
        'participants': session.participants,
        'endedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Update user workout score (+10 points)
      batch.update(_firestore.collection('users').doc(participantId), {
        'workoutScore': FieldValue.increment(10),
        'totalWorkouts': FieldValue.increment(1),
      });
    }

    await withRetryCircuitBreakerVoid(
      () => batch.commit(),
      operationType: 'session_end',
      maxFailures: 5,
      cooldownDuration: const Duration(seconds: 30),
    );
  }

  /// Get session by ID.
  Future<Session?> getSession(String sessionId) async {
    final doc = await _firestore.collection('sessions').doc(sessionId).get();
    if (!doc.exists) return null;
    return Session.fromFirestore(doc);
  }

  /// Listen to session document changes.
  /// Returns a stream for real-time updates.
  Stream<Session?> listenToSession(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? Session.fromFirestore(doc) : null);
  }

  /// Save user gym setup plan for a session.
  Future<void> saveGymPlan({
    required String sessionId,
    required GymSessionPlan plan,
  }) async {
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('plans')
        .doc(plan.userId)
        .set(plan.toMap());
  }

  /// Ensure participant has a personal gym plan.
  /// Reuses existing plan if present, otherwise clones host template.
  Future<GymSessionPlan> ensureGymPlan({
    required String sessionId,
    required String hostId,
    required String userId,
  }) async {
    final plansCollection = _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('plans');

    final userPlanRef = plansCollection.doc(userId);
    final existingUserPlan = await userPlanRef.get();
    if (existingUserPlan.exists) {
      return GymSessionPlan.fromMap(existingUserPlan.data()!);
    }

    final hostPlanSnapshot = await plansCollection.doc(hostId).get();
    if (!hostPlanSnapshot.exists) {
      throw Exception('Host gym plan not found for session: $sessionId');
    }

    final hostPlan = GymSessionPlan.fromMap(hostPlanSnapshot.data()!);
    final clonedPlan = GymSessionPlan(
      userId: userId,
      source: GymSessionPlanSource.personal,
      isReady: false,
      exercises: hostPlan.exercises
          .map((exercise) => PlannedExercise.fromMap(exercise.toMap()))
          .toList(),
    );

    await userPlanRef.set(clonedPlan.toMap());
    return clonedPlan;
  }

  /// Update ready state and promote setup session to live when everyone is ready.
  Future<void> setGymPlanReady({
    required String sessionId,
    required String userId,
    required bool isReady,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final plansCollection = sessionRef.collection('plans');
    final userPlanRef = plansCollection.doc(userId);

    await _firestore.runTransaction<void>((transaction) async {
      final sessionSnapshot = await transaction.get(sessionRef);
      final sessionData = sessionSnapshot.data();
      if (sessionData == null) {
        throw Exception('Session not found: $sessionId');
      }

      final participants =
          (sessionData['participants'] as List<dynamic>?)
              ?.cast<String>() ??
          const <String>[];

      final userPlanSnapshot = await transaction.get(userPlanRef);
      if (userPlanSnapshot.exists) {
        transaction.update(userPlanRef, {'isReady': isReady});
      } else {
        transaction.set(userPlanRef, {
          'userId': userId,
          'source': GymSessionPlanSource.personal.value,
          'isReady': isReady,
          'exercises': const [],
        });
      }

      final planReadiness = <String, bool>{userId: isReady};
      for (final participantId in participants) {
        if (participantId == userId) continue;

        final participantPlanSnapshot = await transaction.get(
          plansCollection.doc(participantId),
        );

        if (!participantPlanSnapshot.exists) {
          planReadiness[participantId] = false;
          continue;
        }

        final planData = participantPlanSnapshot.data();
        if (planData == null) {
          planReadiness[participantId] = false;
          continue;
        }

        planReadiness[participantId] = GymSessionPlan.fromMap(planData).isReady;
      }

      if (participants.isNotEmpty &&
          participants.every((participantId) => planReadiness[participantId] == true)) {
        transaction.update(sessionRef, {'phase': SessionPhase.live.value});
      }
    });
  }

  /// Listen to user's gym plan changes in real-time.
  Stream<GymSessionPlan?> listenToGymPlan(String sessionId, String userId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('plans')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) return null;
          return GymSessionPlan.fromMap(data);
        });
  }

  /// Listen to session events in real-time.
  /// Matches RN listenToSessionEvents.
  Stream<List<TimelineEvent>> listenToSessionEvents(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('events')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TimelineEvent.fromFirestore(doc))
              .toList(),
        );
  }

  /// Switch turn to the next participant.
  /// Matches RN switchTurn (for turn_based mode only).
  /// Uses round-robin cycling to support 3+ participants.
  Future<void> switchTurn(String sessionId, String currentUserId) async {
    final session = await getSession(sessionId);
    if (session == null) return;

    // Handle edge cases
    if (session.participants.isEmpty) return;
    if (session.participants.length == 1) {
      return; // Single participant, no turn switch needed
    }

    // Find current participant's index
    final currentIndex = session.participants.indexOf(currentUserId);
    if (currentIndex == -1) {
      // Current user not found in participants, default to first participant
      debugPrint('[SessionService] Current user not in participants list');
      return;
    }

    // Calculate next participant index using modulo for round-robin cycling
    final nextIndex = (currentIndex + 1) % session.participants.length;
    final nextUserId = session.participants[nextIndex];

    // Get next participant's display name
    final nextUser = await _ref
        .read(userCacheServiceProvider)
        .getUser(nextUserId);
    final nextUserName = nextUser?.displayName ?? 'User';

    await withRetry(() async {
      await _firestore.collection('sessions').doc(sessionId).update({
        'activeUserId': nextUserId,
      });
    });

    await addSessionEvent(
      sessionId: sessionId,
      type: SessionEventType.turnSwitch,
      userId: nextUserId,
      text: "$nextUserName's turn!",
    );

    // Notify the next participant that it's their turn
    unawaited(
      _ref
          .read(notificationServiceProvider)
          .notifyTurnChange(
            recipientId: nextUserId,
            sessionId: sessionId,
            sessionType: session.type,
          )
          .catchError(
            (e) => debugPrint('[SessionService] Turn notification error: $e'),
          ),
    );
  }

  /// Get set counts per participant from session events.
  Future<Map<String, int>> getParticipantSetCounts(String sessionId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('events')
        .where('type', isEqualTo: SessionEventType.setLogged.value)
        .get();

    final setCounts = <String, int>{};
    for (final doc in snapshot.docs) {
      final userId = doc.data()['userId'] as String?;
      if (userId != null) {
        setCounts[userId] = (setCounts[userId] ?? 0) + 1;
      }
    }
    return setCounts;
  }

  /// Get exercises per participant from session events.
  Future<Map<String, List<String>>> getParticipantExercises(
    String sessionId,
  ) async {
    final snapshot = await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('events')
        .where('type', isEqualTo: SessionEventType.setLogged.value)
        .get();

    final exercises = <String, Set<String>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['userId'] as String?;
      final eventData = data['data'] as Map<String, dynamic>?;
      final exercise = eventData?['exercise'] as String?;

      if (userId != null && exercise != null) {
        exercises.putIfAbsent(userId, () => <String>{}).add(exercise);
      }
    }

    return exercises.map((key, value) => MapEntry(key, value.toList()));
  }

  /// Get all session events (for accurate summary aggregation).
  Future<List<TimelineEvent>> getAllSessionEvents(String sessionId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('events')
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => TimelineEvent.fromFirestore(doc))
        .toList();
  }

  /// Listen to most recent session events (for UI optimization).
  Stream<List<TimelineEvent>> listenToRecentSessionEvents(
    String sessionId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('events')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TimelineEvent.fromFirestore(doc))
              .toList()
              .reversed
              .toList(),
        );
  }

  /// Listen to real-time session progress aggregated by participant.
  /// Returns a stream of maps with participant progress data.
  /// Supports both strength (set_logged) and cardio (cardio_entry_logged) events.
  Stream<Map<String, dynamic>> listenToSessionProgress(String sessionId) {
    // Note: uses full event stream for accurate calculation
    return listenToSessionEvents(sessionId).map((events) {
      final progress = <String, dynamic>{};
      // Strength tracking
      final setCounts = <String, int>{};
      final exerciseCounts = <String, Set<String>>{};
      final volumes = <String, double>{};
      final currentExercise = <String, String>{};
      // Cardio tracking
      final distances = <String, double>{};
      final durations = <String, int>{};
      final activityTypes = <String, String>{};
      // Shared
      final lastActivity = <String, DateTime>{};

      for (final event in events) {
        final userId = event.userId;
        final data = event.data;

        if (event.type == SessionEventType.setLogged) {
          // Increment set count
          setCounts[userId] = (setCounts[userId] ?? 0) + 1;

          // Track exercises
          final exercise = data?['exercise'] as String?;
          if (exercise != null) {
            exerciseCounts.putIfAbsent(userId, () => <String>{}).add(exercise);
            currentExercise[userId] = exercise;
          }

          // Calculate volume
          final weight = (data?['weight'] as num?)?.toDouble() ?? 0;
          final reps = (data?['reps'] as num?)?.toInt() ?? 0;
          volumes[userId] = (volumes[userId] ?? 0) + (weight * reps);

          // Track last activity
          if (lastActivity[userId] == null ||
              event.timestamp.isAfter(lastActivity[userId]!)) {
            lastActivity[userId] = event.timestamp;
          }
        } else if (event.type == SessionEventType.cardioEntry) {
          // Aggregate cardio metrics
          final distance = (data?['distance'] as num?)?.toDouble() ?? 0;
          final duration = (data?['duration'] as num?)?.toInt() ?? 0;
          final activityType = data?['activityType'] as String?;

          distances[userId] = (distances[userId] ?? 0) + distance;
          durations[userId] = (durations[userId] ?? 0) + duration;
          if (activityType != null) {
            activityTypes[userId] = activityType;
          }

          // Track last activity
          if (lastActivity[userId] == null ||
              event.timestamp.isAfter(lastActivity[userId]!)) {
            lastActivity[userId] = event.timestamp;
          }
        }
      }

      // Build progress map for each participant (combining all unique user IDs)
      final allUserIds = <String>{
        ...setCounts.keys,
        ...exerciseCounts.keys,
        ...distances.keys,
        ...durations.keys,
      };

      for (final userId in allUserIds) {
        // Calculate average pace for cardio
        String? averagePace;
        final totalDistance = distances[userId] ?? 0;
        final totalDuration = durations[userId] ?? 0;
        if (totalDistance > 0 && totalDuration > 0) {
          final paceMinutes = totalDuration / totalDistance;
          final paceMinsPart = paceMinutes.floor();
          final paceSecsPart = ((paceMinutes - paceMinsPart) * 60).round();
          averagePace =
              '$paceMinsPart:${paceSecsPart.toString().padLeft(2, '0')}/km';
        }

        progress[userId] = {
          // Strength metrics
          'totalSets': setCounts[userId] ?? 0,
          'exerciseCount': exerciseCounts[userId]?.length ?? 0,
          'totalVolume': volumes[userId] ?? 0.0,
          'currentExercise': currentExercise[userId],
          // Cardio metrics
          'totalDistance': distances[userId] ?? 0.0,
          'totalDuration': durations[userId] ?? 0,
          'averagePace': averagePace,
          'activityType': activityTypes[userId],
          // Shared
          'lastActivity': lastActivity[userId]?.toIso8601String(),
        };
      }

      return progress;
    });
  }
}

/// Session service provider.
final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(ref.watch(authFirestoreProvider), ref);
});

/// Stream provider for current session.
final currentSessionProvider = StreamProvider.family<Session?, String>((
  ref,
  sessionId,
) {
  // Warm cache when listening starts
  ref.read(userCacheServiceProvider).warmSessionParticipants(sessionId);
  return ref.watch(sessionServiceProvider).listenToSession(sessionId);
});

/// Stream provider for session events.
final sessionEventsProvider =
    StreamProvider.family<List<TimelineEvent>, String>((ref, sessionId) {
      return ref.watch(sessionServiceProvider).listenToSessionEvents(sessionId);
    });

/// Debounced session events provider (reduces rebuild frequency).
/// Use this for UI components that don't need immediate updates.
final debouncedSessionEventsProvider =
    StreamProvider.family<List<TimelineEvent>, String>((ref, sessionId) {
      return ref
          .watch(sessionServiceProvider)
          .listenToSessionEvents(sessionId)
          .debounceTime(const Duration(milliseconds: 300));
    });

/// Stream provider for recent session events (paginated).
final recentSessionEventsProvider =
    StreamProvider.family<List<TimelineEvent>, ({String sessionId, int limit})>(
      (ref, params) {
        return ref
            .watch(sessionServiceProvider)
            .listenToRecentSessionEvents(params.sessionId, limit: params.limit);
      },
    );

/// Stream provider for real-time participant progress.
/// Returns aggregated progress data per participant.
final sessionProgressProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, sessionId) {
      return ref
          .watch(sessionServiceProvider)
          .listenToSessionProgress(sessionId)
          .debounceTime(const Duration(milliseconds: 500));
    });

/// Throttled session events provider - emits first event immediately then throttles.
/// Use for UI-critical updates that need immediate first response.
final throttledSessionEventsProvider =
    StreamProvider.family<List<TimelineEvent>, String>((ref, sessionId) {
      return ref
          .watch(sessionServiceProvider)
          .listenToSessionEvents(sessionId)
          .throttleTime(
            const Duration(milliseconds: 300),
            trailing: true,
            leading: true,
          );
    });

/// Adaptive debounced session events provider.
/// Adjusts debounce duration based on event frequency.
/// For high-frequency updates (>10/sec), uses 500ms debounce; otherwise 300ms.
final adaptiveDebouncedSessionEventsProvider =
    StreamProvider.family<List<TimelineEvent>, String>((ref, sessionId) {
      // Track recent event timestamps to detect frequency
      final timestamps = <DateTime>[];
      const maxTracked = 10;

      // Use a BehaviorSubject to allow dynamic debounce switching
      final controller = StreamController<List<TimelineEvent>>();
      Timer? debounceTimer;
      List<TimelineEvent>? pendingEvents;
      Duration currentDebounce = const Duration(milliseconds: 300);

      final subscription = ref
          .watch(sessionServiceProvider)
          .listenToSessionEvents(sessionId)
          .listen((events) {
            final now = DateTime.now();
            timestamps.add(now);
            if (timestamps.length > maxTracked) {
              timestamps.removeAt(0);
            }

            // Calculate event frequency
            double eventsPerSecond = 0;
            if (timestamps.length >= 2) {
              final duration = timestamps.last.difference(timestamps.first);
              if (duration.inMilliseconds > 0) {
                eventsPerSecond =
                    (timestamps.length - 1) / (duration.inMilliseconds / 1000);
              }
            }

            // Dynamically adjust debounce based on frequency with exponential backoff
            final newDebounce = eventsPerSecond > 20
                ? const Duration(milliseconds: 1000)
                : eventsPerSecond > 10
                ? const Duration(milliseconds: 500)
                : const Duration(milliseconds: 300);

            if (newDebounce != currentDebounce) {
              debugPrint(
                '[SessionService] Adaptive debounce: ${newDebounce.inMilliseconds}ms (${eventsPerSecond.toStringAsFixed(1)}/s)',
              );
              currentDebounce = newDebounce;
            }

            // Apply debounce with current duration
            pendingEvents = events;
            debounceTimer?.cancel();
            debounceTimer = Timer(currentDebounce, () {
              if (pendingEvents != null) {
                controller.add(pendingEvents!);
              }
            });
          });

      ref.onDispose(() {
        subscription.cancel();
        debounceTimer?.cancel();
        controller.close();
      });

      return controller.stream;
    });

/// Configurable debounced session events provider.
/// Allows specifying custom debounce duration.
final configurableDebouncedSessionEventsProvider =
    StreamProvider.family<
      List<TimelineEvent>,
      ({String sessionId, Duration debounce})
    >((ref, params) {
      return ref
          .watch(sessionServiceProvider)
          .listenToSessionEvents(params.sessionId)
          .debounceTime(params.debounce);
    });


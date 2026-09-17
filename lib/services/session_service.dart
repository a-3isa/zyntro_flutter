import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../core/models/models.dart';
import '../core/constants/constants.dart';
import '../core/auth/email_verification_gate.dart';
import '../features/session/domain/gym_session_plan.dart';
import '../features/session/domain/resume_decision.dart';
import '../features/session/domain/turn_eligibility.dart';
import '../features/session/domain/workout_score.dart';
import '../features/session/domain/workout_streak.dart';
import '../utils/retry_helper.dart';
import '../utils/offline_manager.dart';
import '../utils/field_trace.dart';
import '../features/auth/auth_providers.dart';
import 'notification_service.dart';
import 'presence_service.dart';
import 'user_cache_service.dart';
import 'session_analytics_service.dart';
import 'follow_service.dart';
import 'session_lobby_gate.dart';
import 'buddy_review_prompt_service.dart';

/// Session service for managing workout sessions.
/// Matches React Native sessionService.ts behavior.
class SessionService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  SessionService(this._firestore, this._ref);

  static List<String> validatePairedParticipants(List<String> participants) {
    if (participants.length != 2) {
      throw ArgumentError('Paired sessions require exactly two participants');
    }
    return List.unmodifiable(participants);
  }

  static void validateOneToOneInvitees(List<String>? invitedUserIds) {
    if (invitedUserIds != null && invitedUserIds.length > 1) {
      throw ArgumentError('Paired sessions allow exactly one invited friend');
    }
  }

  static SessionMode derivePairedSessionMode(
    Map<String, String> participantTypes,
  ) {
    return Session.modeFromParticipantTypes(participantTypes);
  }

  static Map<String, dynamic> sharedClockStartFields({
    required Map<String, String> participantTypes,
  }) {
    // Mode is derived client-side from participantTypes — never persisted
    // (Z-DATA-002 / Z-RT-001).
    return {
      'participantTypes': Map<String, String>.from(participantTypes),
    };
  }

  static bool isParticipantPlanOwner({
    required String planUserId,
    required String requesterId,
  }) {
    return planUserId == requesterId;
  }

  static GymSessionPlan copyHostGymPlanForInvitee({
    required GymSessionPlan hostPlan,
    required String inviteeId,
  }) {
    return GymSessionPlan(
      userId: inviteeId,
      source: GymSessionPlanSource.personalCopy,
      isReady: false,
      workoutType: hostPlan.workoutType,
      stages: List<PlannedWorkoutStage>.from(hostPlan.stages),
      targets: Map<String, dynamic>.from(hostPlan.targets),
      exercises: hostPlan.exercises
          .map((exercise) => PlannedExercise.fromMap(exercise.toMap()))
          .toList(),
      updatedAt: hostPlan.updatedAt,
    );
  }

  static GymSessionPlan copyGymPlanForParticipant({
    required GymSessionPlan sourcePlan,
    required String userId,
    required GymSessionPlanSource source,
    bool isReady = true,
  }) {
    return GymSessionPlan(
      userId: userId,
      source: source,
      isReady: isReady,
      workoutType: sourcePlan.workoutType,
      stages: List<PlannedWorkoutStage>.from(sourcePlan.stages),
      targets: Map<String, dynamic>.from(sourcePlan.targets),
      exercises: sourcePlan.exercises
          .map((exercise) => PlannedExercise.fromMap(exercise.toMap()))
          .toList(),
      updatedAt: sourcePlan.updatedAt,
    );
  }

  static GymSessionPlan botGymPlanFromHostPlan(GymSessionPlan hostPlan) {
    return copyGymPlanForParticipant(
      sourcePlan: hostPlan,
      userId: pairedBotFriendId,
      source: GymSessionPlanSource.personalCopy,
    );
  }

  /// Parse one section (`strength` or `cardio`) of a `users/{uid}/stats/prs`
  /// document into `{recordKey: bestEstimate}`.
  ///
  /// Deliberately total: the section being absent, not a map, an entry not
  /// being a map, a non-string key, or `bestEstimate` being missing or
  /// non-numeric all yield "no record" for that entry rather than throwing.
  /// This runs before the session-end batch is built, so a throw here would
  /// permanently block session completion for that user — and Firestore rules
  /// let a client put any shape in its own stats/prs doc.
  static Map<String, double> parsePersonalBests(Object? section) {
    final records = <String, double>{};
    if (section is! Map) return records;

    for (final entry in section.entries) {
      final key = entry.key;
      if (key is! String) continue;

      final value = entry.value;
      if (value is! Map) continue;

      final bestEstimate = value['bestEstimate'];
      if (bestEstimate is! num) continue;

      final asDouble = bestEstimate.toDouble();
      if (asDouble.isNaN || asDouble.isInfinite) continue;

      records[key] = asDouble;
    }

    return records;
  }

  /// Fields to merge into any write that counts as session activity.
  ///
  /// Recorded work or a state change by *any* participant resets the 3-hour
  /// clock (FR-007a). `expiresAt` is stamped alongside because the scheduled
  /// sweep range-filters on it, and Firestore allows only one range filter per
  /// query — so it is stored rather than derived at read time.
  ///
  /// Merely viewing a session must NOT use this; viewing counts as presence,
  /// not activity.
  static Map<String, dynamic> activityStamp() {
    return {
      'lastActivityAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().toUtc().add(Session.inactivityLimit),
      ),
    };
  }

  /// Fields to merge into a write that only proves someone is present —
  /// the presence heartbeat. Pushes expiry out without touching the activity
  /// clock, so an idle-but-occupied session stays alive while still reading as
  /// "quiet" for the warm/quiet split.
  static Map<String, dynamic> occupancyStamp() {
    return {
      'lastOccupiedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().toUtc().add(Session.inactivityLimit),
      ),
    };
  }

  static Map<String, dynamic> participantCompletionRecord({
    required String sessionId,
    required String userId,
    required GymSessionPlan plan,
    required ParticipantProgress progress,
  }) {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'workoutType': plan.workoutType.value,
      'plan': plan.toMap(),
      'progress': progress.toMap(),
      'completedAt': progress.updatedAt,
    };
  }

  static Map<String, dynamic> botProgressSummaryFor(WorkoutType workoutType) {
    switch (workoutType) {
      case WorkoutType.running:
      case WorkoutType.walking:
        return {'primaryMetric': 'distance', 'distanceKm': 0.12};
      case WorkoutType.cycling:
        return {'primaryMetric': 'distance', 'distanceKm': 0.4};
      case WorkoutType.swimming:
        return {'primaryMetric': 'distance', 'distanceMeters': 25};
      case WorkoutType.yoga:
        return {'primaryMetric': 'stage_completion', 'completedStages': 1};
      case WorkoutType.hiit:
      case WorkoutType.sports:
      case WorkoutType.other:
        return {'primaryMetric': 'rounds', 'completedRounds': 1};
      case WorkoutType.gym:
        final bot = BotFriend.gymSimulation();
        return {
          'primaryMetric': 'set',
          'setSeconds': bot.gymSetSeconds,
          'reps': bot.gymReps,
          'weightKg': bot.gymWeightKg,
        };
    }
  }

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

  /// The session this member should be returned to on a cold start, or null.
  ///
  /// Extends [checkActiveSession], which returns `snapshot.docs.first` with no
  /// ordering — non-deterministic, and unable to satisfy the "most recent
  /// activity wins" rule when a member somehow holds more than one.
  ///
  /// Never throws. This runs during start-up, so a failure here must degrade to
  /// "no session to resume" rather than block the member from opening the app.
  Future<ResumeCandidate?> findResumableSession(String userId) async {
    return FieldTrace.measure('session_resume_lookup', () async {
      try {
        final snapshot = await _firestore
            .collection('sessions')
            .where('participants', arrayContains: userId)
            .where('status', isEqualTo: SessionStatus.active.value)
            .where('phase', isEqualTo: SessionPhase.live.value)
            .orderBy('lastActivityAt', descending: true)
            .limit(5)
            .get();

        // Ordering happens server-side, but a member who already terminated is
        // filtered client-side: `endedParticipants` cannot be an inequality
        // filter alongside the ordering above.
        Session? session;
        for (final doc in snapshot.docs) {
          final candidate = Session.fromFirestore(doc);
          if (!candidate.hasTerminated(userId)) {
            session = candidate;
            break;
          }
        }
        if (session == null) return null;

        return ResumeCandidate.fromSession(
          session,
          userId,
          otherParticipantPresent: await _isAnyOtherParticipantPresent(
            session,
            userId,
          ),
        );
      } catch (e) {
        debugPrint('[SessionService] findResumableSession failed: $e');
        return null;
      }
    });
  }

  /// Current presence for every participant, keyed by user id.
  ///
  /// Returns an empty map on failure, which reads as "nobody is present" — the
  /// safe direction. Guessing someone is there would hand them a turn they can
  /// never take.
  Future<Map<String, UserPresence>> _presenceByUser(String sessionId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('presence')
          .get();
      return {
        for (final doc in snapshot.docs) doc.id: UserPresence.fromFirestore(doc),
      };
    } catch (e) {
      debugPrint('[SessionService] presence map lookup failed: $e');
      return const {};
    }
  }

  /// Whether anyone other than [userId] is actually in the room right now.
  ///
  /// Staleness-filtered: a force-killed app leaves `status: 'online'` written
  /// forever, so trusting the flag alone would make every abandoned session
  /// read as occupied and redirect with no prompt.
  Future<bool> _isAnyOtherParticipantPresent(
    Session session,
    String userId,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final presence = await _firestore
          .collection('sessions')
          .doc(session.id)
          .collection('presence')
          .get();

      return presence.docs.any((doc) {
        if (doc.id == userId) return false;
        if (session.hasTerminated(doc.id)) return false;
        return PresenceService.isPresenceLive(
          UserPresence.fromFirestore(doc),
          now,
        );
      });
    } catch (e) {
      // Unknown presence must read as absent: guessing "present" would turn a
      // dead session into a silent redirect.
      debugPrint('[SessionService] presence lookup failed: $e');
      return false;
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
    SessionPhase phase = SessionPhase.live,
  }) async {
    validateOneToOneInvitees(invitedUserIds);
    if (invitedUserIds != null && invitedUserIds.isNotEmpty) {
      ensureEmailVerifiedForSocial(_ref.read(authSessionProvider).value);
    }
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
    final inviteExpiresAt = DateTime.now().add(pairedInviteTimeout);
    final invitedFriendId = invitedUserIds != null && invitedUserIds.isNotEmpty
        ? invitedUserIds.single
        : null;

    if (invitedFriendId != null) {
      final canInvite = await _ref
          .read(followServiceProvider)
          .canInviteToPairedSession(hostId: hostId, inviteeId: invitedFriendId);
      if (!canInvite) {
        await _ref
            .read(sessionAnalyticsServiceProvider)
            .trackPairedSessionEvent(
              SessionAnalyticsService.pairedSessionEventPayload(
                eventName:
                    PairedSessionAnalyticsEvent.inviteEligibilityRejected,
                sessionId: '',
                hostId: hostId,
                partnerId: invitedFriendId,
                partnerKind: PairedPartnerKind.realFriend.value,
                mode: SessionMode.turnBased.value,
                extra: {'workoutType': type},
              ),
            );
        throw Exception('Selected friend is not eligible for a paired invite.');
      }
    }

    // Batch: session doc + start event
    batch.set(sessionRef, {
      'type': type,
      'title': title,
      'hostId': hostId,
      'participants': [hostId],
      'invitedUserIds': invitedUserIds ?? [],
      if (invitedFriendId != null)
        'partnerKind': PairedPartnerKind.realFriend.value,
      'partnerId': ?invitedFriendId,
      if (invitedFriendId != null)
        'invitationStatus': WorkoutInvitationStatus.pending.value,
      if (invitedFriendId != null)
        'inviteExpiresAt': Timestamp.fromDate(inviteExpiresAt),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'buddyPairId': buddyPairId,
      'activeUserId': hostId,
      'phase': phase.value,
      'participantTypes': {hostId: type},
      ...activityStamp(),
    });

    // Denominator of the abandonment rate (SC-014). Captured at creation so a
    // pre-release baseline exists to compare against.
    _trackFunnelEvent(
      ResumeSessionAnalyticsEvent.sessionStarted,
      sessionRef.id,
    );

    if (phase == SessionPhase.setup) {
      final hostPlanRef = sessionRef.collection('plans').doc(hostId);
      batch.set(
        hostPlanRef,
        const GymSessionPlan(
          userId: '',
          source: GymSessionPlanSource.hostTemplate,
          isReady: false,
          exercises: [],
        ).toMap()..['userId'] = hostId,
      );
    }

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

    // Notify the invited user with paired-session context and error tracking.
    if (invitedUserIds != null && invitedUserIds.isNotEmpty) {
      final totalInvites = invitedUserIds.length;

      // Fetch invited user names for the paired invite payload.
      final invitedUserNames = <String>[];
      for (final uid in invitedUserIds) {
        final user = await _ref.read(userCacheServiceProvider).getUser(uid);
        invitedUserNames.add(user?.displayName ?? 'User');
      }

      // Keep the existing notification payload shape while enforcing one invitee.
      final int groupSize = (invitedUserIds.length) + 1; // +1 for host

      for (int i = 0; i < invitedUserIds.length; i++) {
        final invitedUserId = invitedUserIds[i];

        // Build custom message with paired-session context.
        final otherNamesPreview = invitedUserNames
            .where((name) => name != invitedUserNames[i])
            .take(2)
            .join(', ');

        try {
          await _ref
              .read(notificationServiceProvider)
              .notifySessionInvite(
                recipientId: invitedUserId,
                inviterName: hostName,
                sessionId: sessionId,
                sessionType: type,
                hostId: hostId,
                expiresAt: inviteExpiresAt,
                groupSize: groupSize,
                otherParticipantNames: otherNamesPreview,
              );
        } catch (e) {
          debugPrint('[SessionService] Notify error for $invitedUserId: $e');
          // The session was already committed above. Roll it back to a terminal
          // state so a failed invite can't leave an active+pending orphan that
          // blocks the host's next session (checkActiveSession filters on
          // status == 'active'). Only status is changed — invitationStatus is
          // frozen for participant updates by the security rules, and clearing
          // status alone is enough to free checkActiveSession.
          try {
            await sessionRef.update({'status': SessionStatus.cancelled.value});
          } catch (cleanupError) {
            debugPrint(
              '[SessionService] Orphan session cleanup failed: $cleanupError',
            );
          }
          await _ref
              .read(sessionAnalyticsServiceProvider)
              .trackPairedSessionEvent(
                SessionAnalyticsService.pairedSessionEventPayload(
                  eventName: PairedSessionAnalyticsEvent.inviteDeliveryFailed,
                  sessionId: sessionId,
                  hostId: hostId,
                  partnerId: invitedUserId,
                  partnerKind: PairedPartnerKind.realFriend.value,
                  mode: SessionMode.turnBased.value,
                  extra: {'workoutType': type},
                ),
              );
          throw Exception('Invite delivery failed. Please try again.');
        }
      }

      debugPrint('[SessionService] Paired invite: $totalInvites invite sent');
      await _ref
          .read(sessionAnalyticsServiceProvider)
          .trackPairedSessionEvent(
            SessionAnalyticsService.pairedSessionEventPayload(
              eventName: PairedSessionAnalyticsEvent.inviteCreated,
              sessionId: sessionId,
              hostId: hostId,
              partnerId: invitedUserIds.single,
              partnerKind: PairedPartnerKind.realFriend.value,
              mode: derivePairedSessionMode({
                hostId: type,
                invitedUserIds.single: type,
              }).value,
              extra: {'workoutType': type},
            ),
          );
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

  Future<String> createBotPairedSession({
    required String hostId,
    required String type,
    required String title,
    required GymSessionPlan plan,
  }) async {
    final existingSessionId = await checkActiveSession(hostId);
    if (existingSessionId != null) {
      throw Exception(
        'You already have an active session. Please end it before starting a new one.',
      );
    }

    final sessionRef = _firestore.collection('sessions').doc();
    final sessionId = sessionRef.id;
    final batch = _firestore.batch();
    final participants = validatePairedParticipants([
      hostId,
      pairedBotFriendId,
    ]);
    final hostPlan = copyGymPlanForParticipant(
      sourcePlan: plan,
      userId: hostId,
      source: GymSessionPlanSource.hostTemplate,
    );
    final botPlan = botGymPlanFromHostPlan(hostPlan);
    final hostPlanRef = sessionRef.collection('plans').doc(hostId);
    final botPlanRef = sessionRef.collection('plans').doc(pairedBotFriendId);

    batch.set(sessionRef, {
      'type': type,
      'title': title,
      'hostId': hostId,
      'participants': participants,
      'invitedUserIds': [],
      'status': SessionStatus.active.value,
      'phase': SessionPhase.live.value,
      'partnerKind': PairedPartnerKind.bot.value,
      'partnerId': pairedBotFriendId,
      'invitationStatus': WorkoutInvitationStatus.accepted.value,
      'participantTypes': {hostId: type, pairedBotFriendId: type},
      'createdAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'activeUserId': hostId,
      'botProfile': BotFriend.gymSimulation().gymReps,
      ...activityStamp(),
    });
    batch.set(hostPlanRef, hostPlan.toMap());
    batch.set(botPlanRef, botPlan.toMap());

    await withRetryCircuitBreakerVoid(
      () => batch.commit(),
      operationType: 'bot_session_create',
      maxFailures: 5,
      cooldownDuration: const Duration(seconds: 30),
    );

    await _ref
        .read(sessionAnalyticsServiceProvider)
        .trackPairedSessionEvent(
          SessionAnalyticsService.pairedSessionEventPayload(
            eventName: PairedSessionAnalyticsEvent.botSessionStarted,
            sessionId: sessionId,
            hostId: hostId,
            partnerId: pairedBotFriendId,
            partnerKind: PairedPartnerKind.bot.value,
            mode: derivePairedSessionMode({
              hostId: type,
              pairedBotFriendId: type,
            }).value,
            extra: {'workoutType': type},
          ),
        );

    _ref.read(userCacheServiceProvider).warmSessionParticipants(sessionId);
    return sessionId;
  }

  /// Starts the shared workout clock once, when the first active set timer starts.
  Future<void> startSharedSessionClock(String sessionId) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    await withRetryCircuitBreakerVoid(
      () => _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(sessionRef);
        final data = snapshot.data();
        if (data == null) {
          throw Exception('Session not found: $sessionId');
        }
        if (data['sharedClockStartedAt'] != null) return;
        transaction.update(sessionRef, {
          'sharedClockStartedAt': FieldValue.serverTimestamp(),
        });
      }),
      operationType: 'session_clock_start',
      maxFailures: 5,
      cooldownDuration: const Duration(seconds: 30),
    );
  }

  /// Change a joined participant's own workout type in the lobby (e.g. a friend
  /// switching from the host's gym plan to their own cardio). Atomically updates
  /// their key in participantTypes AND their own plan doc's workoutType, so the
  /// stored plan never disagrees with the chosen type before they mark ready.
  /// `userId` is written into the plan doc to satisfy the create rule when the
  /// doc does not yet exist.
  Future<void> changeParticipantWorkoutType({
    required String sessionId,
    required String userId,
    required String workoutType,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final planRef = sessionRef.collection('plans').doc(userId);
    final batch = _firestore.batch();
    batch.update(sessionRef, {'participantTypes.$userId': workoutType});
    batch.set(planRef, {
      'userId': userId,
      'workoutType': workoutType,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Stamp (or clear) the moment the active participant started their current
  /// set, so the waiting partner's timer counts the set — not the whole
  /// session. Best-effort: a failure here must never block logging a set.
  Future<void> setActiveSetStarted(
    String sessionId, {
    required bool started,
  }) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'activeSetStartedAt': started
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
        ...activityStamp(),
      });
    } catch (e) {
      debugPrint('setActiveSetStarted($started) failed: $e');
    }
  }

  /// Join an existing session.
  /// Matches RN joinSession.
  Future<void> joinSession(String sessionId, String userId) async {
    await FieldTrace.measure('session_join', () async {
      // Get user display name
      final user = await _ref.read(userCacheServiceProvider).getUser(userId);
      final userName = user?.displayName ?? 'User';

      // Add user to participants with circuit breaker
      await withRetryCircuitBreakerVoid(
        () => _firestore.collection('sessions').doc(sessionId).update({
          'participants': FieldValue.arrayUnion([userId]),
          ...activityStamp(),
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
    }, extras: {'session_id': sessionId});
  }

  /// Friend joins a paired session's setup phase. Validates invite eligibility
  /// (named, still-pending, non-expired invitee) but only joins —
  /// readiness/plan are completed later in the lobby via setGymPlanReady.
  Future<void> joinSetup({
    required String sessionId,
    required String userId,
    required String chosenWorkoutType,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final sessionDoc = await sessionRef.get();
    final sessionData = sessionDoc.data();

    final invitedUserIds =
        (sessionData?['invitedUserIds'] as List?)?.cast<String>() ??
        const <String>[];
    if (!invitedUserIds.contains(userId)) {
      throw Exception('You are not invited to this session.');
    }
    if (sessionData?['invitationStatus'] !=
        WorkoutInvitationStatus.pending.value) {
      throw Exception('This invite is no longer open.');
    }
    if (sessionData?['status'] != SessionStatus.active.value ||
        sessionData?['phase'] != SessionPhase.setup.value) {
      throw Exception('This session is no longer accepting buddies.');
    }

    final inviteExpiresAt = sessionData?['inviteExpiresAt'];
    final expiresAt = inviteExpiresAt is Timestamp
        ? inviteExpiresAt.toDate()
        : inviteExpiresAt is DateTime
        ? inviteExpiresAt
        : null;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw Exception('This invite has expired.');
    }

    final user = await _ref.read(userCacheServiceProvider).getUser(userId);
    final userName = user?.displayName ?? 'User';

    final batch = _firestore.batch();
    batch.update(sessionRef, {
      'participants': FieldValue.arrayUnion([userId]),
      'participantTypes.$userId': chosenWorkoutType,
      'invitationStatus': WorkoutInvitationStatus.accepted.value,
      ...activityStamp(),
    });

    // Not-ready plan stub so the lobby can edit / confirm before readiness.
    final planRef = sessionRef.collection('plans').doc(userId);
    batch.set(
      planRef,
      GymSessionPlan(
        userId: userId,
        source: GymSessionPlanSource.personalCopy,
        isReady: false,
        exercises: const [],
      ).toMap(),
    );

    final joinEventRef = sessionRef
        .collection('events')
        .doc('join_${userId}_${DateTime.now().millisecondsSinceEpoch}');
    batch.set(joinEventRef, {
      'type': SessionEventType.join.value,
      'userId': userId,
      'text': '$userName joined the session',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await withRetryCircuitBreakerVoid(
      () => batch.commit(),
      operationType: 'session_join_setup',
      maxFailures: 5,
      cooldownDuration: const Duration(seconds: 30),
    );

    _ref.read(userCacheServiceProvider).warmSessionParticipants(sessionId);

    // Re-fire the invite-accepted event the retired acceptInvite used to track.
    final hostId = (sessionData?['hostId'] ?? '').toString();
    final hostType = (sessionData?['participantTypes']
            as Map<String, dynamic>?)?[hostId]
            ?.toString() ??
        (sessionData?['type'] ?? '').toString();
    await _ref
        .read(sessionAnalyticsServiceProvider)
        .trackPairedSessionEvent(
          SessionAnalyticsService.pairedSessionEventPayload(
            eventName: PairedSessionAnalyticsEvent.inviteAccepted,
            sessionId: sessionId,
            hostId: hostId,
            partnerId: userId,
            partnerKind: PairedPartnerKind.realFriend.value,
            mode: derivePairedSessionMode({
              hostId: hostType,
              userId: chosenWorkoutType,
            }).value,
            extra: {'workoutType': chosenWorkoutType},
          ),
        );
  }

  Future<void> declineInvite({
    required String sessionId,
    required String userId,
  }) async {
    await withRetry(
      () => _firestore.collection('sessions').doc(sessionId).update({
        'invitationStatus': WorkoutInvitationStatus.declined.value,
        'declinedBy': userId,
      }),
    );
    await _ref
        .read(sessionAnalyticsServiceProvider)
        .trackPairedSessionEvent(
          SessionAnalyticsService.pairedSessionEventPayload(
            eventName: PairedSessionAnalyticsEvent.inviteDeclined,
            sessionId: sessionId,
            hostId: '',
            partnerId: userId,
            partnerKind: PairedPartnerKind.realFriend.value,
            mode: SessionMode.turnBased.value,
          ),
        );
  }

  /// Pause the session (host only — Z-RT-005).
  Future<void> pauseSession(String sessionId, String userId) async {
    await _assertCallerIsSessionHost(sessionId, userId);
    await withRetry(
      () => _firestore.collection('sessions').doc(sessionId).update({
        'status': 'paused',
        ...activityStamp(),
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

  /// Resume the session (host only — Z-RT-005).
  Future<void> resumeSession(String sessionId, String userId) async {
    await _assertCallerIsSessionHost(sessionId, userId);
    await withRetry(
      () => _firestore.collection('sessions').doc(sessionId).update({
        'status': 'active',
        ...activityStamp(),
      }),
    );

    await addSessionEvent(
      sessionId: sessionId,
      type: SessionEventType.cheer,
      userId: userId,
      text: 'Session resumed',
    );
  }

  Future<void> _assertCallerIsSessionHost(
    String sessionId,
    String userId,
  ) async {
    final snap = await _firestore.collection('sessions').doc(sessionId).get();
    final data = snap.data();
    if (data == null) {
      throw StateError('Session $sessionId not found');
    }
    if ((data['hostId'] ?? '').toString() != userId) {
      throw StateError('Only the session host may pause or resume');
    }
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
    String? clientEventId,
  }) async {
    final startTime = DateTime.now();
    final eventId =
        clientEventId ??
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
              'data': ?data,
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
      await _ref.read(offlineManagerProvider).queueOperation(
        'session_event',
        {
          'sessionId': sessionId,
          'type': type.value,
          'userId': userId,
          'text': text,
          'clientEventId': eventId,
          'data': ?data,
        },
        id: 'session_event_$eventId',
      );
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
      final eventId =
          event['clientEventId'] as String? ??
          '${type}_${userId}_${timestamp.millisecondsSinceEpoch}';

      final docRef = _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('events')
          .doc(eventId);

      batch.set(docRef, {
        ...event,
        'timestamp': event['timestamp'] ?? FieldValue.serverTimestamp(),
      }..remove('clientEventId'));
    }

    await withRetry(() => batch.commit());
  }

  /// End a session.
  /// Matches RN endSession with batched writes for atomicity.
  /// Ends [userId]'s own part in the session, leaving it live for everyone
  /// else.
  ///
  /// Terminating has always been meant per-member: one member walking out must
  /// not end their partner's workout. The remaining participant is notified and
  /// gets to choose whether to finish too or carry on alone — this method never
  /// makes that choice for them.
  ///
  /// The last member out is different: with nobody left, the session is
  /// genuinely over, so this delegates to [endSession] and all the existing
  /// scoring, streak and workout-logging behaviour runs unchanged.
  Future<void> terminateForMember(String sessionId, String userId) async {
    final session = await getSession(sessionId);
    if (session == null) return;
    if (!session.participants.contains(userId)) return;
    if (session.hasTerminated(userId)) return;

    final remaining = session.participants
        .where((id) => id != userId && !session.hasTerminated(id))
        .toList();

    if (remaining.isEmpty) {
      // Nobody left to carry it on — this is a real session end.
      await endSession(sessionId, userId, null);
      return;
    }

    final updates = <String, dynamic>{
      'endedParticipants': FieldValue.arrayUnion([userId]),
      ...activityStamp(),
    };

    // If the leaver held the turn, hand it on in the same write. Otherwise the
    // session stalls on an activeUserId belonging to someone who has gone.
    if (session.activeUserId == userId) {
      final next = nextTurnHolder(
        currentUserId: userId,
        session: session,
        presence: await _presenceByUser(sessionId),
        now: DateTime.now().toUtc(),
      );
      updates['activeUserId'] = next ?? remaining.first;
    }

    await withRetry(
      () => _firestore.collection('sessions').doc(sessionId).update(updates),
    );

    await addSessionEvent(
      sessionId: sessionId,
      type: SessionEventType.leave,
      userId: userId,
      text: 'Left the session',
    );

    await _notifyPartnersOfDeparture(
      sessionId: sessionId,
      leaverId: userId,
      recipients: remaining,
    );
  }

  /// Tells the remaining participants their partner has gone.
  ///
  /// The notification is for speed only. The finish-or-continue choice itself
  /// renders from `endedParticipants` on the session, so a member who never
  /// receives this — phone off, no signal, notification dismissed — still gets
  /// the choice the next time they open the session.
  ///
  /// Best-effort: a failed notification must never leave the leaver stuck in a
  /// session they have already left.
  Future<void> _notifyPartnersOfDeparture({
    required String sessionId,
    required String leaverId,
    required List<String> recipients,
  }) async {
    try {
      final leaver = await _ref.read(userCacheServiceProvider).getUser(leaverId);
      final leaverName = leaver?.displayName ?? 'Your partner';
      final notificationService = _ref.read(notificationServiceProvider);

      for (final recipientId in recipients) {
        await notificationService.notifyPartnerLeft(
          recipientId: recipientId,
          sessionId: sessionId,
          leaverId: leaverId,
          leaverName: leaverName,
        );
      }
    } catch (e) {
      debugPrint('[SessionService] partner-left notification failed: $e');
    }
  }

  /// Ends the session for [userId]. Returns the locally computed workout score
  /// and any newly set PRs for recap UX. Aggregate score/streak/PR persistence
  /// is server-owned (Z-DATA-001) and is not written from the client.
  Future<WorkoutScoreResult> endSession(
    String sessionId,
    String userId,
    SessionSummary? summary,
  ) async {
    // Get session data for workout logging
    final session = await getSession(sessionId);
    if (session == null) {
      return const WorkoutScoreResult(
        score: 0,
        updatedStrengthPrs: {},
        updatedCardioPrs: {},
      );
    }

    final sessionDuration = DateTime.now().difference(session.startedAt);
    // `partnerKind` is stamped at session creation, before the invited friend
    // responds — on its own it would pay the buddy bonus for a session the
    // inviter trained alone with a pending or declined invite. Require the
    // invite to have actually been accepted.
    final hasRealHumanBuddy =
        session.partnerKind == PairedPartnerKind.realFriend &&
        session.invitationStatus == WorkoutInvitationStatus.accepted;
    // `session.type` stores a WorkoutType.value ('gym', 'running', ...), never
    // the scorer's category literals. Map it to the category the scorer branches
    // on ('strength' / 'cardio' / 'flexibility' / 'mixed').
    final sessionCategory = WorkoutType.fromString(session.type).category;

    final prsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('prs');
    // Reading the PR doc is best-effort: it must never block a user from
    // finishing their session. A network/permission failure, or a doc in an
    // unexpected shape (client rules allow any shape under the user's own
    // stats/prs), degrades to "no PRs known" instead of throwing out of
    // endSession — which would otherwise brick session completion permanently.
    var currentStrengthPrs = <String, double>{};
    var currentCardioPrs = <String, double>{};
    // When the read fails we must NOT write PRs: computeWorkoutScore treats an
    // absent personal best as first-time-ever and hands back today's number as
    // the new PR, which would silently overwrite a real stored PR downward.
    var canWritePrs = false;
    try {
      final prsSnapshot = await prsRef.get();
      final Object? rawPrsData = prsSnapshot.data();
      final prsData = rawPrsData is Map<Object?, Object?>
          ? rawPrsData
          : const <Object?, Object?>{};
      currentStrengthPrs = parsePersonalBests(prsData['strength']);
      currentCardioPrs = parsePersonalBests(prsData['cardio']);
      canWritePrs = true;
    } catch (e) {
      debugPrint(
        '[SessionService] Failed to read personal records for $userId; '
        'scoring without PR history and skipping PR writes: $e',
      );
      currentStrengthPrs = <String, double>{};
      currentCardioPrs = <String, double>{};
      canWritePrs = false;
    }

    // Streak counters are maintained here rather than recomputed on read.
    // Reading them is best-effort for the same reason the PR read is: a failure
    // must not stop a user finishing their session. When the read fails we skip
    // the streak write entirely rather than advance from a zeroed state, which
    // would reset a real streak to 1.
    StreakState? previousStreak;
    try {
      final userSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      previousStreak = streakStateFromUserData(userSnapshot.data());
    } catch (e) {
      debugPrint(
        '[SessionService] Failed to read streak state for $userId; '
        'skipping streak update for this session: $e',
      );
    }
    final nextStreak = previousStreak == null
        ? null
        : advanceStreak(previous: previousStreak, completedAt: DateTime.now());

    final scoreResult = computeWorkoutScore(
      sessionDuration: sessionDuration,
      hasRealHumanBuddy: hasRealHumanBuddy,
      sessionType: sessionCategory,
      summary: summary,
      currentStrengthPrs: currentStrengthPrs,
      currentCardioPrs: currentCardioPrs,
    );

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

    // 3. Log workout for the caller only — partners write their own row when
    // they end. userId must match auth (Z-DATA-001 / Z-SEC-002).
    final workoutRef = _firestore.collection('workouts').doc();
    batch.set(workoutRef, {
      'userId': userId,
      'sessionId': sessionId,
      'type': session.type,
      'title': session.title,
      'summary': summary?.toMap(),
      'participants': session.participants,
      'endedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Score / streak / PR persistence is server-owned (Z-DATA-001). Local
    // scoreResult is returned for recap UX; do not write it here.
    // Cloud Function applySessionScore (stub) will grant aggregates later.
    debugPrint(
      '[SessionService] endSession local score=${scoreResult.score} '
      '(not persisted; nextStreak=${nextStreak?.currentStreak}; '
      'canWritePrs=$canWritePrs)',
    );

    await withRetryCircuitBreakerVoid(
      () => batch.commit(),
      operationType: 'session_end',
      maxFailures: 5,
      cooldownDuration: const Duration(seconds: 30),
    );

    // Numerator of the abandonment rate: a session that reached a real ending
    // because somebody chose to finish it, as opposed to one that expired with
    // nobody in it.
    _trackFunnelEvent(
      ResumeSessionAnalyticsEvent.sessionCompleted,
      sessionId,
    );

    if (hasRealHumanBuddy) {
      unawaited(
        _ref
            .read(buddyReviewPromptServiceProvider)
            .onBuddySessionCompleted()
            .catchError(
              (e) => debugPrint('[SessionService] review prompt skipped: $e'),
            ),
      );
    }

    return scoreResult;
  }

  /// Records a funnel event without ever letting it affect the caller.
  ///
  /// A session must complete whether or not its telemetry does — including when
  /// the analytics dependency is unavailable entirely.
  void _trackFunnelEvent(ResumeSessionAnalyticsEvent event, String sessionId) {
    try {
      unawaited(
        _ref
            .read(sessionAnalyticsServiceProvider)
            .trackResumeEvent(event, sessionId: sessionId),
      );
    } catch (e) {
      debugPrint('[SessionService] funnel telemetry skipped: $e');
    }
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

  /// Save a user's gym setup plan for a session.
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
    await _ref
        .read(sessionAnalyticsServiceProvider)
        .trackPairedSessionEvent(
          SessionAnalyticsService.pairedSessionEventPayload(
            eventName: PairedSessionAnalyticsEvent.planModified,
            sessionId: sessionId,
            hostId: plan.userId,
            partnerId: plan.userId,
            partnerKind: PairedPartnerKind.realFriend.value,
            mode: SessionMode.turnBased.value,
            extra: {
              'planUserId': plan.userId,
              'workoutType': plan.workoutType,
              'source': plan.source.value,
            },
          ),
        );
  }

  /// Ensure a participant has a personal gym plan for the setup flow.
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
    if (existingUserPlan.exists && existingUserPlan.data() != null) {
      return GymSessionPlan.fromMap(existingUserPlan.data()!);
    }

    final hostPlanSnapshot = await plansCollection.doc(hostId).get();
    if (!hostPlanSnapshot.exists || hostPlanSnapshot.data() == null) {
      throw Exception('Host gym plan not found for session: $sessionId');
    }

    final hostPlan = GymSessionPlan.fromMap(hostPlanSnapshot.data()!);
    final clonedPlan = userId == hostId
        ? GymSessionPlan(
            userId: userId,
            source: GymSessionPlanSource.hostTemplate,
            isReady: false,
            workoutType: hostPlan.workoutType,
            stages: List<PlannedWorkoutStage>.from(hostPlan.stages),
            targets: Map<String, dynamic>.from(hostPlan.targets),
            exercises: hostPlan.exercises
                .map((exercise) => PlannedExercise.fromMap(exercise.toMap()))
                .toList(),
            updatedAt: hostPlan.updatedAt,
          )
        : copyHostGymPlanForInvitee(hostPlan: hostPlan, inviteeId: userId);

    await userPlanRef.set(clonedPlan.toMap());
    if (userId != hostId) {
      await _ref
          .read(sessionAnalyticsServiceProvider)
          .trackPairedSessionEvent(
            SessionAnalyticsService.pairedSessionEventPayload(
              eventName: PairedSessionAnalyticsEvent.planCopied,
              sessionId: sessionId,
              hostId: hostId,
              partnerId: userId,
              partnerKind: PairedPartnerKind.realFriend.value,
              mode: SessionMode.turnBased.value,
              extra: {'workoutType': clonedPlan.workoutType},
            ),
          );
    }
    return clonedPlan;
  }

  /// Update readiness and move setup sessions into the live phase once everyone is ready.
  Future<void> setGymPlanReady({
    required String sessionId,
    required String userId,
    required bool isReady,
  }) async {
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final plansCollection = sessionRef.collection('plans');
    final userPlanRef = plansCollection.doc(userId);

    bool allParticipantsReady = false;
    bool wentLive = false;
    String hostId = '';
    String partnerId = '';
    String mode = SessionMode.turnBased.value;

    await _firestore.runTransaction<void>((transaction) async {
      final sessionSnapshot = await transaction.get(sessionRef);
      final sessionData = sessionSnapshot.data();
      if (sessionData == null) {
        throw Exception('Session not found: $sessionId');
      }
      hostId = (sessionData['hostId'] ?? '').toString();
      final participantTypes =
          (sessionData['participantTypes'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          const <String, String>{};
      mode = derivePairedSessionMode(participantTypes).value;

      final participants =
          (sessionData['participants'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];
      partnerId = participants.firstWhere(
        (participantId) => participantId != userId,
        orElse: () => '',
      );
      final currentPhase = SessionPhase.fromString(
        sessionData['phase'] as String? ?? SessionPhase.live.value,
      );

      final userPlanSnapshot = await transaction.get(userPlanRef);
      final userPlanData = userPlanSnapshot.data();
      if (!userPlanSnapshot.exists || userPlanData == null) {
        throw StateError(
          'Gym plan must exist before readiness can be updated.',
        );
      }
      // Firestore transactions require ALL reads before ANY write, so read the
      // other participants' plans first and defer every update to the end.
      //
      // Readiness must be read for EVERY current participant (not just the
      // invited roster) so a matchmaking partner — added via joinSession and
      // absent from invitedUserIds — is not ignored by the gate.
      final planReadiness = <String, bool>{userId: isReady};
      for (final participantId in participants) {
        if (participantId == userId) continue;
        final memberPlanSnapshot = await transaction.get(
          plansCollection.doc(participantId),
        );
        final memberPlanData = memberPlanSnapshot.data();
        planReadiness[participantId] =
            memberPlanSnapshot.exists && memberPlanData != null
            ? GymSessionPlan.fromMap(memberPlanData).isReady
            : false;
      }

      // --- reads done; writes start here ---
      transaction.update(userPlanRef, {'isReady': isReady});

      final invitedUserIds =
          (sessionData['invitedUserIds'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];
      final roster = requiredRoster(
        hostId: hostId,
        invitedUserIds: invitedUserIds,
      );
      final invitationStatus = sessionData['invitationStatus'] as String?;
      allParticipantsReady = shouldGoLive(
        requiredRoster: roster,
        participants: participants,
        planReadiness: planReadiness,
        invitationStatus: invitationStatus,
      );

      if (currentPhase == SessionPhase.setup && allParticipantsReady) {
        // Mode is derived from participantTypes — do not persist (Z-DATA-002).
        final liveUpdate = <String, dynamic>{
          'phase': SessionPhase.live.value,
          ...activityStamp(),
        };
        if (sessionData['sharedClockStartedAt'] == null) {
          liveUpdate['sharedClockStartedAt'] = FieldValue.serverTimestamp();
        }
        transaction.update(sessionRef, liveUpdate);
        wentLive = true;
      }
    });

    await _ref
        .read(sessionAnalyticsServiceProvider)
        .trackPairedSessionEvent(
          SessionAnalyticsService.pairedSessionEventPayload(
            eventName: PairedSessionAnalyticsEvent.planReady,
            sessionId: sessionId,
            hostId: hostId,
            partnerId: partnerId,
            partnerKind: PairedPartnerKind.realFriend.value,
            mode: mode,
            extra: {'planUserId': userId, 'isReady': isReady},
          ),
        );

    if (wentLive && mode == SessionMode.parallel.value) {
      await _ref
          .read(sessionAnalyticsServiceProvider)
          .trackPairedSessionEvent(
            SessionAnalyticsService.pairedSessionEventPayload(
              eventName: PairedSessionAnalyticsEvent.mixedSessionStarted,
              sessionId: sessionId,
              hostId: hostId,
              partnerId: partnerId,
              partnerKind: PairedPartnerKind.realFriend.value,
              mode: mode,
            ),
          );
    }

    if (isReady && !allParticipantsReady) {
      await _ref
          .read(sessionAnalyticsServiceProvider)
          .trackPairedSessionEvent(
            SessionAnalyticsService.pairedSessionEventPayload(
              eventName: PairedSessionAnalyticsEvent.readinessBlocked,
              sessionId: sessionId,
              hostId: hostId,
              partnerId: partnerId,
              partnerKind: PairedPartnerKind.realFriend.value,
              mode: mode,
              extra: {'waitingOnPlan': true},
            ),
          );
    }
  }

  /// Listen to a user's gym setup plan.
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
  /// Paired gym sessions switch turns only between exactly two gym participants.
  ///
  /// The `activeUserId` write is transactional (Z-RT-002): only the current
  /// active holder may pass the turn, so concurrent clients cannot race.
  Future<void> switchTurn(String sessionId, String currentUserId) async {
    final session = await getSession(sessionId);
    if (session == null) return;

    if (session.participants.length != 2) return;
    final allGym = session.participants.every(
      (participantId) =>
          session.participantTypes[participantId] == WorkoutType.gym.value ||
          session.participantTypes[participantId] == null &&
              session.type == WorkoutType.gym.value,
    );
    if (!allGym) return;

    final currentIndex = session.participants.indexOf(currentUserId);
    if (currentIndex == -1) {
      debugPrint('[SessionService] Current user not in participants list');
      return;
    }

    // Presence is advisory and read outside the transaction. Inside the txn we
    // re-check that [currentUserId] is still activeUserId before writing.
    final presence = await _presenceByUser(sessionId);
    final preferredNext =
        nextTurnHolder(
          currentUserId: currentUserId,
          session: session,
          presence: presence,
          now: DateTime.now().toUtc(),
        ) ??
        session.participants[(currentIndex + 1) % session.participants.length];

    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    String? committedNextId;

    try {
      await withRetry(() async {
        await _firestore.runTransaction<void>((transaction) async {
          final snap = await transaction.get(sessionRef);
          final data = snap.data();
          if (data == null) return;

          final participants =
              (data['participants'] as List<dynamic>?)?.cast<String>() ??
              const <String>[];
          if (participants.length != 2) return;
          if (!participants.contains(currentUserId)) return;

          final activeUserId = data['activeUserId'] as String?;
          // Stale pass: another client already advanced the turn.
          if (activeUserId != null && activeUserId != currentUserId) {
            return;
          }

          final nextUserId = preferredNext;
          transaction.update(sessionRef, {
            'activeUserId': nextUserId,
            ...activityStamp(),
          });
          committedNextId = nextUserId;
        });
      });
    } catch (e) {
      debugPrint('[SessionService] switchTurn transaction failed: $e');
      return;
    }

    if (committedNextId == null) return;
    final nextUserId = committedNextId!;

    final nextUser = await _ref
        .read(userCacheServiceProvider)
        .getUser(nextUserId);
    final nextUserName = nextUser?.displayName ?? 'User';

    await addSessionEvent(
      sessionId: sessionId,
      type: SessionEventType.turnSwitch,
      userId: currentUserId,
      text: "$nextUserName's turn!",
      data: {'nextUserId': nextUserId, 'nextUserName': nextUserName},
    );

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
      final lastWeight = <String, double>{};
      final lastReps = <String, int>{};
      final lastSetSeconds = <String, int>{};
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
          // Events are iterated oldest-first, so the last write here per user
          // ends up being their most recent logged set.
          lastWeight[userId] = weight;
          lastReps[userId] = reps;
          final setSeconds = (data?['durationSeconds'] as num?)?.toInt();
          if (setSeconds != null) lastSetSeconds[userId] = setSeconds;

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
          'lastWeight': lastWeight[userId],
          'lastReps': lastReps[userId],
          'lastSetSeconds': lastSetSeconds[userId],
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

  /// Fetch a user's recent completed sessions for the Train home screen.
  Future<List<Session>> getUserSessions(String userId, {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .where('participants', arrayContains: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<Session>> watchUserSessions(String userId, {int limit = 10}) {
    return _firestore
        .collection('sessions')
        .where('participants', arrayContains: userId)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList(),
        );
  }

  /// Terminal cancel for a paired setup handshake (host cancels or friend leaves
  /// after joining). A paired handshake is cancelled, not downgraded to solo.
  /// Leaves phase/participants/participantTypes/invitationStatus and plan docs
  /// intact for audit. status is not frozen for participants, so this passes
  /// isParticipantSessionUpdate; participantTypes is unchanged (empty diff).
  Future<void> cancelSetup({
    required String sessionId,
    required String byUserId,
    required String reason,
  }) async {
    await withRetry(
      () => _firestore.collection('sessions').doc(sessionId).update({
        'status': SessionStatus.cancelled.value,
        'endedAt': FieldValue.serverTimestamp(),
        'cancelledBy': byUserId,
        'cancelReason': reason,
      }),
    );
  }
}

/// Session service provider.
/// ---------------------------------------------------------------------------
/// Session live-snapshot lifetime map (Z-PERF-002)
///
/// | Provider | Scope | Dispose |
/// |---|---|---|
/// | currentSessionProvider | sessionId | autoDispose + 2m keepAlive grace |
/// | gymSessionPlanProvider | sessionId+userId | autoDispose |
/// | sessionEventsProvider | sessionId | autoDispose |
/// | debouncedSessionEventsProvider | sessionId | autoDispose |
/// | recentSessionEventsProvider | sessionId+limit | autoDispose |
/// | sessionProgressProvider | sessionId | autoDispose |
/// | throttledSessionEventsProvider | sessionId | autoDispose |
/// | adaptiveDebouncedSessionEventsProvider | sessionId | autoDispose (cancels sub) |
/// | configurableDebouncedSessionEventsProvider | sessionId+debounce | autoDispose |
///
/// Room UI should prefer the autoDispose providers above. Non-session global
/// streams (auth, connectivity) live in their own modules and stay warm.
/// ---------------------------------------------------------------------------

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(ref.watch(authFirestoreProvider), ref);
});

/// Stream provider for current session.
///
/// Session-scoped, so it autoDisposes with the session room rather than
/// holding a Firestore listener for every session ever opened. The grace
/// window keeps a brief navigation away from tearing it down and re-running
/// the participant cache warm below, which is a burst of reads.
final currentSessionProvider = StreamProvider.autoDispose.family<Session?, String>((
  ref,
  sessionId,
) {
  final link = ref.keepAlive();
  final grace = Timer(const Duration(minutes: 2), link.close);
  ref.onDispose(grace.cancel);

  // Warm cache when listening starts
  ref.read(userCacheServiceProvider).warmSessionParticipants(sessionId);
  return ref.watch(sessionServiceProvider).listenToSession(sessionId);
});

/// Stream provider for a participant's gym setup plan.
final gymSessionPlanProvider =
    StreamProvider.autoDispose.family<GymSessionPlan?, ({String sessionId, String userId})>(
      (ref, params) {
        return ref
            .watch(sessionServiceProvider)
            .listenToGymPlan(params.sessionId, params.userId);
      },
    );

/// Stream provider for session events.
final sessionEventsProvider =
    StreamProvider.autoDispose.family<List<TimelineEvent>, String>((ref, sessionId) {
      return ref.watch(sessionServiceProvider).listenToSessionEvents(sessionId);
    });

/// Debounced session events provider (reduces rebuild frequency).
/// Use this for UI components that don't need immediate updates.
final debouncedSessionEventsProvider =
    StreamProvider.autoDispose.family<List<TimelineEvent>, String>((ref, sessionId) {
      return ref
          .watch(sessionServiceProvider)
          .listenToSessionEvents(sessionId)
          .debounceTime(const Duration(milliseconds: 300));
    });

/// Stream provider for recent session events (paginated).
final recentSessionEventsProvider = StreamProvider.autoDispose
    .family<List<TimelineEvent>, ({String sessionId, int limit})>(
      (ref, params) {
        return ref
            .watch(sessionServiceProvider)
            .listenToRecentSessionEvents(params.sessionId, limit: params.limit);
      },
    );

/// Stream provider for real-time participant progress.
/// Returns aggregated progress data per participant.
final sessionProgressProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>, String>((ref, sessionId) {
      return ref
          .watch(sessionServiceProvider)
          .listenToSessionProgress(sessionId)
          .debounceTime(const Duration(milliseconds: 500));
    });

/// Throttled session events provider - emits first event immediately then throttles.
/// Use for UI-critical updates that need immediate first response.
final throttledSessionEventsProvider =
    StreamProvider.autoDispose.family<List<TimelineEvent>, String>((ref, sessionId) {
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
    StreamProvider.autoDispose.family<List<TimelineEvent>, String>((ref, sessionId) {
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
    StreamProvider.autoDispose.family<
      List<TimelineEvent>,
      ({String sessionId, Duration debounce})
    >((ref, params) {
      return ref
          .watch(sessionServiceProvider)
          .listenToSessionEvents(params.sessionId)
          .debounceTime(params.debounce);
    });

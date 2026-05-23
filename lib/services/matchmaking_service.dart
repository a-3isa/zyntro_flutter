import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/constants.dart';
import '../features/auth/auth_providers.dart';
import 'session_service.dart';

sealed class MatchmakingOutcome {
  const MatchmakingOutcome();
}

class MatchFound extends MatchmakingOutcome {
  final String sessionId;
  final String queueDocId;
  const MatchFound({required this.sessionId, required this.queueDocId});
}

class WaitingForMatch extends MatchmakingOutcome {
  final String queueDocId;
  const WaitingForMatch({required this.queueDocId});
}

class MatchmakingService {
  final FirebaseFirestore _firestore;
  final SessionService _sessionService;

  MatchmakingService(this._firestore, this._sessionService);

  /// Enter the matchmaking queue for a given workout type.
  ///
  /// Creates a waiting entry, then immediately searches for a partner.
  /// Returns [MatchFound] with a sessionId if paired instantly, or
  /// [WaitingForMatch] with a queueDocId to listen to.
  Future<MatchmakingOutcome> joinQueue({
    required String userId,
    required WorkoutType workoutType,
  }) async {
    // Write our own entry first so we're discoverable to others.
    final myDocRef = _firestore.collection('matchmaking_queue').doc();
    await myDocRef.set({
      'userId': userId,
      'workoutType': workoutType.value,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Look for a waiting partner with the same workout type.
    final snapshot = await _firestore
        .collection('matchmaking_queue')
        .where('workoutType', isEqualTo: workoutType.value)
        .where('status', isEqualTo: 'waiting')
        .where('userId', isNotEqualTo: userId)
        .limit(5)
        .get();

    if (snapshot.docs.isEmpty) {
      return WaitingForMatch(queueDocId: myDocRef.id);
    }

    // Try to atomically claim one of the candidates.
    for (final partnerDoc in snapshot.docs) {
      try {
        final partnerId = partnerDoc.data()['userId'] as String;

        // Optimistic claim: mark partner as 'claiming' so no one else takes them.
        await _firestore.runTransaction<void>((tx) async {
          final snap = await tx.get(partnerDoc.reference);
          if (!snap.exists || snap.data()?['status'] != 'waiting') {
            throw const _AlreadyClaimedException();
          }
          tx.update(partnerDoc.reference, {
            'status': 'claiming',
            'claimedBy': userId,
          });
        });

        // Create the shared session.
        final sessionId = await _sessionService.createSession(
          hostId: userId,
          type: workoutType.value,
          title: '${workoutType.displayName} Session',
          phase: workoutType == WorkoutType.gym
              ? SessionPhase.setup
              : SessionPhase.live,
        );

        // Add partner to the session.
        await _sessionService.joinSession(sessionId, partnerId);

        // Finalize both queue docs as matched.
        final batch = _firestore.batch();
        batch.update(partnerDoc.reference, {
          'status': 'matched',
          'sessionId': sessionId,
          'matchedAt': FieldValue.serverTimestamp(),
          'matchedWithUserId': userId,
        });
        batch.update(myDocRef, {
          'status': 'matched',
          'sessionId': sessionId,
          'matchedAt': FieldValue.serverTimestamp(),
          'matchedWithUserId': partnerId,
        });
        await batch.commit();

        return MatchFound(sessionId: sessionId, queueDocId: myDocRef.id);
      } on _AlreadyClaimedException {
        // Someone else claimed this candidate first — try the next one.
        continue;
      } catch (e) {
        debugPrint('[Matchmaking] Error claiming partner: $e');
        // Roll back our claim attempt if session creation failed mid-way.
        try {
          await partnerDoc.reference.update({'status': 'waiting', 'claimedBy': FieldValue.delete()});
        } catch (_) {}
        continue;
      }
    }

    // All candidates were claimed concurrently — stay in queue.
    return WaitingForMatch(queueDocId: myDocRef.id);
  }

  /// Remove the user from the matchmaking queue.
  Future<void> cancelQueue(String queueDocId) async {
    await _firestore.collection('matchmaking_queue').doc(queueDocId).delete();
  }

  /// Stream updates for a queue entry. Emits null when the doc is deleted.
  Stream<Map<String, dynamic>?> listenToQueueEntry(String queueDocId) {
    return _firestore
        .collection('matchmaking_queue')
        .doc(queueDocId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }
}

class _AlreadyClaimedException implements Exception {
  const _AlreadyClaimedException();
}

final matchmakingServiceProvider = Provider<MatchmakingService>((ref) {
  return MatchmakingService(
    ref.watch(authFirestoreProvider),
    ref.watch(sessionServiceProvider),
  );
});

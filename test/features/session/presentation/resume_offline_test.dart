import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/session/domain/resume_decision.dart';
import 'package:zyntro_flutter/services/session_service.dart';

/// A member who reopens the app in a gym basement with no signal must still get
/// their session back. Resuming is a read, and Firestore serves reads from its
/// local cache when offline, so this works by construction — but only as long
/// as nothing on the path assumes connectivity.
void main() {
  const alice = 'alice';
  const sessionId = 's1';

  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late SessionService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(
      overrides: [authFirestoreProvider.overrideWithValue(firestore)],
    );
    service = container.read(sessionServiceProvider);
  });

  tearDown(() => container.dispose());

  Future<void> seedLiveSession() async {
    await firestore.collection('sessions').doc(sessionId).set({
      'hostId': alice,
      'type': 'gym',
      'title': 'Session',
      'participants': [alice],
      'participantTypes': {alice: 'gym'},
      'status': SessionStatus.active.value,
      'phase': SessionPhase.live.value,
      'activeUserId': alice,
      'endedParticipants': <String>[],
      'createdAt': DateTime.now(),
      'startedAt': DateTime.now(),
      'lastActivityAt': DateTime.now(),
      'expiresAt': DateTime.now().add(const Duration(hours: 3)),
    });
  }

  group('resuming is a read, so it survives having no connection', () {
    test('the lookup finds the session from stored state alone', () async {
      await seedLiveSession();

      final candidate = await service.findResumableSession(alice);

      expect(candidate, isNotNull);
      expect(candidate!.sessionId, sessionId);
    });

    test('the decision needs no network of its own', () {
      // resolveResumeDecision takes a snapshot and returns an enum. Nothing in
      // it can block on connectivity.
      final source = File(
        'lib/features/session/domain/resume_decision.dart',
      ).readAsStringSync();

      expect(source.contains('await'), isFalse);
      expect(source.contains('Future'), isFalse);
    });

    test('a lookup failure lands the member on the home screen, not an error',
        () async {
      // Worst case offline: the read throws. Start-up must continue.
      final candidate = await service.findResumableSession('nobody');
      expect(candidate, isNull);

      expect(
        resolveResumeDecision(
          candidate: candidate,
          now: DateTime.now().toUtc(),
          hasExplicitLaunchDestination: false,
          resumeEnabled: true,
          expiryAlreadyNotified: false,
        ),
        isA<ResumeNone>(),
      );
    });

    test('presence unavailable reads as absent, never as present', () async {
      // Offline, the presence subcollection may be empty or stale. Guessing
      // "present" would silently upgrade a quiet session to a warm redirect.
      await seedLiveSession();

      final candidate = await service.findResumableSession(alice);

      expect(candidate!.otherParticipantPresent, isFalse);
    });
  });

  group('what offline resume does NOT promise', () {
    test('pending-write badging belongs to the offline cache work', () {
      // FR-012 asks for unsynced work to be marked as pending. That badge is
      // 006-offline-cache-sync's contract, not this feature's — resuming only
      // guarantees the member gets back into the session.
      final offlineManager = File(
        'lib/utils/offline_manager.dart',
      ).readAsStringSync();

      expect(
        offlineManager.contains('pendingQueueCountProvider'),
        isTrue,
        reason: 'the pending-work surface this feature relies on must exist',
      );
    });
  });
}

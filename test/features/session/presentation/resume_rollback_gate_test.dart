import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/constants/feature_flags.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/session/domain/resume_decision.dart';
import 'package:zyntro_flutter/services/session_analytics_service.dart';

/// Constitution IV requires a **tested** rollback path and active telemetry
/// before cutover — not after. These are the two ship gates for US1.
///
/// The rollback path has to be provable without a release: if flipping the
/// switch needed a new build, the switch would not be a rollback path at all.
void main() {
  group('rollback: the kill switch is genuinely runtime-flippable', () {
    test('the flag lives in Firestore, not in a compile-time constant', () {
      final source =
          File('lib/core/constants/feature_flags.dart').readAsStringSync();

      // A `static bool get` here would need an app-store release to change,
      // which takes days. That is not a rollback path.
      expect(source.contains(kRuntimeFlagsCollection), isTrue);
      expect(source.contains(kRuntimeFlagsDocument), isTrue);
      expect(
        source.contains('static bool get isResumeActiveSessionEnabled =>'),
        isFalse,
        reason: 'the live value must not be a compile-time constant',
      );
    });

    test('reads true when the console has it on', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection(kRuntimeFlagsCollection)
          .doc(kRuntimeFlagsDocument)
          .set({'resumeActiveSessionEnabled': true});

      final container = ProviderContainer(
        overrides: [authFirestoreProvider.overrideWithValue(firestore)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(resumeActiveSessionEnabledProvider.future),
        isTrue,
      );
    });

    test('reads false the moment the console flips it — no rebuild', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection(kRuntimeFlagsCollection)
          .doc(kRuntimeFlagsDocument)
          .set({'resumeActiveSessionEnabled': false});

      final container = ProviderContainer(
        overrides: [authFirestoreProvider.overrideWithValue(firestore)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(resumeActiveSessionEnabledProvider.future),
        isFalse,
      );
    });

    test('falls back to the default when the document is missing', () async {
      // Start-up must never block or fail on this read.
      final container = ProviderContainer(
        overrides: [
          authFirestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(resumeActiveSessionEnabledProvider.future),
        FeatureFlags.isResumeActiveSessionEnabledByDefault,
      );
    });

    test('falls back when the stored value is the wrong shape', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection(kRuntimeFlagsCollection)
          .doc(kRuntimeFlagsDocument)
          .set({'resumeActiveSessionEnabled': 'yes please'});

      final container = ProviderContainer(
        overrides: [authFirestoreProvider.overrideWithValue(firestore)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(resumeActiveSessionEnabledProvider.future),
        FeatureFlags.isResumeActiveSessionEnabledByDefault,
      );
    });

    test('with the switch off the app behaves exactly as it did before', () {
      // Every decision collapses to "do nothing" — no redirect, no prompt, no
      // expiry notice — which is the pre-feature behaviour.
      for (final present in [true, false]) {
        for (final activity in [Duration.zero, const Duration(hours: 1)]) {
          for (final expiry in [
            const Duration(hours: 1),
            const Duration(seconds: -1),
          ]) {
            final decision = resolveResumeDecision(
              candidate: ResumeCandidate(
                sessionId: 's1',
                workoutType: 'gym',
                phase: SessionPhase.live,
                status: SessionStatus.active,
                lastActivityAt: DateTime.utc(2026, 8, 5, 12).subtract(activity),
                expiresAt: DateTime.utc(2026, 8, 5, 12).add(expiry),
                memberHasTerminated: false,
                otherParticipantPresent: present,
              ),
              now: DateTime.utc(2026, 8, 5, 12),
              hasExplicitLaunchDestination: false,
              resumeEnabled: false,
              expiryAlreadyNotified: false,
            );
            expect(decision, isA<ResumeNone>());
          }
        }
      }
    });
  });

  group('rollback: expiry keeps running with the switch off', () {
    test('the scheduled function is not gated by any flag', () {
      // This is the sharp edge. Termination-on-close is gone, so if expiry were
      // also gated, turning the feature off would leave every live session
      // running forever with nothing able to close it.
      final functions = File('functions/index.js').readAsStringSync();
      final start = functions.indexOf('exports.expireStaleSessions');
      final body = functions.substring(start, start + 900);

      expect(body.contains('resumeActiveSessionEnabled'), isFalse);
      expect(body.contains('featureFlags'), isFalse);
    });

    test('the flag provider is client-side only and cannot reach the sweep', () {
      final source =
          File('lib/core/constants/feature_flags.dart').readAsStringSync();
      expect(source.contains('expireStaleSessions'), isFalse);
    });
  });

  group('telemetry is live before cutover', () {
    test('every decision outcome has an event', () {
      final values =
          ResumeSessionAnalyticsEvent.values.map((e) => e.value).toList();

      expect(values, contains('session_resume_redirect'));
      expect(values, contains('session_resume_prompt_shown'));
      expect(values, contains('session_resume_prompt_answered'));
      expect(values, contains('session_partner_left_choice'));
      expect(values, contains('session_expired_swept'));
      expect(values, contains('session_resume_error'));
    });

    test('a redirect is recorded with its session id', () async {
      final firestore = FakeFirebaseFirestore();
      await SessionAnalyticsService(firestore).trackResumeEvent(
        ResumeSessionAnalyticsEvent.redirect,
        sessionId: 's1',
      );

      final written = await firestore.collection('analytics').get();
      expect(written.docs, hasLength(1));
      expect(written.docs.single.data()['type'], 'session_resume_redirect');
      expect(written.docs.single.data()['sessionId'], 's1');
    });

    test('the rollback trigger carries why it fired', () async {
      // A spike in this event is what tells an operator to flip the switch, so
      // it has to say what went wrong.
      final firestore = FakeFirebaseFirestore();
      await SessionAnalyticsService(firestore).trackResumeEvent(
        ResumeSessionAnalyticsEvent.error,
        extra: {'reason': 'lookup_failed'},
      );

      final written = await firestore.collection('analytics').get();
      expect(written.docs.single.data()['type'], 'session_resume_error');
      expect(written.docs.single.data()['reason'], 'lookup_failed');
    });

    test('telemetry never takes down the path it instruments', () async {
      // Best-effort by design: a failed analytics write must not surface into
      // start-up.
      final source =
          File('lib/services/session_analytics_service.dart').readAsStringSync();
      final start = source.indexOf('Future<void> trackResumeEvent');
      expect(source.substring(start, start + 800).contains('catch'), isTrue);
    });
  });
}

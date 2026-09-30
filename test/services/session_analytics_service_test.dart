import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/services/session_analytics_service.dart';

void main() {
  group('SessionAnalyticsService paired events', () {
    test('builds typed paired session telemetry payloads', () {
      final payload = SessionAnalyticsService.pairedSessionEventPayload(
        eventName: PairedSessionAnalyticsEvent.inviteAccepted,
        sessionId: 'session-1',
        hostId: 'host-1',
        partnerId: 'friend-1',
        partnerKind: 'real_friend',
        mode: 'parallel',
        extra: const {'workoutType': 'running'},
      );

      expect(payload['type'], 'paired_invite_accepted');
      expect(payload['sessionId'], 'session-1');
      expect(payload['hostId'], 'host-1');
      expect(payload['partnerKind'], 'real_friend');
      expect(payload['mode'], 'parallel');
      expect(payload['workoutType'], 'running');
    });

    test('defines plan review and readiness telemetry events', () {
      expect(
        PairedSessionAnalyticsEvent.planCopied.value,
        'paired_plan_copied',
      );
      expect(
        PairedSessionAnalyticsEvent.planModified.value,
        'paired_plan_modified',
      );
      expect(PairedSessionAnalyticsEvent.planReady.value, 'paired_plan_ready');
      expect(
        PairedSessionAnalyticsEvent.readinessBlocked.value,
        'paired_readiness_blocked',
      );
    });

    test('defines mixed-session progress and completion telemetry events', () {
      expect(
        PairedSessionAnalyticsEvent.mixedSessionStarted.value,
        'paired_mixed_session_started',
      );
      expect(
        PairedSessionAnalyticsEvent.progressLatency.value,
        'paired_progress_latency',
      );
      expect(
        PairedSessionAnalyticsEvent.partnerDisconnected.value,
        'paired_partner_disconnected',
      );
      expect(
        PairedSessionAnalyticsEvent.completionWrite.value,
        'paired_completion_write',
      );
    });

    test('serializes workout type extras before Firestore writes', () {
      final payload = SessionAnalyticsService.pairedSessionEventPayload(
        eventName: PairedSessionAnalyticsEvent.planModified,
        sessionId: 'session-1',
        hostId: 'host-1',
        partnerId: 'friend-1',
        partnerKind: 'real_friend',
        mode: 'turn_based',
        extra: const {'workoutType': WorkoutType.gym},
      );

      expect(payload['workoutType'], 'gym');
    });
  });
}

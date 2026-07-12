import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'session room page reads auth directly from migrated auth providers',
    () {
      final source = File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('services/auth_service.dart')));
      expect(source, isNot(contains('authStateProvider')));
      expect(source, isNot(contains('.uid')));
      expect(source, contains('authSessionProvider'));
    },
  );

  test('v2 session header uses a compact layout for narrow widths', () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    final headerStart = source.indexOf('Widget _buildV2SessionHeader');
    final headerEnd = source.indexOf('Widget _buildV2ProgressRow');
    final headerSource = source.substring(headerStart, headerEnd);

    expect(headerSource, contains('LayoutBuilder'));
    expect(headerSource, contains('isCompactHeader'));
    expect(headerSource, contains('maxWidth <'));
  });

  test(
    'v2 compact session header scrolls status chips instead of squeezing them',
    () {
      final source = File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync();

      final headerStart = source.indexOf('Widget _buildV2SessionHeader');
      final headerEnd = source.indexOf('Widget _buildV2ProgressRow');
      final headerSource = source.substring(headerStart, headerEnd);
      final compactStart = headerSource.indexOf('if (isCompactHeader)');
      final compactSource = headerSource.substring(compactStart);

      expect(compactSource, contains('SingleChildScrollView'));
      expect(compactSource, contains('scrollDirection: Axis.horizontal'));
    },
  );

  test('friend workout quickstart scenarios are represented in tasks', () {
    final tasks = File(
      'specs/001-friend-workout-sessions/tasks.md',
    ).readAsStringSync();

    expect(tasks, contains('bot paired session'));
    expect(tasks, contains('mutual-follow invitation success'));
    expect(tasks, contains('host gym plan copy'));
    expect(tasks, contains('mixed workout-type mode derivation'));
    expect(tasks, contains('rollback verification test'));
  });

  test('session room exposes setup readiness states before live start', () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    expect(source, contains('Waiting for workout plans'));
    expect(source, contains('SessionPhase.setup'));
  });

  test('session room drives turn-based gym plans from planned progress', () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    expect(source, contains('TurnPlanProgress.participantState'));
    expect(source, contains('TurnPlanProgress.nextActiveParticipant'));
    expect(source, contains('Finish Session'));
    expect(source, contains('Add Exercise'));
    expect(source, contains('pairedBotFriendId'));
    expect(source, contains('bot.gymSetSeconds'));
  });

  test('session room starts the top bar clock from the first set timer', () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    expect(source, contains('onTimerStart'));
    expect(source, contains('_ensureSharedClockStarted'));
    expect(source, contains('startSharedSessionClock'));
    expect(source, contains('sharedClockStartedAt'));
    expect(source, isNot(contains('_sessionStartTime = session.startedAt')));
  });

  test(
    'session service records plan readiness telemetry and blocked starts',
    () {
      final source = File(
        'lib/services/session_service.dart',
      ).readAsStringSync();

      expect(source, contains('PairedSessionAnalyticsEvent.planReady'));
      expect(source, contains('PairedSessionAnalyticsEvent.readinessBlocked'));
    },
  );

  // ---------------------------------------------------------------------------
  // T027 [US2] late-add exercise routes through GymExercisePickerSheet
  // ---------------------------------------------------------------------------
  test(
    'T027: late-add exercise routes through GymExercisePickerSheet, not AddExerciseDialog',
    () {
      final source = File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync();

      expect(source, contains('GymExercisePickerSheet'));
      expect(source, isNot(contains('AddExerciseDialog')));
    },
  );

  // ---------------------------------------------------------------------------
  // T028 [US2] late-add plan mutation preserves catalog/custom identity
  // ---------------------------------------------------------------------------
  test(
    'T028: late-add plan mutation uses catalog/custom picker result identity',
    () {
      final source = File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync();

      // Late-add relies on the domain helper so catalog/custom identity is
      // preserved without duplicating source-specific copy logic in the page.
      // The id includes the running order so multiple exercises added in one
      // picker batch (same millisecond timestamp) still get unique ids.
      expect(source, contains('picked.copyWithPlanFields('));
      expect(
        source,
        contains("id: 'extra_\${DateTime.now().microsecondsSinceEpoch}_\$nextOrder'"),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T055 [P] paired-session plan exercise isolation after identity-field additions
  // ---------------------------------------------------------------------------
  test('T055: each participant plan is saved under their own userId, '
      'not a shared plan path', () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    // The _openLateAddPicker builds updatedPlan with userId = currentPlan.userId
    // (the acting participant's id), not a shared or host id.
    // Both plans are stored via saveGymPlan which uses plan.userId as the doc id.
    expect(source, contains('currentPlan.userId'));
    expect(
      source,
      contains('saveGymPlan(sessionId: widget.sessionId, plan: updatedPlan)'),
    );
  });

  test(
    'T055: bot plan copy uses botGymPlanFromHostPlan — does not mutate host plan userId',
    () {
      final source = File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync();

      expect(source, contains('botGymPlanFromHostPlan(updatedPlan)'));
    },
  );
}

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

  test('the legacy auth compatibility shim is gone for good', () {
    // lib/services/auth_service.dart was a temporary bridge while session
    // flows migrated to features/auth/auth_providers.dart. The migration is
    // done and nothing imported it, so the file is deleted; this pins that.
    expect(File('lib/services/auth_service.dart').existsSync(), isFalse);
  });

  test('v2 session header uses a compact layout for narrow widths', () {
    final source = File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync();

    final headerStart = source.indexOf('Widget _buildV2SessionHeader');
    final headerEnd = source.indexOf('Widget _buildV2ProgressRow');
    // The header body moved into SessionV2Header.
    final headerSource = source.substring(headerStart, headerEnd) +
        File(
          'lib/features/session/presentation/widgets/session_v2_header.dart',
        ).readAsStringSync();

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
      // The header body moved into SessionV2Header.
    final headerSource = source.substring(headerStart, headerEnd) +
        File(
          'lib/features/session/presentation/widgets/session_v2_header.dart',
        ).readAsStringSync();
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
    final source = (File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync() +
        // Pieces of the room extracted since this contract was written.
        File('lib/features/session/presentation/widgets/session_header_chips.dart')
            .readAsStringSync() +
        File('lib/features/session/presentation/widgets/session_plan_complete_view.dart')
            .readAsStringSync() +
        File('lib/features/session/presentation/late_add_plan.dart')
            .readAsStringSync());

    expect(source, contains('Waiting for workout plans'));
    expect(source, contains('SessionPhase.setup'));
  });

  test('session room drives turn-based gym plans from planned progress', () {
    final source = (File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync() +
        // Pieces of the room extracted since this contract was written.
        File('lib/features/session/presentation/widgets/session_header_chips.dart')
            .readAsStringSync() +
        File('lib/features/session/presentation/widgets/session_plan_complete_view.dart')
            .readAsStringSync() +
        File('lib/features/session/presentation/late_add_plan.dart')
            .readAsStringSync());

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
      final source = (File(
          'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync() +
            // Pieces of the room extracted since this contract was written.
            File('lib/features/session/presentation/widgets/session_header_chips.dart')
                .readAsStringSync() +
            File('lib/features/session/presentation/widgets/session_plan_complete_view.dart')
                .readAsStringSync() +
            File('lib/features/session/presentation/late_add_plan.dart')
                .readAsStringSync());

      // Late-add relies on the domain helper so catalog/custom identity is
      // preserved without duplicating source-specific copy logic in the page.
      // The id includes the running order so multiple exercises added in one
      // picker batch (same millisecond timestamp) still get unique ids.
      expect(source, contains('picked.copyWithPlanFields('));
      expect(
        source,
        contains("id: 'extra_\${stamp()}_\$nextOrder'"),
      );
      // stamp() defaults to the microsecond clock (injectable for tests).
      expect(
        source,
        contains('DateTime.now().microsecondsSinceEpoch'),
      );
    },
  );

  // ---------------------------------------------------------------------------
  // T055 [P] paired-session plan exercise isolation after identity-field additions
  // ---------------------------------------------------------------------------
  test('T055: each participant plan is saved under their own userId, '
      'not a shared plan path', () {
    final source = (File(
      'lib/features/session/presentation/session_room_page.dart',
    ).readAsStringSync() +
        // Pieces of the room extracted since this contract was written.
        File('lib/features/session/presentation/widgets/session_header_chips.dart')
            .readAsStringSync() +
        File('lib/features/session/presentation/widgets/session_plan_complete_view.dart')
            .readAsStringSync() +
        File('lib/features/session/presentation/late_add_plan.dart')
            .readAsStringSync());

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

  // ---------------------------------------------------------------------------
  // Cardio progress scoring needs SessionSummary.averageSpeed populated. Without
  // it the scorer's cardio branch never fires, so the finish handler must set it
  // from the tracked distance and the session clock.
  // ---------------------------------------------------------------------------
  // The summary is built by buildSessionSummary() in
  // session_summary_builder.dart, which _handleFinishSession() calls; the
  // checks below read that builder (they used to slice the room page).
  test(
    'finish handler populates SessionSummary.averageSpeed from distance and elapsed',
    () {
      final room = File(
        'lib/features/session/presentation/session_room_page.dart',
      ).readAsStringSync();
      final start = room.indexOf('Future<void> _handleFinishSession()');
      expect(start, greaterThan(-1));
      expect(room.indexOf('buildSessionSummary(', start), greaterThan(start));

      final builder = File(
        'lib/features/session/presentation/session_summary_builder.dart',
      ).readAsStringSync();
      expect(builder, contains('averageSpeed: averageSpeedKmh('));
      expect(builder, contains('distanceKm: totalDistance'));
      expect(builder, contains('elapsed: activityElapsed'));
    },
  );

  // ---------------------------------------------------------------------------
  // Regression: averageSpeedKmh must be fed the time actually spent on the
  // cardio activity (myProgress.totalDuration, accumulated from logged
  // entries), not wall-clock session-room-open time. Using wall-clock elapsed
  // let a user inflate their recorded speed (and PR/progress bonus) simply by
  // closing the session promptly after finishing, instead of leaving the room
  // open idle — same distance, less wall-clock time, higher computed speed.
  // ---------------------------------------------------------------------------
  test(
    'finish handler derives cardio speed elapsed time from myProgress.totalDuration, '
    'not the wall-clock session timer',
    () {
      final builder = File(
        'lib/features/session/presentation/session_summary_builder.dart',
      ).readAsStringSync();

      // Primary path: the logged activity duration. Fallback: the wall-clock
      // time, only when there is no progress record (never a null crash).
      expect(
        builder,
        contains(RegExp(
          r'final activityElapsed = myProgress != null\s*'
          r'\?\s*Duration\(minutes: myProgress\.totalDuration\)\s*'
          r':\s*wallClockElapsed;',
        )),
      );

      // The averageSpeedKmh call site itself must use the fixed variable.
      final callSiteIndex = builder.indexOf('averageSpeed: averageSpeedKmh(');
      expect(callSiteIndex, greaterThan(-1));
      final callSite = builder.substring(callSiteIndex, callSiteIndex + 120);
      expect(callSite, contains('elapsed: activityElapsed'));
      expect(callSite, isNot(contains('elapsed: wallClockElapsed')));
    },
  );
}

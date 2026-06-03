import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zyntro_flutter/app/navigation/app_router.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/features/session/presentation/session_invite_acceptance_page.dart';
import 'package:zyntro_flutter/services/session_service.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';

class MockSessionService extends Mock implements SessionService {}

class MockUserCacheService extends Mock implements UserCacheService {}

class FakeGymSessionPlan extends Fake implements GymSessionPlan {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeGymSessionPlan());
  });

  Session makeSession({
    SessionPhase phase = SessionPhase.setup,
    List<String> participants = const ['host-1'],
  }) {
    return Session(
      id: 'session-1',
      type: 'gym',
      title: 'Gym Session',
      hostId: 'host-1',
      participants: participants,
      status: SessionStatus.active,
      phase: phase,
      participantTypes: const {'host-1': 'gym'},
      createdAt: DateTime(2026),
      startedAt: DateTime(2026),
    );
  }

  Widget buildSubject({
    required SessionService sessionService,
    required UserCacheService userCacheService,
    String sessionId = 'session-1',
  }) {
    final router = GoRouter(
      initialLocation: '/session/accept/$sessionId',
      routes: [
        GoRoute(
          path: '/session/accept/:sessionId',
          builder: (context, state) => SessionInviteAcceptancePage(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.gymSessionSetup,
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('SETUP:${state.pathParameters['sessionId']}'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.sessionRoom,
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'ROOM:${state.pathParameters['sessionId']}:${state.uri.queryParameters['type']}',
              ),
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sessionServiceProvider.overrideWithValue(sessionService),
        userCacheServiceProvider.overrideWithValue(userCacheService),
        authSessionProvider.overrideWith(
          (ref) => Stream.value(
            const AuthUserEntity(
              id: 'invitee-1',
              email: 'invitee@example.com',
              displayName: 'Invitee',
              photoUrl: null,
              emailVerified: true,
              providerIds: ['password'],
            ),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('shows host name and session type on load', (tester) async {
    final sessionService = MockSessionService();
    final userCacheService = MockUserCacheService();
    final controller = StreamController<Session?>();

    when(
      () => sessionService.listenToSession('session-1'),
    ).thenAnswer((_) => controller.stream);
    when(() => userCacheService.getUser('host-1')).thenAnswer(
      (_) async => User(
        id: 'host-1',
        displayName: 'Coach Alex',
        isPrivate: false,
        workoutPreference: WorkoutType.gym,
        beginnerFlag: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(
      () => userCacheService.warmSessionParticipants(any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildSubject(
        sessionService: sessionService,
        userCacheService: userCacheService,
      ),
    );

    controller.add(makeSession());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Coach Alex'), findsWidgets);

    await controller.close();
  });

  testWidgets('selecting the same type as host shows gym plan editor', (
    tester,
  ) async {
    final sessionService = MockSessionService();
    final userCacheService = MockUserCacheService();
    final controller = StreamController<Session?>();

    when(
      () => sessionService.listenToSession('session-1'),
    ).thenAnswer((_) => controller.stream);
    when(() => userCacheService.getUser(any())).thenAnswer(
      (_) async => User(
        id: 'host-1',
        displayName: 'Host',
        isPrivate: false,
        workoutPreference: WorkoutType.gym,
        beginnerFlag: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(
      () => userCacheService.warmSessionParticipants(any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildSubject(
        sessionService: sessionService,
        userCacheService: userCacheService,
      ),
    );

    controller.add(makeSession());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Gym is pre-selected since it's the host's type — plan editor should appear
    expect(find.byKey(const Key('gym_plan_editor')), findsAny);

    await controller.close();
  });

  testWidgets(
    'selecting a different type shows parallel info card instead of plan editor',
    (tester) async {
      final sessionService = MockSessionService();
      final userCacheService = MockUserCacheService();
      final controller = StreamController<Session?>();

      when(
        () => sessionService.listenToSession('session-1'),
      ).thenAnswer((_) => controller.stream);
      when(() => userCacheService.getUser(any())).thenAnswer(
        (_) async => User(
          id: 'host-1',
          displayName: 'Host',
          isPrivate: false,
          workoutPreference: WorkoutType.gym,
          beginnerFlag: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      when(
        () => userCacheService.warmSessionParticipants(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(
          sessionService: sessionService,
          userCacheService: userCacheService,
        ),
      );

      controller.add(makeSession());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Running type
      await tester.tap(find.text('Running'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('gym_plan_editor')), findsNothing);
      expect(find.textContaining('side-by-side'), findsAny);

      await controller.close();
    },
  );

  testWidgets(
    'already-participant guard redirects without showing join button',
    (tester) async {
      final sessionService = MockSessionService();
      final userCacheService = MockUserCacheService();
      final controller = StreamController<Session?>();

      when(
        () => sessionService.listenToSession('session-1'),
      ).thenAnswer((_) => controller.stream);
      when(() => userCacheService.getUser(any())).thenAnswer(
        (_) async => User(
          id: 'host-1',
          displayName: 'Host',
          isPrivate: false,
          workoutPreference: WorkoutType.gym,
          beginnerFlag: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      when(
        () => userCacheService.warmSessionParticipants(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(
          sessionService: sessionService,
          userCacheService: userCacheService,
        ),
      );

      // Session where invitee-1 is already a participant
      controller.add(makeSession(participants: ['host-1', 'invitee-1']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should have navigated away (setup or room)
      expect(find.text('Join Session'), findsNothing);

      await controller.close();
    },
  );

  testWidgets(
    'joining with different workout type submits a ready personal plan directly',
    (tester) async {
      final sessionService = MockSessionService();
      final userCacheService = MockUserCacheService();
      final controller = StreamController<Session?>();

      when(
        () => sessionService.listenToSession('session-1'),
      ).thenAnswer((_) => controller.stream);
      when(() => userCacheService.getUser(any())).thenAnswer(
        (_) async => User(
          id: 'host-1',
          displayName: 'Host',
          isPrivate: false,
          workoutPreference: WorkoutType.gym,
          beginnerFlag: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      when(
        () => userCacheService.warmSessionParticipants(any()),
      ).thenAnswer((_) async {});
      when(
        () => sessionService.acceptInvite(
          sessionId: any(named: 'sessionId'),
          userId: any(named: 'userId'),
          chosenWorkoutType: any(named: 'chosenWorkoutType'),
          plan: any(named: 'plan'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(
          sessionService: sessionService,
          userCacheService: userCacheService,
        ),
      );

      controller.add(makeSession());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Running'));
      await tester.pump();
      await tester.ensureVisible(find.text('Join Session'));
      await tester.tap(find.text('Join Session'));
      await tester.pump();

      final submittedPlan =
          verify(
                () => sessionService.acceptInvite(
                  sessionId: 'session-1',
                  userId: 'invitee-1',
                  chosenWorkoutType: WorkoutType.running.value,
                  plan: captureAny(named: 'plan'),
                ),
              ).captured.single
              as GymSessionPlan;

      expect(submittedPlan.userId, 'invitee-1');
      expect(submittedPlan.workoutType, WorkoutType.running);
      expect(submittedPlan.isReady, isTrue);
      expect(submittedPlan.stages, isNotEmpty);

      await controller.close();
    },
  );

  testWidgets('decline action records declined invite status', (tester) async {
    final sessionService = MockSessionService();
    final userCacheService = MockUserCacheService();
    final controller = StreamController<Session?>();

    when(
      () => sessionService.listenToSession('session-1'),
    ).thenAnswer((_) => controller.stream);
    when(
      () => sessionService.declineInvite(
        sessionId: any(named: 'sessionId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
    when(() => userCacheService.getUser(any())).thenAnswer(
      (_) async => User(
        id: 'host-1',
        displayName: 'Host',
        isPrivate: false,
        workoutPreference: WorkoutType.gym,
        beginnerFlag: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    when(
      () => userCacheService.warmSessionParticipants(any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildSubject(
        sessionService: sessionService,
        userCacheService: userCacheService,
      ),
    );

    controller.add(makeSession());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Decline'));
    await tester.pump();

    verify(
      () => sessionService.declineInvite(
        sessionId: 'session-1',
        userId: 'invitee-1',
      ),
    ).called(1);

    await controller.close();
  });
}

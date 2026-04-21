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

  Session _makeSession({
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

  Widget _buildSubject({
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

    when(() => sessionService.listenToSession('session-1'))
        .thenAnswer((_) => controller.stream);
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
    when(() => userCacheService.warmSessionParticipants(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      _buildSubject(
        sessionService: sessionService,
        userCacheService: userCacheService,
      ),
    );

    controller.add(_makeSession());
    await tester.pumpAndSettle();

    expect(find.textContaining('Coach Alex'), findsWidgets);

    await controller.close();
  });

  testWidgets(
    'selecting the same type as host shows gym plan editor',
    (tester) async {
      final sessionService = MockSessionService();
      final userCacheService = MockUserCacheService();
      final controller = StreamController<Session?>();

      when(() => sessionService.listenToSession('session-1'))
          .thenAnswer((_) => controller.stream);
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
      when(() => userCacheService.warmSessionParticipants(any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildSubject(
          sessionService: sessionService,
          userCacheService: userCacheService,
        ),
      );

      controller.add(_makeSession());
      await tester.pumpAndSettle();

      // Gym is pre-selected since it's the host's type — plan editor should appear
      expect(find.byKey(const Key('gym_plan_editor')), findsAny);

      await controller.close();
    },
  );

  testWidgets(
    'selecting a different type shows parallel info card instead of plan editor',
    (tester) async {
      final sessionService = MockSessionService();
      final userCacheService = MockUserCacheService();
      final controller = StreamController<Session?>();

      when(() => sessionService.listenToSession('session-1'))
          .thenAnswer((_) => controller.stream);
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
      when(() => userCacheService.warmSessionParticipants(any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildSubject(
          sessionService: sessionService,
          userCacheService: userCacheService,
        ),
      );

      controller.add(_makeSession());
      await tester.pumpAndSettle();

      // Tap Running type
      await tester.tap(find.text('Running'));
      await tester.pumpAndSettle();

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

      when(() => sessionService.listenToSession('session-1'))
          .thenAnswer((_) => controller.stream);
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
      when(() => userCacheService.warmSessionParticipants(any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildSubject(
          sessionService: sessionService,
          userCacheService: userCacheService,
        ),
      );

      // Session where invitee-1 is already a participant
      controller.add(
        _makeSession(participants: ['host-1', 'invitee-1']),
      );
      await tester.pumpAndSettle();

      // Should have navigated away (setup or room)
      expect(find.text('Join Session'), findsNothing);

      await controller.close();
    },
  );
}

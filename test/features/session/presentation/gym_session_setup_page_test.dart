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
import 'package:zyntro_flutter/features/session/presentation/gym_session_setup_page.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/gym_plan_editor.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';
import 'package:zyntro_flutter/services/session_service.dart';

class MockSessionService extends Mock implements SessionService {}

class MockUserCacheService extends Mock implements UserCacheService {}

Widget _buildApp({
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: Scaffold(
        body: GymSessionSetupPage(sessionId: 'session-1'),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const GymSessionPlan(
        userId: 'fallback-user',
        source: GymSessionPlanSource.personal,
        isReady: false,
        exercises: [],
      ),
    );
  });

  testWidgets('shows loading shell before the session loads', (tester) async {
    final sessionService = MockSessionService();
    final userCacheService = MockUserCacheService();
    final controller = StreamController<Session?>();

    when(() => sessionService.listenToSession('session-1')).thenAnswer(
      (_) => controller.stream,
    );
    when(
      () => sessionService.ensureGymPlan(
        sessionId: 'session-1',
        hostId: 'user-1',
        userId: 'user-1',
      ),
    ).thenAnswer(
      (_) async => const GymSessionPlan(
        userId: 'user-1',
        source: GymSessionPlanSource.hostTemplate,
        isReady: false,
        exercises: [],
      ),
    );
    when(() => userCacheService.warmSessionParticipants(any())).thenAnswer(
      (_) async {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionServiceProvider.overrideWithValue(sessionService),
          userCacheServiceProvider.overrideWithValue(userCacheService),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUserEntity(
                id: 'user-1',
                email: 'user@example.com',
                displayName: 'Athlete',
                photoUrl: null,
                emailVerified: true,
                providerIds: ['password'],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: GymSessionSetupPage(sessionId: 'session-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Preparing your gym session'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    controller.add(
      Session(
        id: 'session-1',
        type: 'gym',
        title: 'Gym Setup',
        hostId: 'user-1',
        participants: const ['user-1'],
        status: SessionStatus.active,
        phase: SessionPhase.setup,
        mode: SessionMode.turnBased,
        createdAt: DateTime(2026),
        startedAt: DateTime(2026),
      ),
    );
    await tester.pump();

    await controller.close();
  });

  testWidgets(
    'shows setup copy before redirecting to the live room when the phase becomes live',
    (tester) async {
      final sessionService = MockSessionService();
      final userCacheService = MockUserCacheService();
      final controller = StreamController<Session?>();
      final router = GoRouter(
        initialLocation: '/session/setup/session-1',
        routes: [
          GoRoute(
            path: AppRoutes.gymSessionSetup,
            builder: (context, state) {
              final sessionId = state.pathParameters['sessionId']!;
              return GymSessionSetupPage(sessionId: sessionId);
            },
          ),
          GoRoute(
            path: AppRoutes.sessionRoom,
            builder: (context, state) {
              final sessionId = state.pathParameters['sessionId']!;
              final type = state.uri.queryParameters['type'] ?? '';
              return Scaffold(
                body: Center(child: Text('ROOM:$sessionId:$type')),
              );
            },
          ),
        ],
      );

      when(() => sessionService.listenToSession('session-1')).thenAnswer(
        (_) => controller.stream,
      );
      when(
        () => sessionService.ensureGymPlan(
          sessionId: 'session-1',
          hostId: 'user-1',
          userId: 'user-1',
        ),
      ).thenAnswer(
        (_) async => const GymSessionPlan(
          userId: 'user-1',
          source: GymSessionPlanSource.hostTemplate,
          isReady: false,
          exercises: [],
        ),
      );
      when(() => userCacheService.warmSessionParticipants(any())).thenAnswer(
        (_) async {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionServiceProvider.overrideWithValue(sessionService),
            userCacheServiceProvider.overrideWithValue(userCacheService),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                const AuthUserEntity(
                  id: 'user-1',
                  email: 'user@example.com',
                  displayName: 'Athlete',
                  photoUrl: null,
                  emailVerified: true,
                  providerIds: ['password'],
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      controller.add(
        Session(
          id: 'session-1',
          type: 'gym',
          title: 'Gym Setup',
          hostId: 'user-1',
          participants: const ['user-1'],
          status: SessionStatus.active,
          phase: SessionPhase.setup,
          mode: SessionMode.turnBased,
          createdAt: DateTime(2026),
          startedAt: DateTime(2026),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('Gym session setup'), findsOneWidget);
      expect(
        find.text(
          'Prepare your plan before jumping into the live room.',
        ),
        findsOneWidget,
      );
      expect(find.byType(GymPlanEditor), findsOneWidget);

      controller.add(
        Session(
          id: 'session-1',
          type: 'gym',
          title: 'Gym Setup',
          hostId: 'user-1',
          participants: const ['user-1'],
          status: SessionStatus.active,
          phase: SessionPhase.live,
          mode: SessionMode.turnBased,
          createdAt: DateTime(2026),
          startedAt: DateTime(2026),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ROOM:session-1:gym'), findsOneWidget);

      await controller.close();
    },
  );

  testWidgets('can add and remove an exercise from the selected plan', (
    tester,
  ) async {
    final sessionService = MockSessionService();
    final userCacheService = MockUserCacheService();
    final controller = StreamController<Session?>();

    when(() => sessionService.listenToSession('session-1')).thenAnswer(
      (_) => controller.stream,
    );
    when(
      () => sessionService.ensureGymPlan(
        sessionId: 'session-1',
        hostId: 'user-1',
        userId: 'user-1',
      ),
    ).thenAnswer(
      (_) async => const GymSessionPlan(
        userId: 'user-1',
        source: GymSessionPlanSource.hostTemplate,
        isReady: false,
        exercises: [],
      ),
    );
    when(() => userCacheService.warmSessionParticipants(any())).thenAnswer(
      (_) async {},
    );

    await tester.pumpWidget(
      _buildApp(
        overrides: [
          sessionServiceProvider.overrideWithValue(sessionService),
          userCacheServiceProvider.overrideWithValue(userCacheService),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUserEntity(
                id: 'user-1',
                email: 'user@example.com',
                displayName: 'Athlete',
                photoUrl: null,
                emailVerified: true,
                providerIds: ['password'],
              ),
            ),
          ),
        ],
      ),
    );

    controller.add(
      Session(
        id: 'session-1',
        type: 'gym',
        title: 'Gym Setup',
        hostId: 'user-1',
        participants: const ['user-1'],
        status: SessionStatus.active,
        phase: SessionPhase.setup,
        mode: SessionMode.turnBased,
        createdAt: DateTime(2026),
        startedAt: DateTime(2026),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bench');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsNothing);

    await controller.close();
  });
}

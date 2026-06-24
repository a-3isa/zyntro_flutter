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
  List<PlannedExercise>? seededExercises,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: GymSessionSetupPage(
          sessionId: 'session-1',
          seededExercises: seededExercises,
        ),
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

    when(
      () => sessionService.listenToSession('session-1'),
    ).thenAnswer((_) => controller.stream);
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
    when(
      () => userCacheService.warmSessionParticipants(any()),
    ).thenAnswer((_) async {});

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
        participantTypes: const {'user-1': 'gym'},
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

      when(
        () => sessionService.listenToSession('session-1'),
      ).thenAnswer((_) => controller.stream);
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
      when(
        () => userCacheService.warmSessionParticipants(any()),
      ).thenAnswer((_) async {});

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
          participantTypes: const {'user-1': 'gym'},
          createdAt: DateTime(2026),
          startedAt: DateTime(2026),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('Gym Session Setup'), findsOneWidget);
      expect(
        find.text('Prepare your plan before jumping into the live room.'),
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
          participantTypes: const {'user-1': 'gym'},
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

    when(
      () => sessionService.listenToSession('session-1'),
    ).thenAnswer((_) => controller.stream);
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
    when(
      () => userCacheService.warmSessionParticipants(any()),
    ).thenAnswer((_) async {});

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
        participantTypes: const {'user-1': 'gym'},
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

    // 2-step picker: confirm set count to complete selection
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsNothing);

    await controller.close();
  });

  testWidgets(
    'invited same-gym user reviews and personalizes a copied host plan',
    (tester) async {
      final sessionService = MockSessionService();
      final userCacheService = MockUserCacheService();
      final controller = StreamController<Session?>();
      // The resolver watches gymSessionPlanProvider for the host plan to decide
      // whether to show friendReviewPlan vs friendWaitingForHostPlan.
      final hostPlanController = StreamController<GymSessionPlan?>();

      final hostExercise = PlannedExercise.custom(
        id: 'host-squat',
        name: 'Back Squat',
        plannedSets: 4,
        order: 0,
        muscleGroup: 'Legs',
      );

      when(
        () => sessionService.listenToSession('session-1'),
      ).thenAnswer((_) => controller.stream);
      when(
        () => userCacheService.warmSessionParticipants(any()),
      ).thenAnswer((_) async {});
      when(
        () => sessionService.saveGymPlan(
          sessionId: 'session-1',
          plan: any(named: 'plan'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => sessionService.setGymPlanReady(
          sessionId: 'session-1',
          userId: 'friend-1',
          isReady: true,
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildApp(
          seededExercises: [hostExercise],
          overrides: [
            sessionServiceProvider.overrideWithValue(sessionService),
            userCacheServiceProvider.overrideWithValue(userCacheService),
            // Provide a ready host plan so the resolver lands on friendReviewPlan.
            gymSessionPlanProvider.overrideWith(
              (ref, params) => hostPlanController.stream,
            ),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                const AuthUserEntity(
                  id: 'friend-1',
                  email: 'friend@example.com',
                  displayName: 'Friend',
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
          hostId: 'host-1',
          participants: const ['host-1', 'friend-1'],
          status: SessionStatus.active,
          phase: SessionPhase.setup,
          partnerKind: PairedPartnerKind.realFriend,
          participantTypes: const {'host-1': 'gym', 'friend-1': 'gym'},
          createdAt: DateTime(2026),
          startedAt: DateTime(2026),
        ),
      );

      // Emit a ready host plan so the resolver lands on friendReviewPlan.
      hostPlanController.add(
        GymSessionPlan(
          userId: 'host-1',
          source: GymSessionPlanSource.hostTemplate,
          isReady: true,
          exercises: [hostExercise],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Back Squat'), findsOneWidget);
      expect(
        find.text(
          'Review the host gym plan, then adjust only your personal copy.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text("I'm ready"));
      await tester.pump();

      final savedPlan =
          verify(
                () => sessionService.saveGymPlan(
                  sessionId: 'session-1',
                  plan: captureAny(named: 'plan'),
                ),
              ).captured.single
              as GymSessionPlan;

      expect(savedPlan.userId, 'friend-1');
      expect(savedPlan.source, GymSessionPlanSource.personalCopy);
      expect(savedPlan.exercises.single.plannedSets, 2);

      await controller.close();
      await hostPlanController.close();
    },
  );

  testWidgets('host with pending invite can build the plan but ready is disabled', (tester) async {
    final sessionService = MockSessionService();
    final userCacheService = MockUserCacheService();
    final controller = StreamController<Session?>();

    when(
      () => sessionService.listenToSession('session-1'),
    ).thenAnswer((_) => controller.stream);
    when(
      () => sessionService.ensureGymPlan(
        sessionId: 'session-1',
        hostId: 'host-1',
        userId: 'host-1',
      ),
    ).thenAnswer(
      (_) async => const GymSessionPlan(
        userId: 'host-1',
        source: GymSessionPlanSource.hostTemplate,
        isReady: false,
        exercises: [],
      ),
    );
    when(
      () => userCacheService.warmSessionParticipants(any()),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      _buildApp(
        overrides: [
          sessionServiceProvider.overrideWithValue(sessionService),
          userCacheServiceProvider.overrideWithValue(userCacheService),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUserEntity(
                id: 'host-1',
                email: 'host@example.com',
                displayName: 'Host',
                photoUrl: null,
                emailVerified: true,
                providerIds: ['password'],
              ),
            ),
          ),
        ],
      ),
    );

    // Session: hostId == me, participants == [me], partnerKind == realFriend,
    // partnerId == 'friend-1', invitationStatus == pending, type == gym,
    // status == active, phase == setup.
    controller.add(
      Session(
        id: 'session-1',
        type: 'gym',
        title: 'Gym Setup',
        hostId: 'host-1',
        participants: const ['host-1'],
        status: SessionStatus.active,
        phase: SessionPhase.setup,
        partnerKind: PairedPartnerKind.realFriend,
        partnerId: 'friend-1',
        invitationStatus: WorkoutInvitationStatus.pending,
        participantTypes: const {'host-1': 'gym'},
        createdAt: DateTime(2026),
        startedAt: DateTime(2026),
      ),
    );

    await tester.pumpAndSettle();

    // The host builds the plan WHILE the friend decides (invite-first):
    expect(find.byType(GymPlanEditor), findsOneWidget); // editor visible
    expect(find.text('Waiting for your buddy to join'), findsOneWidget); // ready hint
    // The "I'm ready" button is present but disabled (onPressed == null) because
    // the invited friend has not joined yet.
    final readyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, "I'm ready"),
    );
    expect(readyButton.onPressed, isNull);

    await controller.close();
  });
}

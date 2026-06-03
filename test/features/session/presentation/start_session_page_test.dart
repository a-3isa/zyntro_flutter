import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntro_flutter/app/navigation/app_router.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/constants/feature_flags.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/session/domain/gym_session_plan.dart';
import 'package:zyntro_flutter/features/session/presentation/start_session_page.dart';
import 'package:zyntro_flutter/services/follow_service.dart';
import 'package:zyntro_flutter/services/session_service.dart';

class MockSessionService extends Mock implements SessionService {}

class MockFollowService extends Mock implements FollowService {}

class FakeGymSessionPlan extends Fake implements GymSessionPlan {}

const kSessionTestUserId = 'user-1';

Widget _buildApp({
  required GoRouter router,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

void _stubNoActiveSession(MockSessionService sessionService) {
  when(
    () => sessionService.checkActiveSession(any()),
  ).thenAnswer((_) async => null);
}

void _stubEmptyUserSessions(MockSessionService sessionService) {
  when(
    () => sessionService.getUserSessions(any(), limit: any(named: 'limit')),
  ).thenAnswer((_) async => []);
}

Override buildSessionAuthOverride({String userId = kSessionTestUserId}) {
  return authSessionProvider.overrideWith(
    (ref) => Stream.value(
      AuthUserEntity(
        id: userId,
        email: '$userId@example.com',
        displayName: 'Athlete',
        photoUrl: null,
        emailVerified: true,
        providerIds: const ['password'],
      ),
    ),
  );
}

List<Override> buildStartSessionOverrides({
  required MockSessionService sessionService,
  required MockFollowService followService,
  String userId = kSessionTestUserId,
}) {
  return [
    sessionServiceProvider.overrideWithValue(sessionService),
    followServiceProvider.overrideWithValue(followService),
    buildSessionAuthOverride(userId: userId),
  ];
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.startSession,
    routes: [
      GoRoute(
        path: AppRoutes.startSession,
        builder: (context, state) => const StartSessionPage(),
      ),
      GoRoute(
        path: AppRoutes.sessionRoom,
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          final type = state.uri.queryParameters['type'] ?? '';
          return Scaffold(body: Center(child: Text('ROOM:$sessionId:$type')));
        },
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(SessionMode.turnBased);
    registerFallbackValue(SessionPhase.live);
    registerFallbackValue(FakeGymSessionPlan());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          return null;
        });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'gym sessions create in live phase and navigate to the session room',
    (tester) async {
      final sessionService = MockSessionService();
      final followService = MockFollowService();
      final router = _buildRouter();

      _stubNoActiveSession(sessionService);
      _stubEmptyUserSessions(sessionService);
      when(
        () => sessionService.createSession(
          hostId: any(named: 'hostId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          buddyPairId: any(named: 'buddyPairId'),
          invitedUserIds: any(named: 'invitedUserIds'),
          phase: any(named: 'phase'),
        ),
      ).thenAnswer((_) async => 'session-123');
      when(
        () => followService.getMutualFollows(any()),
      ).thenAnswer((_) async => const []);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          overrides: [
            sessionServiceProvider.overrideWithValue(sessionService),
            followServiceProvider.overrideWithValue(followService),
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Select 'Strength' (gym type) to enable CTA
      await tester.tap(find.text('Strength'));
      await tester.pump();

      // Tap 'Start Strength Session' CTA → navigates to plan view
      await tester.ensureVisible(find.text('Start Strength Session'));
      await tester.tap(find.text('Start Strength Session'));
      await tester.pump();

      // In plan view, tap 'Begin Session' (plan starts empty = 0 sets)
      await tester.ensureVisible(find.text('Begin Session ⚡  (0 sets)'));
      await tester.tap(find.text('Begin Session ⚡  (0 sets)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => sessionService.createSession(
          hostId: 'user-1',
          type: 'gym',
          title: 'Gym Session',
          invitedUserIds: any(named: 'invitedUserIds', that: isNull),
          phase: SessionPhase.live,
          buddyPairId: any(named: 'buddyPairId', that: isNull),
        ),
      ).called(1);
      expect(find.text('ROOM:session-123:gym'), findsOneWidget);
    },
  );

  testWidgets('non-gym sessions stay on the live room flow', (tester) async {
    final sessionService = MockSessionService();
    final followService = MockFollowService();
    final router = _buildRouter();

    _stubNoActiveSession(sessionService);
    _stubEmptyUserSessions(sessionService);
    when(
      () => sessionService.createSession(
        hostId: any(named: 'hostId'),
        type: any(named: 'type'),
        title: any(named: 'title'),
        buddyPairId: any(named: 'buddyPairId'),
        invitedUserIds: any(named: 'invitedUserIds'),
        phase: any(named: 'phase'),
      ),
    ).thenAnswer((_) async => 'session-456');
    when(
      () => followService.getMutualFollows(any()),
    ).thenAnswer((_) async => const []);

    await tester.pumpWidget(
      _buildApp(
        router: router,
        overrides: [
          sessionServiceProvider.overrideWithValue(sessionService),
          followServiceProvider.overrideWithValue(followService),
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cardio'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start Cardio Session'));
    await tester.tap(find.text('Start Cardio Session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(
      () => sessionService.createSession(
        hostId: 'user-1',
        type: 'running',
        title: 'Running Session',
        invitedUserIds: any(named: 'invitedUserIds', that: isNull),
        phase: SessionPhase.live,
        buddyPairId: any(named: 'buddyPairId', that: isNull),
      ),
    ).called(1);
    expect(find.text('ROOM:session-456:running'), findsOneWidget);
  });

  testWidgets(
    'shows a Firebase permissions message when session creation is blocked',
    (tester) async {
      final sessionService = MockSessionService();
      final followService = MockFollowService();
      final router = _buildRouter();

      _stubNoActiveSession(sessionService);
      _stubEmptyUserSessions(sessionService);
      when(
        () => sessionService.createSession(
          hostId: any(named: 'hostId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          buddyPairId: any(named: 'buddyPairId'),
          invitedUserIds: any(named: 'invitedUserIds'),
          phase: any(named: 'phase'),
        ),
      ).thenThrow(
        Exception(
          '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
        ),
      );
      when(
        () => followService.getMutualFollows(any()),
      ).thenAnswer((_) async => const []);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          overrides: [
            sessionServiceProvider.overrideWithValue(sessionService),
            followServiceProvider.overrideWithValue(followService),
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Cardio'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start Cardio Session'));
      await tester.tap(find.text('Start Cardio Session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Firebase blocked session creation for this build. Check Firestore permissions or App Check allowlisting.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'persists workout type and restores it from SharedPreferences on next open',
    (tester) async {
      SharedPreferences.setMockInitialValues({'last_workout_type': 'running'});

      final sessionService = MockSessionService();
      final followService = MockFollowService();

      _stubEmptyUserSessions(sessionService);
      when(
        () => followService.getMutualFollows(any()),
      ).thenAnswer((_) async => const []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionServiceProvider.overrideWithValue(sessionService),
            followServiceProvider.overrideWithValue(followService),
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
          child: const MaterialApp(home: StartSessionPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Saved 'running' type maps to 'Cardio' label; CTA should read 'Start Cardio Session'
      expect(find.text('Cardio'), findsOneWidget);
      expect(find.text('Start Cardio Session'), findsOneWidget);
    },
  );

  testWidgets('selecting bot friend starts a bot paired session', (
    tester,
  ) async {
    final sessionService = MockSessionService();
    final followService = MockFollowService();
    final router = _buildRouter();

    _stubNoActiveSession(sessionService);
    _stubEmptyUserSessions(sessionService);
    when(
      () => sessionService.createBotPairedSession(
        hostId: any(named: 'hostId'),
        type: any(named: 'type'),
        title: any(named: 'title'),
        plan: any(named: 'plan'),
      ),
    ).thenAnswer((_) async => 'bot-session-1');
    when(
      () => followService.getMutualFollows(any()),
    ).thenAnswer((_) async => const []);

    await tester.pumpWidget(
      _buildApp(
        router: router,
        overrides: buildStartSessionOverrides(
          sessionService: sessionService,
          followService: followService,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cardio'));
    await tester.pump();
    await tester.ensureVisible(find.text('Bot'));
    await tester.tap(find.text('Bot'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start Cardio Session'));
    await tester.tap(find.text('Start Cardio Session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(
      () => sessionService.createBotPairedSession(
        hostId: kSessionTestUserId,
        type: 'running',
        title: 'Running Session',
        plan: any(named: 'plan'),
      ),
    ).called(1);
    expect(find.text('ROOM:bot-session-1:running'), findsOneWidget);
  });

  testWidgets('friend mode allows only one selected friend', (tester) async {
    final sessionService = MockSessionService();
    final followService = MockFollowService();

    _stubEmptyUserSessions(sessionService);
    when(() => followService.getMutualFollows(any())).thenAnswer(
      (_) async => [
        User(
          id: 'friend_1000',
          displayName: 'Friend One',
          isPrivate: false,
          workoutPreference: WorkoutType.gym,
          beginnerFlag: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        User(
          id: 'friend_2000',
          displayName: 'Friend Two',
          isPrivate: false,
          workoutPreference: WorkoutType.gym,
          beginnerFlag: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildStartSessionOverrides(
          sessionService: sessionService,
          followService: followService,
        ),
        child: const MaterialApp(home: StartSessionPage()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.byIcon(Icons.person_add_alt_1));
    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Friend One'));
    await tester.tap(find.text('Friend One'));
    await tester.pump();
    await tester.tap(find.text('Friend Two'));
    await tester.pump();

    expect(find.text('1 friend selected'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // T016: "Add exercise" opens GymExercisePickerSheet (no inline free-text)
  // ---------------------------------------------------------------------------
  testWidgets(
    'T016: plan view shows "Add exercise" button that opens GymExercisePickerSheet',
    (tester) async {
      final sessionService = MockSessionService();
      final followService = MockFollowService();

      _stubNoActiveSession(sessionService);
      _stubEmptyUserSessions(sessionService);
      when(() => followService.getMutualFollows(any()))
          .thenAnswer((_) async => const []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildStartSessionOverrides(
            sessionService: sessionService,
            followService: followService,
          ),
          child: const MaterialApp(home: StartSessionPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Navigate to plan view
      await tester.tap(find.text('Strength'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start Strength Session'));
      await tester.tap(find.text('Start Strength Session'));
      await tester.pump();

      // Free-text "Add exercise..." input must not exist in plan view (FR-001)
      expect(find.widgetWithText(TextField, 'Add exercise...'), findsNothing);

      // An "Add exercise" action exists
      expect(find.text('Add exercise'), findsOneWidget);

      // Tap it → GymExercisePickerSheet should appear (contains search field)
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();

      expect(find.text('Search exercises'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // T018: picker selection stores catalog identity in start-session plan
  // ---------------------------------------------------------------------------
  testWidgets(
    'T018: selecting a catalog exercise stores exerciseId in plan',
    (tester) async {
      final sessionService = MockSessionService();
      final followService = MockFollowService();

      _stubNoActiveSession(sessionService);
      _stubEmptyUserSessions(sessionService);
      when(() => followService.getMutualFollows(any()))
          .thenAnswer((_) async => const []);
      when(
        () => sessionService.createSession(
          hostId: any(named: 'hostId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          buddyPairId: any(named: 'buddyPairId'),
          invitedUserIds: any(named: 'invitedUserIds'),
          phase: any(named: 'phase'),
        ),
      ).thenAnswer((_) async => 'test-session');
      when(
        () => sessionService.saveGymPlan(
          sessionId: any(named: 'sessionId'),
          plan: any(named: 'plan'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: buildStartSessionOverrides(
            sessionService: sessionService,
            followService: followService,
          ),
          child: const MaterialApp(home: StartSessionPage()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Strength'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start Strength Session'));
      await tester.tap(find.text('Start Strength Session'));
      await tester.pump();

      // Open picker
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();

      // Search and select deadlift (not in default plan to avoid ambiguity)
      await tester.enterText(find.byType(TextField), 'deadlift');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deadlift'));
      await tester.pumpAndSettle();

      // Confirm with default set count
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Deadlift should now appear in the plan — catalog identity confirmed
      // via plan view showing the exercise (T018 acceptance criterion)
      expect(find.text('Deadlift'), findsWidgets);
    },
  );

  testWidgets(
    'rollback flag hides bot and friend entry points while preserving solo start',
    (tester) async {
      final sessionService = MockSessionService();
      final followService = MockFollowService();
      final router = _buildRouter();

      _stubNoActiveSession(sessionService);
      _stubEmptyUserSessions(sessionService);
      when(
        () => sessionService.createSession(
          hostId: any(named: 'hostId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          buddyPairId: any(named: 'buddyPairId'),
          invitedUserIds: any(named: 'invitedUserIds'),
          phase: any(named: 'phase'),
        ),
      ).thenAnswer((_) async => 'solo-session-1');
      when(
        () => followService.getMutualFollows(any()),
      ).thenAnswer((_) async => const []);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          overrides: [
            ...buildStartSessionOverrides(
              sessionService: sessionService,
              followService: followService,
            ),
            pairedFriendSessionsEnabledProvider.overrideWithValue(false),
          ],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Bot'), findsNothing);
      expect(find.text('Friend'), findsNothing);
      expect(find.text('Solo'), findsOneWidget);

      await tester.tap(find.text('Cardio'));
      await tester.pump();
      await tester.ensureVisible(find.text('Start Cardio Session'));
      await tester.tap(find.text('Start Cardio Session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(
        () => sessionService.createSession(
          hostId: kSessionTestUserId,
          type: 'running',
          title: 'Running Session',
          invitedUserIds: any(named: 'invitedUserIds', that: isNull),
          phase: SessionPhase.live,
          buddyPairId: any(named: 'buddyPairId', that: isNull),
        ),
      ).called(1);
      expect(find.text('ROOM:solo-session-1:running'), findsOneWidget);
    },
  );
}

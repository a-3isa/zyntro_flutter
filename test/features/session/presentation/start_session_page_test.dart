import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zyntro_flutter/app/navigation/app_router.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/session/presentation/start_session_page.dart';
import 'package:zyntro_flutter/services/follow_service.dart';
import 'package:zyntro_flutter/services/session_service.dart';

class MockSessionService extends Mock implements SessionService {}

class MockFollowService extends Mock implements FollowService {}

Widget _buildApp({
  required GoRouter router,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
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
        path: AppRoutes.gymSessionSetup,
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return Scaffold(body: Center(child: Text('SETUP:$sessionId')));
        },
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
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'gym sessions create in setup phase and navigate to the setup route',
    (tester) async {
      final sessionService = MockSessionService();
      final followService = MockFollowService();
      final router = _buildRouter();

      when(
        () => sessionService.createSession(
          hostId: 'user-1',
          type: 'gym',
          title: 'Gym Session',
          buddyPairId: null,
          invitedUserIds: null,
          mode: SessionMode.turnBased,
          phase: SessionPhase.setup,
        ),
      ).thenAnswer((_) async => 'session-123');
      when(() => followService.getMutualFollows(any())).thenAnswer(
        (_) async => const [],
      );

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
      await tester.dragUntilVisible(
        find.text('Start Gym Session'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await tester.tap(find.text('Start Gym Session'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => sessionService.createSession(
          hostId: 'user-1',
          type: 'gym',
          title: 'Gym Session',
          invitedUserIds: null,
          mode: SessionMode.turnBased,
          phase: SessionPhase.setup,
          buddyPairId: null,
        ),
      ).called(1);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/session/setup/session-123',
      );
    },
  );

  testWidgets(
    'non-gym sessions stay on the live room flow',
    (tester) async {
      final sessionService = MockSessionService();
      final followService = MockFollowService();
      final router = _buildRouter();

      when(
        () => sessionService.createSession(
          hostId: 'user-1',
          type: 'running',
          title: 'Running Session',
          buddyPairId: null,
          invitedUserIds: null,
          mode: SessionMode.turnBased,
          phase: SessionPhase.live,
        ),
      ).thenAnswer((_) async => 'session-456');
      when(() => followService.getMutualFollows(any())).thenAnswer(
        (_) async => const [],
      );

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

      await tester.tap(find.text('Running'));
      await tester.pump();
      await tester.dragUntilVisible(
        find.text('Start Running Session'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
      );
      await tester.tap(find.text('Start Running Session'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => sessionService.createSession(
          hostId: 'user-1',
          type: 'running',
          title: 'Running Session',
          invitedUserIds: null,
          mode: SessionMode.turnBased,
          phase: SessionPhase.live,
          buddyPairId: null,
        ),
      ).called(1);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/session/room/session-456?type=running',
      );
    },
  );
}

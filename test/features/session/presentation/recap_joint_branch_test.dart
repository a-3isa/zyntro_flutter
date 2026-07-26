// T8: Recap branches to the joint composer for two-human paired sessions,
// and keeps the existing solo share flow for solo/bot sessions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/session/presentation/recap_page.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/joint_post_composer.dart';
import 'package:zyntro_flutter/services/post_service.dart';
import 'package:zyntro_flutter/services/session_service.dart';
import 'package:zyntro_flutter/utils/offline_manager.dart';

class MockSessionService extends Mock implements SessionService {}

class MockPostService extends Mock implements PostService {}

const kSelfId = 'self-user';
const kPartnerId = 'partner-user';
const kSessionId = 'session-1';
const kDraftId = 'draft-post-1';

class _FakeCreatePostParams extends Fake implements CreatePostParams {}

Session _buildSession({
  required List<String> participants,
  PairedPartnerKind? partnerKind,
}) {
  return Session(
    id: kSessionId,
    type: 'strength',
    title: 'Evening Lift',
    hostId: kSelfId,
    participants: participants,
    status: SessionStatus.completed,
    phase: SessionPhase.live,
    partnerKind: partnerKind,
    summary: SessionSummary(totalSets: 6, totalExercises: 2),
    createdAt: DateTime(2026, 7, 26),
    startedAt: DateTime(2026, 7, 26, 10),
    endedAt: DateTime(2026, 7, 26, 11),
  );
}

dynamic _authOverride() {
  return authSessionProvider.overrideWithValue(
    const AsyncValue.data(
      AuthUserEntity(
        id: kSelfId,
        email: 'self@example.com',
        displayName: 'Sam Self',
        photoUrl: null,
        emailVerified: true,
        providerIds: ['password'],
      ),
    ),
  );
}

Widget _buildApp({
  required GoRouter router,
  required List<Object> overrides,
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp.router(routerConfig: router),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/recap',
    routes: [
      GoRoute(
        path: '/recap',
        builder: (context, state) => const RecapPage(sessionId: kSessionId),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Text('FEED:${state.uri.queryParameters['tab'] ?? ''}'),
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakeCreatePostParams());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  late MockSessionService sessionService;
  late MockPostService postService;

  setUp(() {
    sessionService = MockSessionService();
    postService = MockPostService();

    when(() => postService.watchJointDraft(any()))
        .thenAnswer((_) => const Stream.empty());
    when(
      () => postService.createPost(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((_) async => 'solo-post-id');
  });

  List<Object> overrides() => [
        _authOverride(),
        sessionServiceProvider.overrideWithValue(sessionService),
        postServiceProvider.overrideWithValue(postService),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
      ];

  testWidgets(
    'a two-human paired session renders JointPostComposer and never calls createPost',
    (tester) async {
      final session = _buildSession(
        participants: [kSelfId, kPartnerId],
        partnerKind: PairedPartnerKind.realFriend,
      );
      when(() => sessionService.getSession(kSessionId))
          .thenAnswer((_) async => session);
      when(
        () => postService.createJointDraft(
          sessionId: any(named: 'sessionId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          authorIds: any(named: 'authorIds'),
          summaries: any(named: 'summaries'),
        ),
      ).thenAnswer((_) async => kDraftId);

      await tester.pumpWidget(
        _buildApp(router: _buildRouter(), overrides: overrides()),
      );
      // Flush: getSession -> setState -> createJointDraft -> setState.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(JointPostComposer), findsOneWidget);
      expect(find.text('Post to feed'), findsNothing);

      verify(
        () => postService.createJointDraft(
          sessionId: kSessionId,
          type: 'strength',
          title: 'Evening Lift',
          authorIds: [kSelfId, kPartnerId],
          summaries: any(named: 'summaries'),
        ),
      ).called(1);
      verifyNever(
        () => postService.createPost(
          any(),
          onProgress: any(named: 'onProgress'),
        ),
      );
    },
  );

  testWidgets(
    'a failed joint draft creation shows a retry button that recovers',
    (tester) async {
      final session = _buildSession(
        participants: [kSelfId, kPartnerId],
        partnerKind: PairedPartnerKind.realFriend,
      );
      when(() => sessionService.getSession(kSessionId))
          .thenAnswer((_) async => session);

      var callCount = 0;
      when(
        () => postService.createJointDraft(
          sessionId: any(named: 'sessionId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          authorIds: any(named: 'authorIds'),
          summaries: any(named: 'summaries'),
        ),
      ).thenAnswer((_) async {
        callCount += 1;
        if (callCount == 1) {
          throw Exception('network error');
        }
        return kDraftId;
      });

      await tester.pumpWidget(
        _buildApp(router: _buildRouter(), overrides: overrides()),
      );
      // Flush: getSession -> setState -> createJointDraft (fails) -> setState.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(JointPostComposer), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      // Flush: retry clears error -> createJointDraft (succeeds) -> setState.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(JointPostComposer), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      verify(
        () => postService.createJointDraft(
          sessionId: any(named: 'sessionId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          authorIds: any(named: 'authorIds'),
          summaries: any(named: 'summaries'),
        ),
      ).called(2);
    },
  );

  testWidgets(
    'a bot-partner session renders the existing solo share UI',
    (tester) async {
      final session = _buildSession(
        participants: [kSelfId, pairedBotFriendId],
        partnerKind: PairedPartnerKind.bot,
      );
      when(() => sessionService.getSession(kSessionId))
          .thenAnswer((_) async => session);

      await tester.pumpWidget(
        _buildApp(router: _buildRouter(), overrides: overrides()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(JointPostComposer), findsNothing);
      expect(find.text('Post to feed'), findsOneWidget);
      expect(find.text('Share Workout'), findsOneWidget);

      verifyNever(
        () => postService.createJointDraft(
          sessionId: any(named: 'sessionId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          authorIds: any(named: 'authorIds'),
          summaries: any(named: 'summaries'),
        ),
      );
    },
  );

  testWidgets(
    'a single-human solo session renders the existing solo share UI',
    (tester) async {
      final session = _buildSession(participants: [kSelfId]);
      when(() => sessionService.getSession(kSessionId))
          .thenAnswer((_) async => session);

      await tester.pumpWidget(
        _buildApp(router: _buildRouter(), overrides: overrides()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(JointPostComposer), findsNothing);
      expect(find.text('Post to feed'), findsOneWidget);
      expect(find.text('Share Workout'), findsOneWidget);

      verifyNever(
        () => postService.createJointDraft(
          sessionId: any(named: 'sessionId'),
          type: any(named: 'type'),
          title: any(named: 'title'),
          authorIds: any(named: 'authorIds'),
          summaries: any(named: 'summaries'),
        ),
      );
    },
  );
}

// Task 14: an expired joint draft (status == 'expired') must offer the
// confirmed, non-removed author a "post solo instead" dialog (Public /
// Private / Discard) BEFORE the existing coAuthored branch (Task 10) would
// otherwise render it via the full joint PostCardWidget. A user who is not
// a confirmed author of the expired draft sees a plain unavailable state
// with no dialog.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:zyntro_flutter/features/feed/presentation/post_detail_page.dart';
import 'package:zyntro_flutter/services/post_service.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';
import 'package:zyntro_flutter/widgets/post_card_widget.dart';

class MockPostService extends Mock implements PostService {}

class MockAuthController extends Mock implements AuthController {}

class MockUserCacheService extends Mock implements UserCacheService {}

const kSelfId = 'self-user';
const kPartnerId = 'partner-user';
const kExpiredPostId = 'expired-joint-1';
const kRepostedPostId = 'reposted-solo-1';

Post _buildExpiredJointPost({required Map<String, PostAuthorSlot> authors}) {
  return Post(
    id: kExpiredPostId,
    authorId: kSelfId,
    authorIds: const [kSelfId, kPartnerId],
    status: 'expired',
    coAuthored: true,
    authors: authors,
    sessionId: 'session-1',
    visibility: 'public',
    title: 'Joint workout',
    type: 'strength',
    summary: SessionSummary(totalSets: 22, totalExercises: 7),
    likesCount: 0,
    commentsCount: 0,
    createdAt: DateTime.now(),
  );
}

Post _buildRepostedSoloPost() {
  return Post(
    id: kRepostedPostId,
    authorId: kSelfId,
    authorIds: const [kSelfId],
    status: 'published',
    coAuthored: false,
    sessionId: 'session-1',
    visibility: 'public',
    title: 'Solo repost of joint workout',
    type: 'strength',
    summary: SessionSummary(totalSets: 12, totalExercises: 4),
    likesCount: 0,
    commentsCount: 0,
    createdAt: DateTime.now(),
  );
}

class _TestApp {
  final MockPostService postService;
  final Widget widget;

  _TestApp({required this.postService, required this.widget});
}

_TestApp _buildApp({
  required Post initialPost,
  required String currentUid,
}) {
  final postService = MockPostService();
  final authController = MockAuthController();
  final userCacheService = MockUserCacheService();

  when(() => postService.getPost(initialPost.id)).thenAnswer(
    (_) async => initialPost,
  );
  when(() => postService.getReactionCounts(initialPost.id)).thenAnswer(
    (_) async => <ReactionType, int>{},
  );
  when(() => postService.getPost(kRepostedPostId)).thenAnswer(
    (_) async => _buildRepostedSoloPost(),
  );
  when(() => postService.getReactionCounts(kRepostedPostId)).thenAnswer(
    (_) async => <ReactionType, int>{},
  );
  when(() => postService.getUserReaction(any(), any())).thenAnswer(
    (_) async => null,
  );
  when(
    () => postService.repostSoloFromExpiredDraft(
      any(),
      any(),
      visibility: any(named: 'visibility'),
    ),
  ).thenAnswer((_) async => kRepostedPostId);
  when(() => authController.getUserProfile(any())).thenAnswer(
    (_) async => null,
  );
  when(() => userCacheService.fetchUsers(any())).thenAnswer(
    (_) async => <String, User>{},
  );

  final overrides = <Object>[
    authSessionProvider.overrideWith(
      (ref) => Stream.value(
        AuthUserEntity(
          id: currentUid,
          email: null,
          displayName: null,
          photoUrl: null,
          emailVerified: true,
          providerIds: const [],
        ),
      ),
    ),
    postServiceProvider.overrideWithValue(postService),
    authControllerProvider.overrideWithValue(authController),
    userCacheServiceProvider.overrideWithValue(userCacheService),
  ];

  final widget = ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(home: PostDetailPage(postId: initialPost.id)),
  );

  return _TestApp(postService: postService, widget: widget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'confirmed, non-removed author sees the solo-repost dialog on an '
    'expired draft',
    (tester) async {
      final post = _buildExpiredJointPost(
        authors: {
          kSelfId: PostAuthorSlot(
            userId: kSelfId,
            confirmed: true,
            summary: SessionSummary(totalSets: 12, totalExercises: 4),
          ),
          kPartnerId: PostAuthorSlot(
            userId: kPartnerId,
            confirmed: false,
            summary: SessionSummary(totalSets: 10, totalExercises: 3),
          ),
        },
      );
      final app = _buildApp(initialPost: post, currentUid: kSelfId);

      await tester.pumpWidget(app.widget);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      // The old (Task 10) full joint-card render must never appear for an
      // expired draft.
      expect(find.byType(PostCardWidget), findsNothing);
    },
  );

  testWidgets(
    'tapping Discard dismisses the dialog without reposting',
    (tester) async {
      final post = _buildExpiredJointPost(
        authors: {
          kSelfId: PostAuthorSlot(
            userId: kSelfId,
            confirmed: true,
            summary: SessionSummary(),
          ),
        },
      );
      final app = _buildApp(initialPost: post, currentUid: kSelfId);

      await tester.pumpWidget(app.widget);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(
        () => app.postService.repostSoloFromExpiredDraft(
          any(),
          any(),
          visibility: any(named: 'visibility'),
        ),
      );
    },
  );

  testWidgets(
    'tapping Public reposts solo with public visibility and navigates to '
    'the new post',
    (tester) async {
      final post = _buildExpiredJointPost(
        authors: {
          kSelfId: PostAuthorSlot(
            userId: kSelfId,
            confirmed: true,
            summary: SessionSummary(),
          ),
        },
      );
      final app = _buildApp(initialPost: post, currentUid: kSelfId);

      await tester.pumpWidget(app.widget);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();

      verify(
        () => app.postService.repostSoloFromExpiredDraft(
          kExpiredPostId,
          kSelfId,
          visibility: 'public',
        ),
      ).called(1);
      expect(find.text('Solo repost of joint workout'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Private reposts solo with private visibility and navigates '
    'to the new post',
    (tester) async {
      final post = _buildExpiredJointPost(
        authors: {
          kSelfId: PostAuthorSlot(
            userId: kSelfId,
            confirmed: true,
            summary: SessionSummary(),
          ),
        },
      );
      final app = _buildApp(initialPost: post, currentUid: kSelfId);

      await tester.pumpWidget(app.widget);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

      verify(
        () => app.postService.repostSoloFromExpiredDraft(
          kExpiredPostId,
          kSelfId,
          visibility: 'private',
        ),
      ).called(1);
      expect(find.text('Solo repost of joint workout'), findsOneWidget);
    },
  );

  testWidgets(
    'a user who never confirmed sees "no longer available" with no dialog',
    (tester) async {
      final post = _buildExpiredJointPost(
        authors: {
          kSelfId: PostAuthorSlot(
            userId: kSelfId,
            confirmed: false,
            summary: SessionSummary(),
          ),
          kPartnerId: PostAuthorSlot(
            userId: kPartnerId,
            confirmed: true,
            summary: SessionSummary(),
          ),
        },
      );
      final app = _buildApp(initialPost: post, currentUid: kSelfId);

      await tester.pumpWidget(app.widget);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('This post is no longer available'), findsOneWidget);
      verifyNever(
        () => app.postService.repostSoloFromExpiredDraft(
          any(),
          any(),
          visibility: any(named: 'visibility'),
        ),
      );
    },
  );

  testWidgets(
    'a stranger who opened a stale link (not in authors at all) sees no '
    'dialog',
    (tester) async {
      final post = _buildExpiredJointPost(
        authors: {
          kPartnerId: PostAuthorSlot(
            userId: kPartnerId,
            confirmed: true,
            summary: SessionSummary(),
          ),
        },
      );
      final app = _buildApp(initialPost: post, currentUid: 'stranger-user');

      await tester.pumpWidget(app.widget);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('This post is no longer available'), findsOneWidget);
    },
  );
}

// Fix 2 (final review I7): an unpublished joint draft must never render as a
// normal, reactable, commentable post at /post/:postId. A qualifying author is
// redirected to the dedicated composer route; everyone else gets an inert
// "not ready yet" state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zyntro_flutter/app/navigation/app_route_locations.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/features/auth/presentation/providers/auth_controller.dart';
import 'package:zyntro_flutter/features/feed/presentation/post_detail_page.dart';
import 'package:zyntro_flutter/features/session/presentation/joint_post_page.dart';
import 'package:zyntro_flutter/features/session/presentation/widgets/joint_post_composer.dart';
import 'package:zyntro_flutter/services/post_service.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';
import 'package:zyntro_flutter/widgets/post_card_widget.dart';
import 'package:zyntro_flutter/widgets/reaction_buttons.dart';

class MockPostService extends Mock implements PostService {}

class MockAuthController extends Mock implements AuthController {}

class MockUserCacheService extends Mock implements UserCacheService {}

const kSelfId = 'self-user';
const kPartnerId = 'partner-user';
const kStrangerId = 'stranger-user';
const kDraftId = 'joint_session-1';

User _buildUser({required String id, required String displayName}) {
  return User(
    id: id,
    displayName: displayName,
    isPrivate: false,
    workoutPreference: WorkoutType.gym,
    beginnerFlag: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Post _buildDraft({bool selfRemoved = false}) {
  return Post(
    id: kDraftId,
    authorId: kPartnerId,
    authorIds: const [kPartnerId, kSelfId],
    status: 'draft',
    coAuthored: true,
    authors: {
      kPartnerId: PostAuthorSlot(
        userId: kPartnerId,
        caption: 'Great session together!',
        confirmed: true,
        summary: SessionSummary(totalSets: 10, totalExercises: 3),
      ),
      kSelfId: PostAuthorSlot(
        userId: kSelfId,
        removed: selfRemoved,
        summary: SessionSummary(totalSets: 12, totalExercises: 4),
      ),
    },
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

Widget _buildApp({required Post post, required String currentUserId}) {
  final postService = MockPostService();
  final authController = MockAuthController();
  final userCacheService = MockUserCacheService();

  when(() => postService.getPost(post.id)).thenAnswer((_) async => post);
  when(() => postService.getReactionCounts(post.id))
      .thenAnswer((_) async => <ReactionType, int>{});
  when(() => postService.getUserReaction(any(), any()))
      .thenAnswer((_) async => null);
  when(() => postService.watchJointDraft(any()))
      .thenAnswer((_) => const Stream.empty());
  when(() => authController.getUserProfile(any())).thenAnswer((_) async => null);
  when(() => userCacheService.fetchUsers(any()))
      .thenAnswer((_) async => <String, User>{});
  when(() => userCacheService.getUserSync(any())).thenReturn(null);
  when(() => userCacheService.getUser(any()))
      .thenAnswer((_) async => _buildUser(id: kSelfId, displayName: 'Sam'));

  final router = GoRouter(
    initialLocation: '/post/${post.id}',
    routes: [
      GoRoute(
        path: '/post/:postId',
        builder: (context, state) =>
            PostDetailPage(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/joint-post/:postId',
        builder: (context, state) =>
            JointPostPage(postId: state.pathParameters['postId']!),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authSessionProvider.overrideWithValue(
        AsyncValue.data(
          AuthUserEntity(
            id: currentUserId,
            email: '$currentUserId@example.com',
            displayName: 'Current User',
            photoUrl: null,
            emailVerified: true,
            providerIds: const ['password'],
          ),
        ),
      ),
      postServiceProvider.overrideWithValue(postService),
      authControllerProvider.overrideWithValue(authController),
      userCacheServiceProvider.overrideWithValue(userCacheService),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('the invite deep link and the post deep link are different routes', () {
    expect(AppRouteLocations.jointPostComposer('p1'), '/joint-post/p1');
    expect(AppRouteLocations.postDetail('p1'), '/post/p1');
  });

  testWidgets(
    'a draft opened by a qualifying author redirects to the composer route',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(post: _buildDraft(), currentUserId: kSelfId),
      );
      // No pumpAndSettle: both the redirect placeholder and the composer's
      // loading state hold an indefinitely-animating progress indicator.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Landed on the standalone composer, not the post detail render.
      expect(find.byType(JointPostPage), findsOneWidget);
      expect(find.byType(JointPostComposer), findsOneWidget);
      expect(find.byType(PostDetailPage), findsNothing);
      expect(find.byType(PostCardWidget), findsNothing);
    },
  );

  testWidgets(
    'a draft opened by a non-author shows an inert not-ready state',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(post: _buildDraft(), currentUserId: kStrangerId),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text("This post isn't ready yet"), findsOneWidget);
      // No normal post render, no reactions, no comment box.
      expect(find.byType(PostCardWidget), findsNothing);
      expect(find.byType(ReactionButtons), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Joint workout'), findsNothing);
      expect(find.byType(JointPostPage), findsNothing);
    },
  );

  testWidgets(
    'an author who removed their slot is not redirected to the composer',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          post: _buildDraft(selfRemoved: true),
          currentUserId: kSelfId,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text("This post isn't ready yet"), findsOneWidget);
      expect(find.byType(JointPostPage), findsNothing);
      expect(find.byType(ReactionButtons), findsNothing);
    },
  );
}

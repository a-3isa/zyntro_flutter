// Task 10 fix round 1: proves post_detail_page.dart's hand-rolled post-card
// block delegates co-authored posts to PostCardWidget(displayMode: .full),
// while the existing solo hand-rolled rendering keeps working unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
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

Post _buildJointPost() {
  return Post(
    id: 'joint-post-1',
    authorId: kSelfId,
    authorIds: const [kSelfId, kPartnerId],
    status: 'published',
    coAuthored: true,
    authors: {
      kSelfId: PostAuthorSlot(
        userId: kSelfId,
        caption: 'Crushed it today!',
        confirmed: true,
        summary: SessionSummary(totalSets: 12, totalExercises: 4),
      ),
      kPartnerId: PostAuthorSlot(
        userId: kPartnerId,
        caption: 'Great session together!',
        confirmed: true,
        summary: SessionSummary(totalSets: 10, totalExercises: 3),
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

Post _buildSoloPost() {
  return Post(
    id: 'solo-post-1',
    authorId: kSelfId,
    authorIds: const [kSelfId],
    status: 'published',
    coAuthored: false,
    sessionId: 'session-2',
    visibility: 'public',
    title: 'Solo workout',
    type: 'strength',
    summary: SessionSummary(totalSets: 15, totalExercises: 5),
    likesCount: 0,
    commentsCount: 0,
    createdAt: DateTime.now(),
  );
}

Widget _buildApp(Post post) {
  final postService = MockPostService();
  final authController = MockAuthController();
  final userCacheService = MockUserCacheService();

  when(() => postService.getPost(post.id)).thenAnswer((_) async => post);
  when(() => postService.getReactionCounts(post.id)).thenAnswer(
    (_) async => <ReactionType, int>{},
  );
  when(() => postService.getUserReaction(any(), any())).thenAnswer(
    (_) async => null,
  );
  when(() => authController.getUserProfile(any())).thenAnswer(
    (_) async => null,
  );
  when(() => userCacheService.fetchUsers(any())).thenAnswer(
    (_) async => <String, User>{},
  );
  when(() => userCacheService.getUserSync(kSelfId)).thenReturn(
    _buildUser(id: kSelfId, displayName: 'Sam Self'),
  );
  when(() => userCacheService.getUserSync(kPartnerId)).thenReturn(
    _buildUser(id: kPartnerId, displayName: 'Priya Partner'),
  );

  return ProviderScope(
    overrides: [
      authSessionProvider.overrideWith((ref) => const Stream.empty()),
      postServiceProvider.overrideWithValue(postService),
      authControllerProvider.overrideWithValue(authController),
      userCacheServiceProvider.overrideWithValue(userCacheService),
    ],
    child: MaterialApp(home: PostDetailPage(postId: post.id)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'co-authored post detail delegates to PostCardWidget (full mode)',
    (tester) async {
      await tester.pumpWidget(_buildApp(_buildJointPost()));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(PostCardWidget), findsOneWidget);
      final postCardWidget = tester.widget<PostCardWidget>(
        find.byType(PostCardWidget),
      );
      expect(postCardWidget.displayMode, PostCardDisplayMode.full);
      expect(postCardWidget.post.id, 'joint-post-1');
    },
  );

  testWidgets(
    'solo post detail keeps rendering via the existing hand-rolled block',
    (tester) async {
      await tester.pumpWidget(_buildApp(_buildSoloPost()));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // The solo (non-co-authored) path must NOT be delegated to
      // PostCardWidget — it stays on the pre-existing hand-rolled block.
      expect(find.byType(PostCardWidget), findsNothing);
      expect(find.text('Solo workout'), findsOneWidget);
    },
  );
}

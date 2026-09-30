// Task 10 fix round 1: proves feed_page.dart's hand-rolled _buildPostCard
// delegates co-authored posts to PostCardWidget(displayMode: .full), while
// the existing solo hand-rolled rendering keeps working unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/feed/presentation/feed_page.dart';
import 'package:zyntro_flutter/services/feed_cache_service.dart';
import 'package:zyntro_flutter/services/post_service.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';
import 'package:zyntro_flutter/widgets/post_card_widget.dart';

class MockPostService extends Mock implements PostService {}

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

Future<Widget> _buildApp(List<Post> publicPosts) async {
  final postService = MockPostService();
  final userCacheService = MockUserCacheService();

  when(
    () => postService.getPublicPosts(
      limit: any(named: 'limit'),
      startAfterDoc: any(named: 'startAfterDoc'),
    ),
  ).thenAnswer(
    (_) async => FeedResult(
      posts: publicPosts,
      cursor: FeedCursor(hasMore: false),
    ),
  );
  when(() => postService.getReactionCounts(any())).thenAnswer(
    (_) async => <ReactionType, int>{},
  );
  when(() => postService.getUserReaction(any(), any())).thenAnswer(
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

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final feedCacheService = FeedCacheService(prefs);

  return ProviderScope(
    overrides: [
      authSessionProvider.overrideWith((ref) => const Stream.empty()),
      postServiceProvider.overrideWithValue(postService),
      userCacheServiceProvider.overrideWithValue(userCacheService),
      feedCacheServiceProvider.overrideWithValue(feedCacheService),
    ],
    child: const MaterialApp(home: FeedPage()),
  );
}

/// Switches from the default "Following" tab to "Discover" (public feed),
/// which doesn't require auth and is where our mocked posts are served from.
Future<void> _goToDiscoverTab(WidgetTester tester) async {
  await tester.tap(find.text('Discover'));
  await tester.pumpAndSettle();
  // Allow the async fetchPosts/reaction/user-cache chain to resolve.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FeedCursor(hasMore: false));
  });

  testWidgets(
    'co-authored post in the feed delegates to PostCardWidget (full mode)',
    (tester) async {
      await tester.pumpWidget(await _buildApp([_buildJointPost()]));
      await tester.pump();
      await tester.pump();
      await _goToDiscoverTab(tester);

      expect(find.byType(PostCardWidget), findsOneWidget);
      final postCardWidget = tester.widget<PostCardWidget>(
        find.byType(PostCardWidget),
      );
      expect(postCardWidget.displayMode, PostCardDisplayMode.full);
      expect(postCardWidget.post.id, 'joint-post-1');
    },
  );

  testWidgets(
    'solo post in the feed keeps rendering via the existing hand-rolled card',
    (tester) async {
      await tester.pumpWidget(await _buildApp([_buildSoloPost()]));
      await tester.pump();
      await tester.pump();
      await _goToDiscoverTab(tester);

      // The solo (non-co-authored) path must NOT be delegated to
      // PostCardWidget — it stays on the pre-existing hand-rolled card.
      expect(find.byType(PostCardWidget), findsNothing);
      expect(find.text('Solo workout'), findsOneWidget);
    },
  );
}

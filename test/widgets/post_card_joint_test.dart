import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/features/auth/auth_providers.dart';
import 'package:zyntro_flutter/features/auth/domain/entities/auth_user_entity.dart';
import 'package:zyntro_flutter/services/moderation_service.dart';
import 'package:zyntro_flutter/services/post_service.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';
import 'package:zyntro_flutter/widgets/fluttermoji_avatar.dart';
import 'package:zyntro_flutter/widgets/post_card_widget.dart';

class MockPostService extends Mock implements PostService {}

class MockModerationService extends Mock implements ModerationService {}

class MockUserCacheService extends Mock implements UserCacheService {}

const kSelfId = 'self-user';
const kPartnerId = 'partner-user';
const kRemovedId = 'removed-user';
const kStrangerId = 'stranger-user';
const kPostId = 'post-1';

User _buildUser({
  required String id,
  required String displayName,
  String? photoURL,
}) {
  return User(
    id: id,
    displayName: displayName,
    photoURL: photoURL,
    isPrivate: false,
    workoutPreference: WorkoutType.gym,
    beginnerFlag: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

Post _buildJointPost({
  PostAuthorSlot? selfSlot,
  PostAuthorSlot? partnerSlot,
  List<String>? authorIds,
  Map<String, PostAuthorSlot>? authorsOverride,
}) {
  return Post(
    id: kPostId,
    authorId: kSelfId,
    authorIds: authorIds ?? const [kSelfId, kPartnerId],
    status: 'published',
    coAuthored: true,
    authors: authorsOverride ??
        {
          kSelfId: selfSlot ??
              PostAuthorSlot(
                userId: kSelfId,
                caption: 'Crushed it today!',
                confirmed: true,
                summary: SessionSummary(totalSets: 12, totalExercises: 4),
              ),
          kPartnerId: partnerSlot ??
              PostAuthorSlot(
                userId: kPartnerId,
                caption: 'Great session together!',
                photoUrl: 'https://example.com/partner-photo.jpg',
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
    mediaURLs: const ['https://example.com/solo-photo.jpg'],
    likesCount: 0,
    commentsCount: 0,
    createdAt: DateTime.now(),
  );
}

dynamic _authOverride({String uid = kSelfId}) {
  return authSessionProvider.overrideWithValue(
    AsyncValue.data(
      AuthUserEntity(
        id: uid,
        email: '$uid@example.com',
        displayName: uid == kSelfId ? 'Sam Self' : 'Vic Viewer',
        photoUrl: null,
        emailVerified: true,
        providerIds: const ['password'],
      ),
    ),
  );
}

Widget _buildApp({
  required Post post,
  // Riverpod 3.x hides its `Override` type from the public API, so it can't
  // be named here; typed as Object and cast into ProviderScope (inference
  // supplies the hidden element type).
  required List<Object> overrides,
  PostCardDisplayMode displayMode = PostCardDisplayMode.full,
  String? slotUserId,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: PostCardWidget(
              post: post,
              displayMode: displayMode,
              slotUserId: slotUserId,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (context, state) => const Scaffold(body: Text('POST')),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (context, state) => const Scaffold(body: Text('USER')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late MockPostService postService;
  late MockModerationService moderationService;
  late MockUserCacheService userCacheService;

  setUp(() {
    postService = MockPostService();
    moderationService = MockModerationService();
    userCacheService = MockUserCacheService();

    when(() => postService.getReactionCounts(any()))
        .thenAnswer((_) async => <ReactionType, int>{});
    when(() => postService.getUserReaction(any(), any()))
        .thenAnswer((_) async => null);
    when(() => moderationService.blockUser(any(), any()))
        .thenAnswer((_) async {});
    when(
      () => postService.removeAuthorSlot(
        postId: any(named: 'postId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});

    when(() => userCacheService.getUserSync(kSelfId)).thenReturn(
      _buildUser(id: kSelfId, displayName: 'Sam Self'),
    );
    when(() => userCacheService.getUserSync(kPartnerId)).thenReturn(
      _buildUser(
        id: kPartnerId,
        displayName: 'Priya Partner',
        photoURL: 'https://example.com/partner-profile.jpg',
      ),
    );
    when(() => userCacheService.getUserSync(kRemovedId)).thenReturn(
      _buildUser(id: kRemovedId, displayName: 'Removed Rex'),
    );
    when(() => userCacheService.getUserSync(kStrangerId)).thenReturn(
      _buildUser(id: kStrangerId, displayName: 'Vic Viewer'),
    );
  });

  List<Object> overrides({String uid = kSelfId}) => [
        _authOverride(uid: uid),
        postServiceProvider.overrideWithValue(postService),
        moderationServiceProvider.overrideWithValue(moderationService),
        userCacheServiceProvider.overrideWithValue(userCacheService),
      ];

  testWidgets('co-authored post shows both names and both captions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(post: _buildJointPost(), overrides: overrides()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Sam Self with Priya Partner'), findsOneWidget);
    expect(
      find.textContaining('Crushed it today!', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Great session together!', findRichText: true),
      findsOneWidget,
    );
    // Both captions are attributed to their author.
    expect(
      find.textContaining('Sam Self: Crushed it today!', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Priya Partner: Great session together!',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'co-authored post shows two photo tiles: one image, one profile-pic fallback',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(post: _buildJointPost(), overrides: overrides()),
      );
      await tester.pump();
      await tester.pump();

      // Self has no authors[uid].photoUrl -> falls back to a
      // FluttermojiAvatar showing their profile picture (none set here, so
      // initials).
      final selfTile = find.byKey(
        const ValueKey('joint_post_card_photo_$kSelfId'),
      );
      expect(selfTile, findsOneWidget);
      expect(
        find.descendant(
          of: selfTile,
          matching: find.byType(FluttermojiAvatar),
        ),
        findsOneWidget,
      );

      // Partner has authors[uid].photoUrl set -> rendered as the network
      // image for that slot.
      final partnerTile = find.byKey(
        const ValueKey('joint_post_card_photo_$kPartnerId'),
      );
      expect(partnerTile, findsOneWidget);
      expect(
        find.descendant(
          of: partnerTile,
          matching: find.byWidgetPredicate(
            (w) =>
                w.runtimeType.toString() == 'CachedNetworkImage' &&
                (w as dynamic).imageUrl ==
                    'https://example.com/partner-photo.jpg',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a removed author is omitted from rendering', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        post: _buildJointPost(
          authorIds: const [kSelfId, kPartnerId, kRemovedId],
          authorsOverride: {
            kSelfId: PostAuthorSlot(
              userId: kSelfId,
              caption: 'Crushed it today!',
              confirmed: true,
              summary: SessionSummary(totalSets: 12, totalExercises: 4),
            ),
            kPartnerId: PostAuthorSlot(
              userId: kPartnerId,
              caption: 'Great session together!',
              photoUrl: 'https://example.com/partner-photo.jpg',
              confirmed: true,
              summary: SessionSummary(totalSets: 10, totalExercises: 3),
            ),
            kRemovedId: PostAuthorSlot(
              userId: kRemovedId,
              caption: 'Should never show up',
              removed: true,
              summary: SessionSummary(),
            ),
          },
        ),
        overrides: overrides(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Sam Self with Priya Partner'), findsOneWidget);
    expect(find.textContaining('Removed Rex'), findsNothing);
    expect(find.textContaining('Should never show up'), findsNothing);
    expect(
      find.byKey(const ValueKey('joint_post_card_photo_$kRemovedId')),
      findsNothing,
    );
  });

  testWidgets(
    'expandable Session activity shows both authors summaries once expanded',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(post: _buildJointPost(), overrides: overrides()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Session activity'), findsOneWidget);

      await tester.tap(find.text('Session activity'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('joint_post_card_activity_$kSelfId')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('joint_post_card_activity_$kPartnerId')),
        findsOneWidget,
      );
      expect(find.textContaining('4 exercises'), findsOneWidget);
      expect(find.textContaining('3 exercises'), findsOneWidget);
    },
  );

  testWidgets('solo (non-co-authored) post renders unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(post: _buildSoloPost(), overrides: overrides()),
    );
    await tester.pump();
    await tester.pump();

    // Existing single-author path: single author name, single image, no
    // joint-only widgets present.
    expect(find.text('Sam Self'), findsOneWidget);
    expect(find.byKey(const ValueKey('joint_post_card')), findsNothing);
    expect(
      find.byKey(const ValueKey('joint_post_card_activity')),
      findsNothing,
    );
    expect(find.text('Session activity'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.runtimeType.toString() == 'CachedNetworkImage' &&
            (w as dynamic).imageUrl == 'https://example.com/solo-photo.jpg',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'co-authored own post overflow shows "Remove from my profile" and '
    'calls removeAuthorSlot for the caller only',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(post: _buildJointPost(), overrides: overrides()),
      );
      await tester.pump();
      await tester.pump();

      final overflow = find.byIcon(Icons.more_vert);
      expect(overflow, findsOneWidget);

      await tester.tap(overflow);
      await tester.pumpAndSettle();

      expect(find.text('Remove from my profile'), findsOneWidget);
      // Scoped to a single action - no report/block parity with the solo
      // menu, and no generic "Delete" wording on a joint post.
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Report Post'), findsNothing);
      expect(find.text('Block User'), findsNothing);

      await tester.tap(find.text('Remove from my profile'));
      await tester.pumpAndSettle();

      // Confirmation dialog guards the destructive action.
      expect(
        find.text(
          'This post will no longer appear on your profile or feed. '
          'It stays visible to your co-author until they remove it too.',
        ),
        findsOneWidget,
      );
      verifyNever(
        () => postService.removeAuthorSlot(
          postId: any(named: 'postId'),
          userId: any(named: 'userId'),
        ),
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      verify(
        () =>
            postService.removeAuthorSlot(postId: kPostId, userId: kSelfId),
      ).called(1);
    },
  );

  testWidgets(
    'co-authored post overflow removal is cancellable without calling '
    'removeAuthorSlot',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(post: _buildJointPost(), overrides: overrides()),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from my profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => postService.removeAuthorSlot(
          postId: any(named: 'postId'),
          userId: any(named: 'userId'),
        ),
      );
    },
  );

  testWidgets(
    'solo (own) post has no co-author "Remove from my profile" option - '
    'pre-existing solo overflow behavior is untouched by this feature',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(post: _buildSoloPost(), overrides: overrides()),
      );
      await tester.pump();
      await tester.pump();

      // NOTE: at the time this test was written, the codebase has no
      // existing full-delete affordance for solo posts anywhere (no menu
      // item, no PostService method) - only report/user-block actions for
      // posts that are NOT the viewer's own. This task's scope (per Task 3's
      // removeAuthorSlot as the only consumed interface) is limited to
      // adding co-authored "Remove from my profile"; it intentionally does
      // not invent a new solo-delete capability.
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.text('Remove from my profile'), findsNothing);
    },
  );

  // ---------------------------------------------------------------------
  // Moderation reachability on co-authored posts (non-author viewer).
  // ---------------------------------------------------------------------

  testWidgets(
    'a non-author viewing a co-authored post still gets an overflow menu '
    'with report/block for each co-author',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          post: _buildJointPost(),
          overrides: overrides(uid: kStrangerId),
        ),
      );
      await tester.pump();
      await tester.pump();

      final overflow = find.byKey(const ValueKey('joint_post_card_menu'));
      expect(overflow, findsOneWidget);

      await tester.tap(overflow);
      await tester.pumpAndSettle();

      // A stranger is not an author, so no soft-leave action is offered.
      expect(find.text('Remove from my profile'), findsNothing);
      expect(find.text('Report Post'), findsOneWidget);
      // Both co-authors are individually reportable / blockable.
      expect(find.text('Report Sam Self'), findsOneWidget);
      expect(find.text('Report Priya Partner'), findsOneWidget);
      expect(find.text('Block Sam Self'), findsOneWidget);
      expect(find.text('Block Priya Partner'), findsOneWidget);
    },
  );

  testWidgets(
    'blocking a co-author from the joint menu blocks that specific author',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          post: _buildJointPost(),
          overrides: overrides(uid: kStrangerId),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('joint_post_card_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Priya Partner'));
      await tester.pumpAndSettle();

      // Same confirmation dialog the solo card uses.
      expect(
        find.textContaining('Are you sure you want to block Priya Partner?'),
        findsOneWidget,
      );
      verifyNever(() => moderationService.blockUser(any(), any()));

      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();

      // The blocked user is the co-author the viewer picked, NOT the post's
      // legacy `authorId` (which is always authorIds.first on a joint post).
      verify(() => moderationService.blockUser(kStrangerId, kPartnerId))
          .called(1);
    },
  );

  testWidgets('a removed co-author is not offered as a report/block target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        post: _buildJointPost(
          authorIds: const [kSelfId, kPartnerId, kRemovedId],
          authorsOverride: {
            kSelfId: PostAuthorSlot(
              userId: kSelfId,
              confirmed: true,
              summary: SessionSummary(),
            ),
            kPartnerId: PostAuthorSlot(
              userId: kPartnerId,
              confirmed: true,
              summary: SessionSummary(),
            ),
            kRemovedId: PostAuthorSlot(
              userId: kRemovedId,
              removed: true,
              summary: SessionSummary(),
            ),
          },
        ),
        overrides: overrides(uid: kStrangerId),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('joint_post_card_menu')));
    await tester.pumpAndSettle();

    expect(find.text('Block Removed Rex'), findsNothing);
    expect(find.text('Report Removed Rex'), findsNothing);
  });

  // ---------------------------------------------------------------------
  // Compact (profile grid) rendering of co-authored posts.
  // ---------------------------------------------------------------------

  testWidgets(
    'compact co-authored tile renders the requested author slot photo and a '
    'co-author badge',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          post: _buildJointPost(),
          overrides: overrides(uid: kStrangerId),
          displayMode: PostCardDisplayMode.compact,
          slotUserId: kPartnerId,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('joint_post_compact_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('joint_post_compact_badge')),
        findsOneWidget,
      );
      // The photo comes from authors.<uid>.photoUrl, never from the (empty)
      // top-level mediaURLs the solo compact tile reads.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.runtimeType.toString() == 'CachedNetworkImage' &&
              (w as dynamic).imageUrl ==
                  'https://example.com/partner-photo.jpg',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'compact co-authored tile falls back to the author profile picture when '
    'their slot has no photo',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          post: _buildJointPost(),
          overrides: overrides(),
          displayMode: PostCardDisplayMode.compact,
          // kSelfId's slot has no photoUrl in the default fixture.
          slotUserId: kSelfId,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('joint_post_compact_card')),
        findsOneWidget,
      );
      expect(find.byType(FluttermojiAvatar), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'CachedNetworkImage',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('compact solo tile is untouched by the co-author branch', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        post: _buildSoloPost(),
        overrides: overrides(),
        displayMode: PostCardDisplayMode.compact,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('joint_post_compact_card')),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.runtimeType.toString() == 'CachedNetworkImage' &&
            (w as dynamic).imageUrl == 'https://example.com/solo-photo.jpg',
      ),
      findsOneWidget,
    );
  });
}

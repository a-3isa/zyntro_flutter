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
import 'package:zyntro_flutter/features/session/presentation/widgets/joint_post_composer.dart';
import 'package:zyntro_flutter/services/media_service.dart';
import 'package:zyntro_flutter/services/notification_service.dart';
import 'package:zyntro_flutter/services/post_service.dart';
import 'package:zyntro_flutter/services/user_cache_service.dart';
import 'package:zyntro_flutter/widgets/fluttermoji_avatar.dart';

class MockPostService extends Mock implements PostService {}

class MockMediaService extends Mock implements MediaService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockUserCacheService extends Mock implements UserCacheService {}

const kSelfId = 'self-user';
const kPartnerId = 'partner-user';
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

Post _buildDraftPost({
  String status = 'draft',
  PostAuthorSlot? selfSlot,
  PostAuthorSlot? partnerSlot,
}) {
  return Post(
    id: kPostId,
    authorId: kSelfId,
    authorIds: const [kSelfId, kPartnerId],
    status: status,
    coAuthored: true,
    authors: {
      kSelfId: selfSlot ??
          PostAuthorSlot(userId: kSelfId, summary: SessionSummary()),
      kPartnerId: partnerSlot ??
          PostAuthorSlot(userId: kPartnerId, summary: SessionSummary()),
    },
    sessionId: 'session-1',
    visibility: 'public',
    title: 'Joint session',
    type: 'strength',
    summary: SessionSummary(),
    likesCount: 0,
    commentsCount: 0,
    createdAt: DateTime(2026),
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
  // Riverpod 3.x hides its `Override` type from the public API, so it can't be
  // named here; typed as Object and cast into ProviderScope (inference supplies
  // the hidden element type).
  required List<Object> overrides,
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp.router(routerConfig: router),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/joint-post',
    routes: [
      GoRoute(
        path: '/joint-post',
        builder: (context, state) => const JointPostComposer(postId: kPostId),
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  late MockPostService postService;
  late MockMediaService mediaService;
  late MockNotificationService notificationService;
  late MockUserCacheService userCacheService;
  late StreamController<Post> draftController;

  setUp(() {
    postService = MockPostService();
    mediaService = MockMediaService();
    notificationService = MockNotificationService();
    userCacheService = MockUserCacheService();
    draftController = StreamController<Post>.broadcast();

    when(() => postService.watchJointDraft(kPostId))
        .thenAnswer((_) => draftController.stream);
    when(
      () => postService.setAuthorSlot(
        postId: any(named: 'postId'),
        userId: any(named: 'userId'),
        caption: any(named: 'caption'),
        photoUrl: any(named: 'photoUrl'),
        visibility: any(named: 'visibility'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => postService.confirmJointPost(
        postId: any(named: 'postId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notificationService.sendJointPostInvite(
        recipientId: any(named: 'recipientId'),
        fromName: any(named: 'fromName'),
        postId: any(named: 'postId'),
        sessionId: any(named: 'sessionId'),
      ),
    ).thenAnswer((_) async {});

    when(() => userCacheService.getUserSync(kSelfId))
        .thenReturn(_buildUser(id: kSelfId, displayName: 'Sam Self'));
    when(() => userCacheService.getUser(kSelfId)).thenAnswer(
      (_) async => _buildUser(id: kSelfId, displayName: 'Sam Self'),
    );
    when(() => userCacheService.getUserSync(kPartnerId)).thenReturn(
      _buildUser(
        id: kPartnerId,
        displayName: 'Priya Partner',
        photoURL: 'https://example.com/partner.jpg',
      ),
    );
    when(() => userCacheService.getUser(kPartnerId)).thenAnswer(
      (_) async => _buildUser(
        id: kPartnerId,
        displayName: 'Priya Partner',
        photoURL: 'https://example.com/partner.jpg',
      ),
    );
  });

  tearDown(() async {
    await draftController.close();
  });

  List<Object> overrides() => [
        _authOverride(),
        postServiceProvider.overrideWithValue(postService),
        mediaServiceProvider.overrideWithValue(mediaService),
        notificationServiceProvider.overrideWithValue(notificationService),
        userCacheServiceProvider.overrideWithValue(userCacheService),
      ];

  testWidgets('renders both slots side by side', (tester) async {
    await tester.pumpWidget(
      _buildApp(router: _buildRouter(), overrides: overrides()),
    );
    draftController.add(_buildDraftPost());
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('joint_post_self_slot')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('joint_post_partner_slot')),
      findsOneWidget,
    );
    expect(find.text('You'), findsOneWidget);
    expect(find.text('You with Priya'), findsOneWidget);
  });

  testWidgets(
    'tapping Post with a caption calls setAuthorSlot then confirmJointPost',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: _buildRouter(), overrides: overrides()),
      );
      draftController.add(_buildDraftPost());
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('joint_post_caption_field')),
        'Great session together!',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('joint_post_post_button')));
      await tester.pump();
      await tester.pump();

      verifyInOrder([
        () => postService.setAuthorSlot(
              postId: kPostId,
              userId: kSelfId,
              caption: 'Great session together!',
              photoUrl: null,
              visibility: 'public',
            ),
        () => postService.confirmJointPost(postId: kPostId, userId: kSelfId),
      ]);
      verifyNever(
        () => mediaService.uploadPostPhoto(
          filePath: any(named: 'filePath'),
          postId: any(named: 'postId'),
        ),
      );
    },
  );

  testWidgets(
    'sends the joint-post invite when the partner has not confirmed yet',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: _buildRouter(), overrides: overrides()),
      );
      // Partner slot defaults to unconfirmed.
      draftController.add(_buildDraftPost());
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('joint_post_caption_field')),
        'Great session together!',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('joint_post_post_button')));
      await tester.pump();
      await tester.pump();

      verify(
        () => notificationService.sendJointPostInvite(
          recipientId: kPartnerId,
          fromName: any(named: 'fromName'),
          postId: kPostId,
          sessionId: 'session-1',
        ),
      ).called(1);
    },
  );

  testWidgets(
    'does not send the joint-post invite when the partner already confirmed',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: _buildRouter(), overrides: overrides()),
      );
      draftController.add(
        _buildDraftPost(
          partnerSlot: PostAuthorSlot(
            userId: kPartnerId,
            confirmed: true,
            summary: SessionSummary(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('joint_post_caption_field')),
        'Great session together!',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('joint_post_post_button')));
      await tester.pump();
      await tester.pump();

      verify(
        () => postService.confirmJointPost(postId: kPostId, userId: kSelfId),
      ).called(1);
      verifyNever(
        () => notificationService.sendJointPostInvite(
          recipientId: any(named: 'recipientId'),
          fromName: any(named: 'fromName'),
          postId: any(named: 'postId'),
          sessionId: any(named: 'sessionId'),
        ),
      );
    },
  );

  testWidgets('partner slot with null photo shows a profile-pic fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: _buildRouter(), overrides: overrides()),
    );
    draftController.add(_buildDraftPost());
    await tester.pump();
    await tester.pump();

    final fallbackAvatar = find.descendant(
      of: find.byKey(const ValueKey('joint_post_partner_slot')),
      matching: find.byWidgetPredicate(
        (w) =>
            w is CircleAvatar &&
            w.backgroundImage is NetworkImage &&
            (w.backgroundImage as NetworkImage).url ==
                'https://example.com/partner.jpg',
      ),
    );
    expect(fallbackAvatar, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('joint_post_partner_slot')),
        matching: find.byType(FluttermojiAvatar),
      ),
      findsOneWidget,
    );
    expect(find.text('waiting…'), findsOneWidget);
  });

  testWidgets(
    "status=='published' shows Posted together and routes to the feed",
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: _buildRouter(), overrides: overrides()),
      );
      draftController.add(_buildDraftPost());
      await tester.pump();
      await tester.pump();

      draftController.add(
        _buildDraftPost(
          status: 'published',
          selfSlot: PostAuthorSlot(
            userId: kSelfId,
            confirmed: true,
            summary: SessionSummary(),
          ),
          partnerSlot: PostAuthorSlot(
            userId: kPartnerId,
            confirmed: true,
            summary: SessionSummary(),
          ),
        ),
      );
      await tester.pump(); // deliver the published stream event
      await tester.pump(); // run the post-frame route + snackbar
      await tester.pumpAndSettle(); // settle the nav transition + snackbar entry

      expect(find.text('FEED:feed'), findsOneWidget);
      expect(find.text('Posted together'), findsOneWidget);
    },
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/post_service.dart';

final _testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PostService postService;
  late Ref testRef;
  late ProviderContainer container;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    container = ProviderContainer(overrides: [_testRefProvider]);
    testRef = container.read(_testRefProvider);
    postService = PostService(fakeFirestore, testRef);
  });

  tearDown(() {
    container.dispose();
  });

  group('createJointDraft', () {
    test(
      'creates one draft with both author slots seeded, then both confirm',
      () async {
        final postId = await postService.createJointDraft(
          sessionId: 'session-1',
          type: 'strength',
          title: 'Leg day',
          authorIds: ['ahmed', 'mohamed'],
          summaries: {
            'ahmed': SessionSummary(totalSets: 10),
            'mohamed': SessionSummary(totalSets: 12),
          },
        );

        final doc = await fakeFirestore.collection('posts').doc(postId).get();
        final data = doc.data()!;
        expect(data['coAuthored'], true);
        expect(data['status'], 'draft');
        expect(
          (data['authorIds'] as List).cast<String>(),
          ['ahmed', 'mohamed'],
        );

        await postService.confirmJointPost(postId: postId, userId: 'ahmed');
        await postService.confirmJointPost(postId: postId, userId: 'mohamed');

        final updatedDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .get();
        final post = Post.fromFirestore(updatedDoc);

        expect(post.authors['ahmed']?.confirmed, true);
        expect(post.authors['mohamed']?.confirmed, true);
        // Publish transition is the Cloud Function's job (Task 6) — not the
        // client's. confirmJointPost must never flip status itself.
        expect(post.status, 'draft');
      },
    );

    test('is idempotent per session', () async {
      final firstId = await postService.createJointDraft(
        sessionId: 'session-2',
        type: 'cardio',
        title: 'Morning run',
        authorIds: ['ahmed', 'mohamed'],
        summaries: {},
      );

      final secondId = await postService.createJointDraft(
        sessionId: 'session-2',
        type: 'cardio',
        title: 'Morning run',
        authorIds: ['ahmed', 'mohamed'],
        summaries: {},
      );

      expect(secondId, firstId);

      final snapshot = await fakeFirestore
          .collection('posts')
          .where('sessionId', isEqualTo: 'session-2')
          .get();
      expect(snapshot.docs.length, 1);
    });

    test('uses a deterministic per-session document id', () async {
      final postId = await postService.createJointDraft(
        sessionId: 'session-det',
        type: 'strength',
        title: 'Leg day',
        authorIds: ['ahmed', 'mohamed'],
        summaries: {},
      );

      expect(postId, PostService.jointDraftIdForSession('session-det'));
      expect(postId, 'joint_session-det');
    });

    test(
      'two clients creating the draft at the same time converge on ONE doc',
      () async {
        // Both partners land on recap the instant the paired session ends, so
        // each client calls createJointDraft with no chance to observe the
        // other's write first. The deterministic id + transaction must make
        // this collapse to a single document.
        final clientA = PostService(fakeFirestore, testRef);
        final clientB = PostService(fakeFirestore, testRef);

        final ids = await Future.wait([
          clientA.createJointDraft(
            sessionId: 'session-race',
            type: 'strength',
            title: 'Leg day',
            authorIds: ['ahmed', 'mohamed'],
            summaries: {'ahmed': SessionSummary(totalSets: 10)},
          ),
          clientB.createJointDraft(
            sessionId: 'session-race',
            type: 'strength',
            title: 'Leg day',
            authorIds: ['ahmed', 'mohamed'],
            summaries: {'mohamed': SessionSummary(totalSets: 12)},
          ),
        ]);

        expect(ids.first, ids.last);

        final snapshot = await fakeFirestore
            .collection('posts')
            .where('sessionId', isEqualTo: 'session-race')
            .get();
        expect(
          snapshot.docs.length,
          1,
          reason: 'a second draft can never collect both confirmations',
        );

        // Both partners confirm on the SAME doc — the publish precondition.
        await clientA.confirmJointPost(postId: ids.first, userId: 'ahmed');
        await clientB.confirmJointPost(postId: ids.last, userId: 'mohamed');

        final post = Post.fromFirestore(
          await fakeFirestore.collection('posts').doc(ids.first).get(),
        );
        expect(post.authors['ahmed']?.confirmed, true);
        expect(post.authors['mohamed']?.confirmed, true);
      },
    );

    test('does not resurrect an already-published joint post', () async {
      final postId = await postService.createJointDraft(
        sessionId: 'session-pub',
        type: 'strength',
        title: 'Leg day',
        authorIds: ['ahmed', 'mohamed'],
        summaries: {},
      );
      // The dual-confirm Cloud Function published it.
      await fakeFirestore.collection('posts').doc(postId).update({
        'status': 'published',
      });

      await expectLater(
        postService.createJointDraft(
          sessionId: 'session-pub',
          type: 'strength',
          title: 'Leg day',
          authorIds: ['ahmed', 'mohamed'],
          summaries: {},
        ),
        throwsA(
          isA<JointDraftUnavailableException>()
              .having((e) => e.status, 'status', 'published')
              .having((e) => e.postId, 'postId', postId),
        ),
      );

      // The published post is left completely untouched.
      final doc = await fakeFirestore.collection('posts').doc(postId).get();
      expect(doc.data()!['status'], 'published');
    });

    test('does not resurrect an already-expired joint draft', () async {
      final postId = await postService.createJointDraft(
        sessionId: 'session-exp',
        type: 'cardio',
        title: 'Morning run',
        authorIds: ['ahmed', 'mohamed'],
        summaries: {},
      );
      await fakeFirestore.collection('posts').doc(postId).update({
        'status': 'expired',
      });

      await expectLater(
        postService.createJointDraft(
          sessionId: 'session-exp',
          type: 'cardio',
          title: 'Morning run',
          authorIds: ['ahmed', 'mohamed'],
          summaries: {},
        ),
        throwsA(
          isA<JointDraftUnavailableException>().having(
            (e) => e.status,
            'status',
            'expired',
          ),
        ),
      );

      final doc = await fakeFirestore.collection('posts').doc(postId).get();
      expect(doc.data()!['status'], 'expired');
    });
  });

  test('setAuthorSlot updates only the caller\'s own slot fields', () async {
    final postId = await postService.createJointDraft(
      sessionId: 'session-3',
      type: 'strength',
      title: 'Push day',
      authorIds: ['ahmed', 'mohamed'],
      summaries: {},
    );

    await postService.setAuthorSlot(
      postId: postId,
      userId: 'ahmed',
      caption: 'Great session!',
      visibility: 'private',
    );

    final doc = await fakeFirestore.collection('posts').doc(postId).get();
    final post = Post.fromFirestore(doc);

    expect(post.authors['ahmed']?.caption, 'Great session!');
    expect(post.authors['ahmed']?.visibility, 'private');
    // mohamed's slot must be untouched.
    expect(post.authors['mohamed']?.caption, null);
    expect(post.authors['mohamed']?.visibility, 'public');
  });

  test('removeAuthorSlot marks only that author as removed', () async {
    final postId = await postService.createJointDraft(
      sessionId: 'session-4',
      type: 'strength',
      title: 'Pull day',
      authorIds: ['ahmed', 'mohamed'],
      summaries: {},
    );

    await postService.removeAuthorSlot(postId: postId, userId: 'mohamed');

    final doc = await fakeFirestore.collection('posts').doc(postId).get();
    final post = Post.fromFirestore(doc);

    expect(post.authors['mohamed']?.removed, true);
    expect(post.authors['ahmed']?.removed, false);
  });

  test('watchJointDraft streams updates to the post document', () async {
    final postId = await postService.createJointDraft(
      sessionId: 'session-5',
      type: 'strength',
      title: 'Leg day',
      authorIds: ['ahmed', 'mohamed'],
      summaries: {},
    );

    // fake_cloud_firestore's transaction stub applies writes without awaiting
    // them (real runTransaction only resolves after the commit is acked), so
    // sync on a read before subscribing.
    final seeded = await fakeFirestore.collection('posts').doc(postId).get();
    expect(seeded.exists, true);

    final stream = postService.watchJointDraft(postId);
    final firstEvent = stream.first;

    await postService.confirmJointPost(postId: postId, userId: 'ahmed');

    final post = await firstEvent;
    expect(post.id, postId);
  });

  group('getUserPosts / watchUserPosts author-scoped queries', () {
    test('excludes drafts and removed slots', () async {
      // Published co-authored post with 'ahmed' removed.
      await fakeFirestore.collection('posts').add({
        'authorId': 'mohamed',
        'authorIds': ['ahmed', 'mohamed'],
        'status': 'published',
        'coAuthored': true,
        'authors': {
          'ahmed': PostAuthorSlot(
            userId: 'ahmed',
            removed: true,
            summary: SessionSummary(),
          ).toMap(),
          'mohamed': PostAuthorSlot(
            userId: 'mohamed',
            summary: SessionSummary(),
          ).toMap(),
        },
        'sessionId': 'session-6',
        'visibility': 'public',
        'title': 'Joint post',
        'type': 'strength',
        'summary': SessionSummary().toMap(),
        'mediaURLs': <String>[],
        'likesCount': 0,
        'commentsCount': 0,
        'createdAt': Timestamp.now(),
      });

      final ahmedPosts = await postService.getUserPosts('ahmed');
      expect(ahmedPosts, isEmpty);

      final mohamedPosts = await postService.getUserPosts('mohamed');
      expect(mohamedPosts, hasLength(1));

      final ahmedStream = await postService.watchUserPosts('ahmed').first;
      expect(ahmedStream, isEmpty);

      final mohamedStream = await postService.watchUserPosts('mohamed').first;
      expect(mohamedStream, hasLength(1));
    });

    test('excludes drafts even when the user is an active author', () async {
      await postService.createJointDraft(
        sessionId: 'session-7',
        type: 'strength',
        title: 'Draft only',
        authorIds: ['ahmed', 'mohamed'],
        summaries: {},
      );

      final ahmedPosts = await postService.getUserPosts('ahmed');
      expect(ahmedPosts, isEmpty);
    });
  });

  group('getFollowingPosts / getBuddiesRecentPosts joint-post visibility', () {
    /// Seeds a co-authored post doc. [removed] lists authors whose slot is
    /// soft-removed.
    Future<String> seedJointPost({
      required String sessionId,
      required String status,
      List<String> authorIds = const ['ahmed', 'mohamed'],
      String visibility = 'public',
      List<String> removed = const [],
    }) async {
      final ref = await fakeFirestore.collection('posts').add({
        // Legacy singular field intentionally points at authorIds.first only —
        // the whole point of the fix is that queries must not rely on it.
        'authorId': authorIds.first,
        'authorIds': authorIds,
        'status': status,
        'coAuthored': true,
        'authors': {
          for (final uid in authorIds)
            uid: PostAuthorSlot(
              userId: uid,
              removed: removed.contains(uid),
              summary: SessionSummary(),
            ).toMap(),
        },
        'sessionId': sessionId,
        'visibility': visibility,
        // Stamped server-side by stampPostAuthorPrivacy in production.
        'authorIsPrivate': false,
        'title': 'Joint $status',
        'type': 'strength',
        'summary': SessionSummary().toMap(),
        'mediaURLs': <String>[],
        'likesCount': 0,
        'commentsCount': 0,
        'createdAt': Timestamp.now(),
      });
      return ref.id;
    }

    test('getFollowingPosts excludes unconfirmed joint drafts', () async {
      await seedJointPost(sessionId: 'session-f1', status: 'draft');

      final result = await postService.getFollowingPosts(
        currentUserId: 'viewer',
        followingIds: ['ahmed', 'mohamed'],
      );

      expect(result.posts, isEmpty);
    });

    test('getFollowingPosts excludes expired joint drafts', () async {
      await seedJointPost(sessionId: 'session-f2', status: 'expired');

      final result = await postService.getFollowingPosts(
        currentUserId: 'viewer',
        followingIds: ['ahmed', 'mohamed'],
      );

      expect(result.posts, isEmpty);
    });

    test(
      'a published joint post reaches followers of BOTH authors, not just '
      'authorIds.first',
      () async {
        final postId = await seedJointPost(
          sessionId: 'session-f3',
          status: 'published',
        );

        // Follower of the SECOND co-author only.
        final secondAuthorFollower = await postService.getFollowingPosts(
          currentUserId: 'viewer',
          followingIds: ['mohamed'],
        );
        expect(secondAuthorFollower.posts.map((p) => p.id), [postId]);

        // Follower of the first co-author still sees it too.
        final firstAuthorFollower = await postService.getFollowingPosts(
          currentUserId: 'viewer2',
          followingIds: ['ahmed'],
        );
        expect(firstAuthorFollower.posts.map((p) => p.id), [postId]);
      },
    );

    test(
      'getFollowingPosts drops a joint post whose only followed author '
      'removed their slot, but keeps it for the other author',
      () async {
        final postId = await seedJointPost(
          sessionId: 'session-f4',
          status: 'published',
          removed: ['mohamed'],
        );

        final followsRemovedAuthor = await postService.getFollowingPosts(
          currentUserId: 'viewer',
          followingIds: ['mohamed'],
        );
        expect(followsRemovedAuthor.posts, isEmpty);

        final followsActiveAuthor = await postService.getFollowingPosts(
          currentUserId: 'viewer2',
          followingIds: ['ahmed'],
        );
        expect(followsActiveAuthor.posts.map((p) => p.id), [postId]);
      },
    );

    test(
      'getFollowingPosts hides a joint post the viewer removed themselves '
      'from, even when they still follow the other author',
      () async {
        await seedJointPost(
          sessionId: 'session-f5',
          status: 'published',
          authorIds: ['ahmed', 'viewer'],
          removed: ['viewer'],
        );

        final result = await postService.getFollowingPosts(
          currentUserId: 'viewer',
          followingIds: ['ahmed'],
        );

        expect(result.posts, isEmpty);
      },
    );

    test('getFollowingPosts still returns solo published posts', () async {
      final soloId = await postService.createPost(
        CreatePostParams(
          authorId: 'ahmed',
          sessionId: 'session-f6',
          visibility: 'public',
          title: 'Solo session',
          type: 'strength',
          summary: SessionSummary(),
        ),
      );

      final result = await postService.getFollowingPosts(
        currentUserId: 'viewer',
        followingIds: ['ahmed'],
      );

      expect(result.posts.map((p) => p.id), [soloId]);
    });

    test('getBuddiesRecentPosts excludes unconfirmed joint drafts', () async {
      await seedJointPost(sessionId: 'session-b1', status: 'draft');

      final posts = await postService.getBuddiesRecentPosts([
        'ahmed',
        'mohamed',
      ]);

      expect(posts, isEmpty);
    });

    test(
      'getBuddiesRecentPosts surfaces a published joint post for the second '
      'co-author and drops it once that author removes their slot',
      () async {
        final postId = await seedJointPost(
          sessionId: 'session-b2',
          status: 'published',
        );

        final viaSecondAuthor = await postService.getBuddiesRecentPosts([
          'mohamed',
        ]);
        expect(viaSecondAuthor.map((p) => p.id), [postId]);

        await postService.removeAuthorSlot(
          postId: postId,
          userId: 'mohamed',
        );

        final afterRemoval = await postService.getBuddiesRecentPosts([
          'mohamed',
        ]);
        expect(afterRemoval, isEmpty);

        final viaOtherAuthor = await postService.getBuddiesRecentPosts([
          'ahmed',
        ]);
        expect(viaOtherAuthor.map((p) => p.id), [postId]);
      },
    );
  });

  group('repostSoloFromExpiredDraft', () {
    test(
      "writes a correctly-shaped solo post from the confirmed author's slot "
      'and leaves the draft untouched',
      () async {
        final postId = await postService.createJointDraft(
          sessionId: 'session-9',
          type: 'strength',
          title: 'Leg day',
          authorIds: ['ahmed', 'mohamed'],
          summaries: {
            'ahmed': SessionSummary(totalSets: 8, totalExercises: 3),
          },
        );

        // ahmed confirmed and had already uploaded a photo before mohamed
        // let the draft expire.
        await postService.setAuthorSlot(
          postId: postId,
          userId: 'ahmed',
          caption: 'Solid leg day',
          photoUrl: 'https://storage.example.com/ahmed-leg-day.jpg',
        );
        await postService.confirmJointPost(postId: postId, userId: 'ahmed');
        await fakeFirestore.collection('posts').doc(postId).update({
          'status': 'expired',
        });

        final newPostId = await postService.repostSoloFromExpiredDraft(
          postId,
          'ahmed',
          visibility: 'private',
        );

        expect(newPostId, isNot(postId));

        final newDoc = await fakeFirestore
            .collection('posts')
            .doc(newPostId)
            .get();
        final newData = newDoc.data()!;
        expect(newData['authorId'], 'ahmed');
        expect((newData['authorIds'] as List).cast<String>(), ['ahmed']);
        expect(newData['status'], 'published');
        expect(newData['coAuthored'], false);
        expect(newData['visibility'], 'private');
        // The author's own composer caption wins over the session title —
        // reposting solo must not silently discard the text they typed.
        expect(newData['title'], 'Solid leg day');
        expect(newData['type'], 'strength');
        expect(
          (newData['mediaURLs'] as List).cast<String>(),
          ['https://storage.example.com/ahmed-leg-day.jpg'],
        );

        final newPost = Post.fromFirestore(newDoc);
        expect(newPost.summary.totalSets, 8);
        expect(newPost.summary.totalExercises, 3);

        // The original expired draft document is left exactly as-is.
        final draftDoc = await fakeFirestore
            .collection('posts')
            .doc(postId)
            .get();
        expect(draftDoc.data()!['status'], 'expired');
        expect(draftDoc.data()!['coAuthored'], true);
        expect(draftDoc.data()!['authors'], isNotNull);
      },
    );

    test(
      'does not attempt a photo upload — falls back to no media when the '
      "slot has no photoUrl",
      () async {
        final postId = await postService.createJointDraft(
          sessionId: 'session-10',
          type: 'cardio',
          title: 'Morning run',
          authorIds: ['ahmed', 'mohamed'],
          summaries: {},
        );
        await postService.confirmJointPost(postId: postId, userId: 'mohamed');
        await fakeFirestore.collection('posts').doc(postId).update({
          'status': 'expired',
        });

        // No mediaServiceProvider override exists in this test's container —
        // if the implementation tried to run the upload pipeline, reading
        // that provider would throw. Succeeding here proves it didn't.
        final newPostId = await postService.repostSoloFromExpiredDraft(
          postId,
          'mohamed',
          visibility: 'public',
        );

        final newDoc = await fakeFirestore
            .collection('posts')
            .doc(newPostId)
            .get();
        expect((newDoc.data()!['mediaURLs'] as List), isEmpty);
        expect(newDoc.data()!['visibility'], 'public');
        // No caption on the slot -> the session title is the fallback.
        expect(newDoc.data()!['title'], 'Morning run');
      },
    );

    test(
      'a blank/whitespace-only caption falls back to the session title',
      () async {
        final postId = await postService.createJointDraft(
          sessionId: 'session-11',
          type: 'strength',
          title: 'Pull day',
          authorIds: ['ahmed', 'mohamed'],
          summaries: {},
        );
        await postService.setAuthorSlot(
          postId: postId,
          userId: 'ahmed',
          caption: '   ',
        );
        await postService.confirmJointPost(postId: postId, userId: 'ahmed');
        await fakeFirestore.collection('posts').doc(postId).update({
          'status': 'expired',
        });

        final newPostId = await postService.repostSoloFromExpiredDraft(
          postId,
          'ahmed',
          visibility: 'public',
        );

        final newDoc = await fakeFirestore
            .collection('posts')
            .doc(newPostId)
            .get();
        expect(newDoc.data()!['title'], 'Pull day');
      },
    );

    test('a padded caption is trimmed before it becomes the title', () async {
      final postId = await postService.createJointDraft(
        sessionId: 'session-12',
        type: 'strength',
        title: 'Pull day',
        authorIds: ['ahmed', 'mohamed'],
        summaries: {},
      );
      await postService.setAuthorSlot(
        postId: postId,
        userId: 'ahmed',
        caption: '  New PR on rows  ',
      );
      await postService.confirmJointPost(postId: postId, userId: 'ahmed');
      await fakeFirestore.collection('posts').doc(postId).update({
        'status': 'expired',
      });

      final newPostId = await postService.repostSoloFromExpiredDraft(
        postId,
        'ahmed',
        visibility: 'public',
      );

      final newDoc = await fakeFirestore
          .collection('posts')
          .doc(newPostId)
          .get();
      expect(newDoc.data()!['title'], 'New PR on rows');
    });
  });

  test(
    'solo createPost still writes authorIds/status/coAuthored and is discoverable via getUserPosts',
    () async {
      final postId = await postService.createPost(
        CreatePostParams(
          authorId: 'ahmed',
          sessionId: 'session-8',
          visibility: 'public',
          title: 'Solo session',
          type: 'strength',
          summary: SessionSummary(),
        ),
      );

      final doc = await fakeFirestore.collection('posts').doc(postId).get();
      final data = doc.data()!;
      expect((data['authorIds'] as List).cast<String>(), ['ahmed']);
      expect(data['status'], 'published');
      expect(data['coAuthored'], false);

      final posts = await postService.getUserPosts('ahmed');
      expect(posts.map((p) => p.id), contains(postId));
    },
  );
}

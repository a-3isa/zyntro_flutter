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

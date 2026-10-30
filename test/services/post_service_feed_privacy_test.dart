import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/post_service.dart';

final _testRefProvider = Provider<Ref>((ref) => ref);

/// Post list queries must match what the Firestore `list` rule can prove:
/// multi-author queries only see isListablePublicPost docs
/// (published + public + authorIsPrivate == false); anything else is reached
/// one author at a time via `authorId ==`.
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PostService postService;
  late ProviderContainer container;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    container = ProviderContainer(overrides: [_testRefProvider]);
    postService = PostService(fakeFirestore, container.read(_testRefProvider));
  });

  tearDown(() => container.dispose());

  var clock = 0;
  Future<String> seedPost(
    String authorId, {
    String visibility = 'public',
    bool? authorIsPrivate = false,
  }) async {
    final ref = await fakeFirestore.collection('posts').add({
      'authorId': authorId,
      'authorIds': [authorId],
      'status': 'published',
      'coAuthored': false,
      'visibility': visibility,
      'authorIsPrivate': ?authorIsPrivate,
      'title': 't',
      'type': 'strength',
      'summary': SessionSummary().toMap(),
      'mediaURLs': <String>[],
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000 + clock++),
    });
    return ref.id;
  }

  test(
    'Discover lists only stamped public posts from public accounts',
    () async {
      final listable = await seedPost('a');
      await seedPost('a', visibility: 'friends');
      await seedPost('p', authorIsPrivate: true);
      await seedPost('legacy', authorIsPrivate: null);

      final result = await postService.getPublicPosts();

      expect(result.posts.map((p) => p.id), [listable]);
    },
  );

  test('Following includes friends posts and private-account posts from '
      'followed authors, but never private-visibility posts', () async {
    final friends = await seedPost('a', visibility: 'friends');
    final privateAccount = await seedPost('p', authorIsPrivate: true);
    await seedPost('a', visibility: 'private');
    await seedPost('stranger');

    final result = await postService.getFollowingPosts(
      currentUserId: 'viewer',
      followingIds: ['a', 'p'],
    );

    expect(result.posts.map((p) => p.id).toSet(), {friends, privateAccount});
  });

  test('a non-follower sees only listable public posts on a profile', () async {
    final public = await seedPost('a');
    final friends = await seedPost('a', visibility: 'friends');

    final stranger = await postService
        .watchUserPosts('a', isOwner: false)
        .first;
    expect(stranger.map((p) => p.id), [public]);

    final follower = await postService
        .watchUserPosts('a', isOwner: false, viewerFollows: true)
        .first;
    expect(follower.map((p) => p.id).toSet(), {public, friends});
  });
}

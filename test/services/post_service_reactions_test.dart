import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/post_service.dart';

final _testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  late FakeFirebaseFirestore firestore;
  late PostService postService;
  late ProviderContainer container;
  const postId = 'post-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(overrides: [_testRefProvider]);
    postService = PostService(firestore, container.read(_testRefProvider));
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> seedPost({
    Map<String, dynamic>? reactionCounts,
    int likesCount = 0,
  }) {
    return firestore.collection('posts').doc(postId).set({
      'authorId': 'author',
      'likesCount': likesCount,
      'reactionCounts': ?reactionCounts,
    });
  }

  Future<void> seedReactionDoc(String userId, ReactionType type) {
    return firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId)
        .set({'type': type.value});
  }

  Future<Map<String, dynamic>> readPost() async {
    final doc = await firestore.collection('posts').doc(postId).get();
    return doc.data()!;
  }

  group('getReactionCounts — maintained map', () {
    test('serves tallies straight off the post document', () async {
      await seedPost(
        reactionCounts: {'fire': 2, 'strong': 1, 'clap': 3},
        likesCount: 6,
      );
      // No reaction documents exist at all: passing proves the map was used.
      expect(await postService.getReactionCounts(postId), {
        ReactionType.fire: 2,
        ReactionType.strong: 1,
        ReactionType.clap: 3,
      });
    });

    test('omits types nobody used rather than reporting them as zero', () async {
      await seedPost(reactionCounts: {'fire': 1, 'clap': 0}, likesCount: 1);

      final counts = await postService.getReactionCounts(postId);

      expect(counts, {ReactionType.fire: 1});
      expect(counts.containsKey(ReactionType.clap), isFalse);
    });

    test('ignores a malformed tally instead of throwing', () async {
      await seedPost(
        reactionCounts: {'fire': 'lots', 'clap': null, 'strong': 2},
        likesCount: 2,
      );

      expect(await postService.getReactionCounts(postId), {
        ReactionType.strong: 2,
      });
    });

    test('returns empty for a post nobody has reacted to', () async {
      await seedPost(likesCount: 0);
      expect(await postService.getReactionCounts(postId), isEmpty);
    });
  });

  group('getReactionCounts — pre-migration fallback', () {
    test('counts reaction documents when the map is absent', () async {
      // likesCount > 0 with no reactionCounts is what a post written before
      // the map existed looks like.
      await seedPost(likesCount: 3);
      await seedReactionDoc('u1', ReactionType.fire);
      await seedReactionDoc('u2', ReactionType.fire);
      await seedReactionDoc('u3', ReactionType.clap);

      expect(await postService.getReactionCounts(postId), {
        ReactionType.fire: 2,
        ReactionType.clap: 1,
      });
    });

    test('counts only the requested post', () async {
      await seedPost(likesCount: 1);
      await seedReactionDoc('u1', ReactionType.fire);
      await firestore
          .collection('posts')
          .doc('other-post')
          .collection('reactions')
          .doc('u2')
          .set({'type': ReactionType.fire.value});

      expect(await postService.getReactionCounts(postId), {
        ReactionType.fire: 1,
      });
    });
  });

  group('reactToPost maintains the tallies', () {
    test('a first reaction increments both its type and the total', () async {
      await seedPost();

      await postService.reactToPost(postId, 'u1', type: ReactionType.fire);

      final post = await readPost();
      expect(post['likesCount'], 1);
      expect(post['reactionCounts']['fire'], 1);
    });

    test('two users reacting the same way both count', () async {
      await seedPost();

      await postService.reactToPost(postId, 'u1', type: ReactionType.clap);
      await postService.reactToPost(postId, 'u2', type: ReactionType.clap);

      final post = await readPost();
      expect(post['likesCount'], 2);
      expect(post['reactionCounts']['clap'], 2);
    });

    test('reacting twice the same way does not double count', () async {
      await seedPost();

      await postService.reactToPost(postId, 'u1', type: ReactionType.fire);
      await postService.reactToPost(postId, 'u1', type: ReactionType.fire);

      final post = await readPost();
      expect(post['likesCount'], 1);
      expect(post['reactionCounts']['fire'], 1);
    });

    test('changing type moves one across and leaves the total alone', () async {
      await seedPost();
      await postService.reactToPost(postId, 'u1', type: ReactionType.fire);

      await postService.reactToPost(postId, 'u1', type: ReactionType.strong);

      final post = await readPost();
      expect(post['likesCount'], 1, reason: 'still one person reacting');
      expect(post['reactionCounts']['fire'], 0);
      expect(post['reactionCounts']['strong'], 1);
    });
  });

  group('removeReaction maintains the tallies', () {
    test('decrements the type that was actually stored', () async {
      await seedPost();
      await postService.reactToPost(postId, 'u1', type: ReactionType.clap);

      await postService.removeReaction(postId, 'u1');

      final post = await readPost();
      expect(post['likesCount'], 0);
      expect(post['reactionCounts']['clap'], 0);
    });

    test('leaves other users\' reactions intact', () async {
      await seedPost();
      await postService.reactToPost(postId, 'u1', type: ReactionType.fire);
      await postService.reactToPost(postId, 'u2', type: ReactionType.fire);

      await postService.removeReaction(postId, 'u1');

      final post = await readPost();
      expect(post['likesCount'], 1);
      expect(post['reactionCounts']['fire'], 1);
    });

    test('a repeated unreact cannot drive the counts negative', () async {
      await seedPost();
      await postService.reactToPost(postId, 'u1', type: ReactionType.fire);

      await postService.removeReaction(postId, 'u1');
      await postService.removeReaction(postId, 'u1');

      final post = await readPost();
      expect(post['likesCount'], 0);
      expect(post['reactionCounts']['fire'], 0);
    });

    test('unreacting without ever having reacted is a no-op', () async {
      await seedPost(reactionCounts: {'fire': 5}, likesCount: 5);

      await postService.removeReaction(postId, 'never-reacted');

      final post = await readPost();
      expect(post['likesCount'], 5);
      expect(post['reactionCounts']['fire'], 5);
    });

    test('react, change, remove leaves every tally back at zero', () async {
      await seedPost();

      await postService.reactToPost(postId, 'u1', type: ReactionType.fire);
      await postService.reactToPost(postId, 'u1', type: ReactionType.clap);
      await postService.removeReaction(postId, 'u1');

      final post = await readPost();
      expect(post['likesCount'], 0);
      expect(post['reactionCounts']['fire'], 0);
      expect(post['reactionCounts']['clap'], 0);
      expect(await postService.getReactionCounts(postId), isEmpty);
    });
  });
}

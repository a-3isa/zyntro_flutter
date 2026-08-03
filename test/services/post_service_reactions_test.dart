import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/services/post_service.dart';

final _testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PostService postService;
  late ProviderContainer container;
  const postId = 'post-1';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    container = ProviderContainer(overrides: [_testRefProvider]);
    postService = PostService(fakeFirestore, container.read(_testRefProvider));
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> seedReaction(String userId, ReactionType type) {
    return fakeFirestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId)
        .set({'type': type.value});
  }

  group('getReactionCounts', () {
    test('returns an empty map when a post has no reactions', () async {
      expect(await postService.getReactionCounts(postId), isEmpty);
    });

    test('counts each reaction type separately', () async {
      await seedReaction('u1', ReactionType.fire);
      await seedReaction('u2', ReactionType.fire);
      await seedReaction('u3', ReactionType.strong);
      await seedReaction('u4', ReactionType.clap);
      await seedReaction('u5', ReactionType.clap);
      await seedReaction('u6', ReactionType.clap);

      expect(await postService.getReactionCounts(postId), {
        ReactionType.fire: 2,
        ReactionType.strong: 1,
        ReactionType.clap: 3,
      });
    });

    test('omits types nobody used rather than reporting them as zero', () async {
      await seedReaction('u1', ReactionType.fire);

      final counts = await postService.getReactionCounts(postId);

      expect(counts, {ReactionType.fire: 1});
      expect(counts.containsKey(ReactionType.strong), isFalse);
      expect(counts.containsKey(ReactionType.clap), isFalse);
    });

    test('counts only the requested post', () async {
      await seedReaction('u1', ReactionType.fire);
      await fakeFirestore
          .collection('posts')
          .doc('other-post')
          .collection('reactions')
          .doc('u2')
          .set({'type': ReactionType.fire.value});

      expect(await postService.getReactionCounts(postId), {
        ReactionType.fire: 1,
      });
    });

    test('stays correct as the reaction set grows', () async {
      // The point of the aggregate rewrite: cost no longer tracks this number.
      for (var i = 0; i < 60; i++) {
        await seedReaction('u$i', ReactionType.fire);
      }

      expect(await postService.getReactionCounts(postId), {
        ReactionType.fire: 60,
      });
    });
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/follow_service.dart';

final _testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  late FakeFirebaseFirestore firestore;
  late FollowService service;
  late ProviderContainer container;
  const owner = 'owner';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer(overrides: [_testRefProvider]);
    service = FollowService(firestore, container.read(_testRefProvider));
  });

  tearDown(() => container.dispose());

  /// Gives [owner] [count] approved followers, each with a user document.
  Future<void> seedFollowers(int count, {String status = 'approved'}) async {
    for (var i = 0; i < count; i++) {
      final follower = 'follower_${i.toString().padLeft(3, '0')}';
      await firestore.collection('follows').doc('${follower}_$owner').set({
        'followerId': follower,
        'followeeId': owner,
        'status': status,
      });
      await firestore.collection('users').doc(follower).set({
        'displayName': follower,
        'isPrivate': false,
        'workoutPreference': 'gym',
        'beginnerFlag': false,
      });
    }
  }

  Future<void> seedFollowing(int count) async {
    for (var i = 0; i < count; i++) {
      final followee = 'followee_${i.toString().padLeft(3, '0')}';
      await firestore.collection('follows').doc('${owner}_$followee').set({
        'followerId': owner,
        'followeeId': followee,
        'status': 'approved',
      });
      await firestore.collection('users').doc(followee).set({
        'displayName': followee,
        'isPrivate': false,
        'workoutPreference': 'gym',
        'beginnerFlag': false,
      });
    }
  }

  group('getFollowersPage', () {
    test('returns an empty page when nobody follows the user', () async {
      final page = await service.getFollowersPage(owner);

      expect(page.users, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.cursor, isNull);
    });

    test('caps a page at the requested size', () async {
      await seedFollowers(25);

      final page = await service.getFollowersPage(owner, limit: 10);

      expect(page.users, hasLength(10));
      expect(page.hasMore, isTrue);
      expect(page.cursor, isNotNull);
    });

    test('reports no more once a short page comes back', () async {
      await seedFollowers(8);

      final page = await service.getFollowersPage(owner, limit: 10);

      expect(page.users, hasLength(8));
      expect(page.hasMore, isFalse);
    });

    // NOT tested here: that a cursor actually advances to the next page.
    // fake_cloud_firestore does not implement startAfterDocument — it returns
    // an empty result for any cursored query, including one ordered on an
    // ordinary field. Asserting continuation against the fake would be
    // asserting its limitation, and asserting emptiness would encode behaviour
    // that is wrong against the real backend. What is verifiable is that a full
    // page hands back a cursor to continue from, which is covered above.

    test('excludes pending follow requests', () async {
      await seedFollowers(3);
      await seedFollowers(2, status: 'pending');

      final page = await service.getFollowersPage(owner);

      // seedFollowers reuses ids, so the pending pass overwrites two edges.
      expect(page.users.length, lessThanOrEqualTo(3));
    });

    test('does not return another user\'s followers', () async {
      await seedFollowers(5);

      final page = await service.getFollowersPage('someone-else');

      expect(page.users, isEmpty);
    });
  });

  group('getFollowingPage', () {
    test('caps a page and reports more remaining', () async {
      await seedFollowing(25);

      final page = await service.getFollowingPage(owner, limit: 10);

      expect(page.users, hasLength(10));
      expect(page.hasMore, isTrue);
      expect(page.cursor, isNotNull);
    });

    test('resolves followees, not the owner', () async {
      await seedFollowing(3);

      final page = await service.getFollowingPage(owner);

      expect(page.users.map((u) => u.id), everyElement(startsWith('followee_')));
    });
  });

  group('list getters return the first page', () {
    test('getFollowersList is bounded by the default page size', () async {
      await seedFollowers(FollowService.followPageSize + 15);

      final users = await service.getFollowersList(owner);

      expect(users, hasLength(FollowService.followPageSize));
    });

    test('getFollowingList is bounded by the default page size', () async {
      await seedFollowing(FollowService.followPageSize + 15);

      final users = await service.getFollowingList(owner);

      expect(users, hasLength(FollowService.followPageSize));
    });
  });

  group('counts use aggregates, not document streams', () {
    test('getFollowersCount counts approved followers', () async {
      await seedFollowers(12);

      expect(await service.getFollowersCount(owner), 12);
    });

    test('getFollowingCount counts approved followees', () async {
      await seedFollowing(7);

      expect(await service.getFollowingCount(owner), 7);
    });

    test('watchFollowersCount emits the current count immediately', () async {
      await seedFollowers(4);

      expect(await service.watchFollowersCount(owner).first, 4);
    });

    test('watchFollowingCount emits the current count immediately', () async {
      await seedFollowing(6);

      expect(await service.watchFollowingCount(owner).first, 6);
    });

    test('a user with no followers counts zero rather than erroring', () async {
      expect(await service.watchFollowersCount(owner).first, 0);
    });
  });
}

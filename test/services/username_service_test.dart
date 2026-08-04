import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/username_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UsernameService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = UsernameService(firestore);
  });

  Future<void> claimFor(String uid, String handle) {
    return firestore.collection('usernames').doc(handle).set({'uid': uid});
  }

  group('normalize', () {
    test('trims and lowercases', () {
      expect(service.normalize('  AhmedIsa  '), 'ahmedisa');
    });
  });

  group('validationError', () {
    test('accepts a plain handle', () {
      expect(service.validationError('ahmed'), isNull);
    });

    test('accepts digits and underscores', () {
      expect(service.validationError('ahmed_92'), isNull);
    });

    test('accepts the boundary lengths', () {
      expect(service.validationError('abc'), isNull);
      expect(service.validationError('a' * 20), isNull);
    });

    test('rejects an empty handle', () {
      expect(service.validationError('   '), 'Username is required.');
    });

    test('rejects one character below the minimum', () {
      expect(service.validationError('ab'), contains('at least 3'));
    });

    test('rejects one character above the maximum', () {
      expect(service.validationError('a' * 21), contains('at most 20'));
    });

    test('rejects spaces inside the handle', () {
      expect(service.validationError('ahmed isa'), contains('lowercase'));
    });

    test('rejects punctuation and symbols', () {
      for (final bad in ['ahmed!', 'ahmed-isa', 'ahmed.isa', 'ahmed@x']) {
        expect(service.validationError(bad), isNotNull, reason: bad);
      }
    });

    test('accepts uppercase input because it is normalized first', () {
      expect(service.validationError('AHMED'), isNull);
    });

    test('rejects a non-ASCII handle', () {
      expect(service.validationError('أحمد'), isNotNull);
    });
  });

  group('isAvailable', () {
    test('is true for an unclaimed handle', () async {
      expect(await service.isAvailable('ahmed'), isTrue);
    });

    test('is false for a handle someone else holds', () async {
      await claimFor('other-user', 'ahmed');
      expect(await service.isAvailable('ahmed', currentUserId: 'me'), isFalse);
    });

    test('is true for the handle the caller already owns', () async {
      await claimFor('me', 'ahmed');
      expect(await service.isAvailable('ahmed', currentUserId: 'me'), isTrue);
    });

    test('is false for an invalid handle without hitting Firestore', () async {
      expect(await service.isAvailable('a'), isFalse);
    });

    test('matches case-insensitively against the stored handle', () async {
      await claimFor('other-user', 'ahmed');
      expect(await service.isAvailable('AHMED', currentUserId: 'me'), isFalse);
    });
  });

  group('claim', () {
    test('claims a free handle and stamps the user document', () async {
      final result = await service.claim(userId: 'me', raw: 'Ahmed');

      expect(result, UsernameClaimResult.success);

      final registry = await firestore.collection('usernames').doc('ahmed').get();
      expect(registry.data()?['uid'], 'me');

      final user = await firestore.collection('users').doc('me').get();
      expect(user.data()?['username'], 'ahmed');
      expect(user.data()?['usernameLower'], 'ahmed');
    });

    test('refuses a handle another user already holds', () async {
      await claimFor('other-user', 'ahmed');

      expect(
        await service.claim(userId: 'me', raw: 'ahmed'),
        UsernameClaimResult.taken,
      );
    });

    test('does not overwrite the registry when the handle is taken', () async {
      await claimFor('other-user', 'ahmed');

      await service.claim(userId: 'me', raw: 'ahmed');

      final registry = await firestore.collection('usernames').doc('ahmed').get();
      expect(registry.data()?['uid'], 'other-user');
    });

    test('re-claiming your own handle succeeds', () async {
      await claimFor('me', 'ahmed');

      expect(
        await service.claim(userId: 'me', raw: 'ahmed'),
        UsernameClaimResult.success,
      );
    });

    test('rejects an invalid handle before touching Firestore', () async {
      expect(
        await service.claim(userId: 'me', raw: 'no spaces allowed'),
        UsernameClaimResult.invalid,
      );

      final docs = await firestore.collection('usernames').get();
      expect(docs.docs, isEmpty);
    });

    test('writes the handle onto an existing user document', () async {
      // NOT asserted here: that the pre-existing fields survive. claim() passes
      // SetOptions(merge: true), which real Firestore honours, but
      // fake_cloud_firestore ignores merge inside a transaction (it honours it
      // outside one). Asserting the surviving fields would be testing the
      // fake's limitation, and asserting they are gone would encode behaviour
      // that is wrong against the real backend.
      await firestore.collection('users').doc('me').set({
        'displayName': 'Ahmed',
      });

      await service.claim(userId: 'me', raw: 'ahmed');

      final user = await firestore.collection('users').doc('me').get();
      expect(user.data()?['username'], 'ahmed');
      expect(user.data()?['usernameLower'], 'ahmed');
    });

    test('normalizes before storing so the registry key is canonical', () async {
      await service.claim(userId: 'me', raw: '  AhMeD_92  ');

      final registry =
          await firestore.collection('usernames').doc('ahmed_92').get();
      expect(registry.exists, isTrue);
      expect(registry.data()?['uid'], 'me');
    });
  });
}

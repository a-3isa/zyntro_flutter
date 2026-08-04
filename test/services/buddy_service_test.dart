import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/services/buddy_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late BuddyService service;
  const creator = 'alice';
  const acceptor = 'bob';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = BuddyService(firestore);
  });

  Future<Map<String, dynamic>> readPair(String pairId) async {
    final doc = await firestore.collection('buddyPairs').doc(pairId).get();
    return doc.data()!;
  }

  Future<Map<String, dynamic>> readCode(String code) async {
    final doc = await firestore.collection('inviteCodes').doc(code).get();
    return doc.data()!;
  }

  group('generateUniqueInviteCode', () {
    test('produces an eight-character uppercase alphanumeric code', () async {
      final code = await service.generateUniqueInviteCode();

      expect(code, matches(RegExp(r'^[A-Z0-9]{8}$')));
    });

    test('produces different codes across calls', () async {
      final codes = <String>{};
      for (var i = 0; i < 20; i++) {
        codes.add(await service.generateUniqueInviteCode());
      }
      // A collision in 20 draws from 36^8 would mean the generator is broken.
      expect(codes.length, 20);
    });
  });

  group('createBuddyInvite', () {
    test('opens a pending pair holding only the creator', () async {
      final invite = await service.createBuddyInvite(creator);

      final pair = await readPair(invite.pairId);
      expect(pair['participants'], [creator]);
      expect(pair['initiatorId'], creator);
      expect(pair['status'], 'pending');
      expect(pair['inviteCode'], invite.inviteCode);
    });

    test('registers the code against the pair with an expiry', () async {
      final invite = await service.createBuddyInvite(creator);

      final code = await readCode(invite.inviteCode);
      expect(code['creatorId'], creator);
      expect(code['buddyPairId'], invite.pairId);
      expect(code['expiresAt'], isA<Timestamp>());
      expect(code['usedAt'], isNull);
    });

    test('dates the expiry roughly a week out', () async {
      final invite = await service.createBuddyInvite(creator);

      final expiresAt = (await readCode(invite.inviteCode))['expiresAt'] as Timestamp;
      final days = expiresAt.toDate().difference(DateTime.now()).inDays;
      expect(days, inInclusiveRange(6, 7));
    });
  });

  group('acceptBuddyInvite', () {
    test('activates the pair and adds the acceptor', () async {
      final invite = await service.createBuddyInvite(creator);

      final pair = await service.acceptBuddyInvite(invite.inviteCode, acceptor);

      expect(pair.status, BuddyPairStatus.active);
      expect(pair.participants, containsAll([creator, acceptor]));
      expect(pair.initiatorId, creator);

      final stored = await readPair(invite.pairId);
      expect(stored['status'], 'active');
      expect((stored['participants'] as List).cast<String>(),
          containsAll([creator, acceptor]));
    });

    test('marks the code used by the acceptor', () async {
      final invite = await service.createBuddyInvite(creator);

      await service.acceptBuddyInvite(invite.inviteCode, acceptor);

      final code = await readCode(invite.inviteCode);
      expect(code['usedAt'], isNotNull);
      expect(code['usedBy'], acceptor);
    });

    test('rejects an unknown code', () async {
      expect(
        () => service.acceptBuddyInvite('NOTACODE', acceptor),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects the creator accepting their own invite', () async {
      final invite = await service.createBuddyInvite(creator);

      await expectLater(
        service.acceptBuddyInvite(invite.inviteCode, creator),
        throwsA(isA<Exception>()),
      );

      // The pair must stay pending rather than half-activating.
      expect((await readPair(invite.pairId))['status'], 'pending');
    });

    test('rejects a code that has already been used', () async {
      final invite = await service.createBuddyInvite(creator);
      await service.acceptBuddyInvite(invite.inviteCode, acceptor);

      await expectLater(
        service.acceptBuddyInvite(invite.inviteCode, 'carol'),
        throwsA(isA<Exception>()),
      );

      // carol must not have been added to somebody else's pair.
      final stored = await readPair(invite.pairId);
      expect((stored['participants'] as List).contains('carol'), isFalse);
    });

    test('rejects an expired code', () async {
      final invite = await service.createBuddyInvite(creator);
      await firestore.collection('inviteCodes').doc(invite.inviteCode).update({
        'expiresAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
      });

      await expectLater(
        service.acceptBuddyInvite(invite.inviteCode, acceptor),
        throwsA(isA<Exception>()),
      );
      expect((await readPair(invite.pairId))['status'], 'pending');
    });

    test('rejects a code whose pair no longer exists', () async {
      final invite = await service.createBuddyInvite(creator);
      await firestore.collection('buddyPairs').doc(invite.pairId).delete();

      await expectLater(
        service.acceptBuddyInvite(invite.inviteCode, acceptor),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('getBuddyPair', () {
    test('returns the active pair a user belongs to', () async {
      final invite = await service.createBuddyInvite(creator);
      await service.acceptBuddyInvite(invite.inviteCode, acceptor);

      final pair = await service.getBuddyPair(acceptor);

      expect(pair, isNotNull);
      expect(pair!.id, invite.pairId);
      expect(pair.status, BuddyPairStatus.active);
    });

    test('returns null while the pair is still pending', () async {
      await service.createBuddyInvite(creator);

      expect(await service.getBuddyPair(creator), isNull);
    });

    test('returns null for a user in no pair at all', () async {
      expect(await service.getBuddyPair('nobody'), isNull);
    });

    test('does not return a pair belonging to other people', () async {
      final invite = await service.createBuddyInvite(creator);
      await service.acceptBuddyInvite(invite.inviteCode, acceptor);

      expect(await service.getBuddyPair('carol'), isNull);
    });
  });

  group('endBuddyPair', () {
    test('takes the pair out of the active state', () async {
      final invite = await service.createBuddyInvite(creator);
      await service.acceptBuddyInvite(invite.inviteCode, acceptor);

      await service.endBuddyPair(invite.pairId);

      expect(await service.getBuddyPair(creator), isNull);
      expect((await readPair(invite.pairId))['status'], isNot('active'));
    });
  });
}

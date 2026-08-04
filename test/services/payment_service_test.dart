import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/payment_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PaymentService service;
  const userId = 'user-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = PaymentService(firestore);
  });

  Future<void> seedUser({bool hasAccess = false}) {
    return firestore.collection('users').doc(userId).set({
      'displayName': 'Ahmed',
      if (hasAccess) 'hasGlobalLeaderboardAccess': true,
    });
  }

  group('priceDisplay', () {
    test('formats the cent price as dollars', () {
      expect(service.priceDisplay, '\$5.00');
    });

    test('matches the configured price constant', () {
      expect(globalLeaderboardPriceCents, 500);
    });
  });

  group('checkGlobalLeaderboardAccess', () {
    test('is false for a user who has not paid', () async {
      await seedUser();

      expect(await service.checkGlobalLeaderboardAccess(userId), isFalse);
    });

    test('is true once the flag is set', () async {
      await seedUser(hasAccess: true);

      expect(await service.checkGlobalLeaderboardAccess(userId), isTrue);
    });

    test('is false for a user document that does not exist', () async {
      expect(await service.checkGlobalLeaderboardAccess('ghost'), isFalse);
    });
  });

  group('createGlobalLeaderboardPaymentIntent', () {
    test('returns a client secret and intent id for a paying user', () async {
      await seedUser();

      final intent = await service.createGlobalLeaderboardPaymentIntent(userId);

      expect(intent, isNotNull);
      expect(intent!['clientSecret'], isNotEmpty);
      expect(intent['paymentIntentId'], isNotEmpty);
    });

    test('returns null for a user who already has access', () async {
      // Charging twice for the same one-off unlock would be a real problem;
      // the method refuses rather than handing back a payable intent.
      await seedUser(hasAccess: true);

      expect(
        await service.createGlobalLeaderboardPaymentIntent(userId),
        isNull,
      );
    });

    test('issues a distinct intent per call', () async {
      await seedUser();

      final first = await service.createGlobalLeaderboardPaymentIntent(userId);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await service.createGlobalLeaderboardPaymentIntent(userId);

      expect(first!['paymentIntentId'], isNot(second!['paymentIntentId']));
    });
  });

  group('grantGlobalLeaderboardAccess', () {
    test('sets the access flag and a granted timestamp', () async {
      await seedUser();

      await service.grantGlobalLeaderboardAccess(userId);

      final doc = await firestore.collection('users').doc(userId).get();
      expect(doc.data()?['hasGlobalLeaderboardAccess'], isTrue);
      expect(doc.data()?['globalAccessGrantedAt'], isNotNull);
    });

    test('rethrows when the user document is missing', () async {
      // The caller needs to know the grant failed — silently swallowing it
      // would leave a paying user without what they bought.
      await expectLater(
        service.grantGlobalLeaderboardAccess('ghost'),
        throwsA(anything),
      );
    });
  });

  group('recordPaymentTransaction', () {
    test('writes the transaction under the user', () async {
      await seedUser();

      await service.recordPaymentTransaction(
        userId: userId,
        paymentIntentId: 'pi_123',
        amount: globalLeaderboardPriceCents,
        status: 'succeeded',
      );

      final doc = await firestore.collection('users').doc(userId).get();
      final transactions = doc.data()?['transactions'] as Map?;
      expect(transactions, isNotNull);
      expect(transactions!.values.single['paymentIntentId'], 'pi_123');
      expect(transactions.values.single['amount'], 500);
      expect(transactions.values.single['status'], 'succeeded');
    });

    test('defaults the type to the leaderboard unlock', () async {
      await seedUser();

      await service.recordPaymentTransaction(
        userId: userId,
        paymentIntentId: 'pi_123',
        amount: 500,
        status: 'succeeded',
      );

      final doc = await firestore.collection('users').doc(userId).get();
      final transactions = doc.data()?['transactions'] as Map;
      expect(
        transactions.values.single['type'],
        'global_leaderboard_access',
      );
    });

    test('swallows a failure rather than breaking the purchase flow', () async {
      // Audit bookkeeping is explicitly non-critical: a user who has paid must
      // not see an error because the receipt row could not be written.
      await expectLater(
        service.recordPaymentTransaction(
          userId: 'ghost',
          paymentIntentId: 'pi_123',
          amount: 500,
          status: 'succeeded',
        ),
        completes,
      );
    });
  });
}

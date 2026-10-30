import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/feature_flags.dart';

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

  // Z-PAY-001 / Z-PAY-002: payments stay off until store-compliant billing
  // ships, and access may only be granted by a trusted Cloud Function, never
  // by the client. These tests pin both guards; the old ones asserted the
  // client-side purchase and grant that the guards replaced.
  group('createGlobalLeaderboardPaymentIntent', () {
    test('refuses while payments are disabled', () async {
      expect(FeatureFlags.isPaymentsEnabled, isFalse);
      await seedUser();

      await expectLater(
        service.createGlobalLeaderboardPaymentIntent(userId),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses even for a user who already has access', () async {
      await seedUser(hasAccess: true);

      await expectLater(
        service.createGlobalLeaderboardPaymentIntent(userId),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('grantGlobalLeaderboardAccess', () {
    test('cannot grant access from the client', () async {
      await seedUser();

      await expectLater(
        service.grantGlobalLeaderboardAccess(userId),
        throwsA(isA<UnsupportedError>()),
      );
      final doc = await firestore.collection('users').doc(userId).get();
      expect(doc.data()?['hasGlobalLeaderboardAccess'], isNot(true));
    });

    test('still throws when the user document is missing', () async {
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

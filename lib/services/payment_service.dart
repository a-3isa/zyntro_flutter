import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';

/// Price for global leaderboard access in cents ($5.00).
const int globalLeaderboardPriceCents = 500;

/// Payment service for Stripe integration.
/// Matches React Native paymentService.ts behavior.
class PaymentService {
  final FirebaseFirestore _firestore;

  PaymentService(this._firestore);

  /// Create a PaymentIntent for global leaderboard access.
  /// In production, this should call a Firebase Cloud Function.
  /// For MVP, returns a mock client secret for simulation.
  Future<Map<String, String>?> createGlobalLeaderboardPaymentIntent(
    String userId,
  ) async {
    try {
      // Check if user already has access
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists &&
          userDoc.data()?['hasGlobalLeaderboardAccess'] == true) {
        throw Exception('User already has global leaderboard access');
      }

      // Production: Call Firebase Cloud Function to create PaymentIntent
      // Example:
      // final callable = FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      // final result = await callable.call({'userId': userId, 'amount': GLOBAL_LEADERBOARD_PRICE});
      // return {
      //   'clientSecret': result.data['clientSecret'],
      //   'paymentIntentId': result.data['paymentIntentId'],
      // };

      // MVP Fallback: Return mock data for simulation
      debugPrint(
        'PaymentService: Using mock PaymentIntent (Stripe not fully configured)',
      );
      return {
        'clientSecret': 'demo_secret_${DateTime.now().millisecondsSinceEpoch}',
        'paymentIntentId': 'demo_pi_${DateTime.now().millisecondsSinceEpoch}',
      };
    } catch (e) {
      debugPrint('Error creating payment intent: $e');
      return null;
    }
  }

  /// Grant global leaderboard access to a user.
  Future<void> grantGlobalLeaderboardAccess(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'hasGlobalLeaderboardAccess': true,
        'globalAccessGrantedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Granted global leaderboard access to user: $userId');
    } catch (e) {
      debugPrint('Error granting global leaderboard access: $e');
      rethrow;
    }
  }

  /// Check if user has global leaderboard access.
  Future<bool> checkGlobalLeaderboardAccess(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      return doc.data()?['hasGlobalLeaderboardAccess'] ?? false;
    } catch (e) {
      debugPrint('Error checking global leaderboard access: $e');
      return false;
    }
  }

  /// Record a payment transaction for audit purposes.
  /// Non-critical, errors are caught silently.
  Future<void> recordPaymentTransaction({
    required String userId,
    required String paymentIntentId,
    required int amount,
    required String status,
    String type = 'global_leaderboard_access',
  }) async {
    try {
      final transactionKey = 'txn_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.collection('users').doc(userId).update({
        'transactions.$transactionKey': {
          'paymentIntentId': paymentIntentId,
          'amount': amount,
          'status': status,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
        },
      });
      debugPrint('Recorded payment transaction: $transactionKey');
    } catch (e) {
      // Non-critical, log and continue
      debugPrint('Error recording payment transaction: $e');
    }
  }

  /// Get price display string.
  String get priceDisplay =>
      '\$${(globalLeaderboardPriceCents / 100).toStringAsFixed(2)}';
}

/// Payment service provider.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref.watch(firestoreProvider));
});

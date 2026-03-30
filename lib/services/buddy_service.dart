import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/constants/constants.dart';
import '../features/auth/auth_providers.dart';

/// Buddy service for managing buddy pairs and invite codes.
/// Matches React Native buddyService.ts behavior.
class BuddyService {
  final FirebaseFirestore _firestore;

  BuddyService(this._firestore);

  /// Generate 8-character alphanumeric invite code.
  /// Matches RN generateInviteCode.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Check if invite code already exists.
  Future<bool> _isCodeUnique(String code) async {
    final doc = await _firestore.collection('inviteCodes').doc(code).get();
    return !doc.exists;
  }

  /// Generate unique invite code with retry logic.
  /// Matches RN generateUniqueInviteCode.
  Future<String> generateUniqueInviteCode({int maxAttempts = 3}) async {
    for (int i = 0; i < maxAttempts; i++) {
      final code = _generateInviteCode();
      if (await _isCodeUnique(code)) {
        return code;
      }
    }
    throw Exception('Failed to generate unique invite code');
  }

  /// Create buddy invite and pending pair.
  /// Matches RN createBuddyInvite.
  Future<({String inviteCode, String pairId})> createBuddyInvite(
    String creatorId,
  ) async {
    final inviteCode = await generateUniqueInviteCode();

    // Create pending buddy pair
    final pairRef = _firestore.collection('buddyPairs').doc();
    final pairId = pairRef.id;

    await pairRef.set({
      'participants': [creatorId],
      'initiatorId': creatorId,
      'status': 'pending',
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create invite code document
    await _firestore.collection('inviteCodes').doc(inviteCode).set({
      'code': inviteCode,
      'creatorId': creatorId,
      'buddyPairId': pairId,
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      ),
    });

    return (inviteCode: inviteCode, pairId: pairId);
  }

  /// Accept buddy invite with transaction.
  /// Matches RN acceptBuddyInvite.
  Future<BuddyPair> acceptBuddyInvite(
    String inviteCode,
    String acceptorId,
  ) async {
    return await _firestore.runTransaction<BuddyPair>((transaction) async {
      // Get invite code document
      final codeDoc = await transaction.get(
        _firestore.collection('inviteCodes').doc(inviteCode),
      );

      if (!codeDoc.exists) {
        throw Exception('Invalid invite code');
      }

      final codeData = codeDoc.data()!;

      // Check if already used
      if (codeData['usedAt'] != null) {
        throw Exception('Invite code has already been used');
      }

      // Check expiry
      final expiresAt = (codeData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('Invite code has expired');
      }

      // Check not accepting own invite
      if (codeData['creatorId'] == acceptorId) {
        throw Exception('Cannot accept your own invite');
      }

      // Get buddy pair
      final pairId = codeData['buddyPairId'] as String;
      final pairDoc = await transaction.get(
        _firestore.collection('buddyPairs').doc(pairId),
      );

      if (!pairDoc.exists) {
        throw Exception('Buddy pair not found');
      }

      final pairData = pairDoc.data()!;

      // Update buddy pair
      transaction.update(_firestore.collection('buddyPairs').doc(pairId), {
        'participants': FieldValue.arrayUnion([acceptorId]),
        'status': 'active',
        'activatedAt': FieldValue.serverTimestamp(),
      });

      // Mark invite code as used
      transaction.update(_firestore.collection('inviteCodes').doc(inviteCode), {
        'usedAt': FieldValue.serverTimestamp(),
        'usedBy': acceptorId,
      });

      return BuddyPair(
        id: pairId,
        participants: [
          ...(pairData['participants'] as List).cast<String>(),
          acceptorId,
        ],
        initiatorId: pairData['initiatorId'],
        status: BuddyPairStatus.active,
        inviteCode: inviteCode,
        createdAt:
            (pairData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        activatedAt: DateTime.now(),
      );
    });
  }

  /// Get active buddy pair for a user.
  /// Matches RN getBuddyPair.
  Future<BuddyPair?> getBuddyPair(String userId) async {
    final snapshot = await _firestore
        .collection('buddyPairs')
        .where('participants', arrayContains: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return BuddyPair.fromFirestore(snapshot.docs.first);
  }

  /// Get buddy profile.
  /// Matches RN getBuddyProfile.
  Future<User?> getBuddyProfile(String buddyId) async {
    final doc = await _firestore.collection('users').doc(buddyId).get();
    if (!doc.exists) return null;
    return User.fromFirestore(doc);
  }

  /// End buddy pair.
  Future<void> endBuddyPair(String pairId) async {
    await _firestore.collection('buddyPairs').doc(pairId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Buddy service provider.
final buddyServiceProvider = Provider<BuddyService>((ref) {
  return BuddyService(ref.watch(authFirestoreProvider));
});

/// Current buddy pair provider.
final currentBuddyPairProvider = FutureProvider<BuddyPair?>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.valueOrNull?.id;
  if (uid == null) return null;
  return ref.watch(buddyServiceProvider).getBuddyPair(uid);
});


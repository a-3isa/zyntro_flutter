import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_providers.dart';

/// Outcome of a username claim attempt.
enum UsernameClaimResult {
  success,
  taken,
  invalid,
  error,
}

/// Service for validating, checking, and atomically claiming unique usernames.
///
/// Usernames are stored lowercase. Uniqueness is enforced via a dedicated
/// `usernames/{username}` collection whose document id is the lowercase handle.
/// A claim is performed inside a transaction so two users cannot grab the same
/// handle concurrently.
class UsernameService {
  final FirebaseFirestore _firestore;

  UsernameService(this._firestore);

  static const int minLength = 3;
  static const int maxLength = 20;

  /// Allowed: lowercase letters, digits, underscore. 3–20 characters.
  static final RegExp _pattern = RegExp(r'^[a-z0-9_]{3,20}$');

  /// Normalize raw input to the canonical stored form (trimmed, lowercase).
  String normalize(String raw) => raw.trim().toLowerCase();

  /// Returns null if valid, otherwise a human-readable validation error.
  String? validationError(String raw) {
    final value = normalize(raw);
    if (value.isEmpty) return 'Username is required.';
    if (value.length < minLength) {
      return 'Must be at least $minLength characters.';
    }
    if (value.length > maxLength) {
      return 'Must be at most $maxLength characters.';
    }
    if (!_pattern.hasMatch(value)) {
      return 'Only lowercase letters, numbers, and underscores.';
    }
    return null;
  }

  bool isValid(String raw) => validationError(raw) == null;

  /// Whether the (valid) username is not already claimed by someone else.
  /// [currentUserId] is treated as owning its own handle.
  Future<bool> isAvailable(String raw, {String? currentUserId}) async {
    final value = normalize(raw);
    if (!isValid(value)) return false;

    final doc = await _firestore.collection('usernames').doc(value).get();
    if (!doc.exists) return true;
    return doc.data()?['uid'] == currentUserId;
  }

  /// Atomically claim [raw] for [userId]. Also writes `username` and
  /// `usernameLower` onto the user document so search and display work.
  Future<UsernameClaimResult> claim({
    required String userId,
    required String raw,
  }) async {
    final value = normalize(raw);
    if (!isValid(value)) return UsernameClaimResult.invalid;

    final usernameRef = _firestore.collection('usernames').doc(value);
    final userRef = _firestore.collection('users').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(usernameRef);
        if (existing.exists && existing.data()?['uid'] != userId) {
          throw _UsernameTakenException();
        }

        transaction.set(usernameRef, {
          'uid': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(userRef, {
          'username': value,
          'usernameLower': value,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
      return UsernameClaimResult.success;
    } on _UsernameTakenException {
      return UsernameClaimResult.taken;
    } catch (_) {
      return UsernameClaimResult.error;
    }
  }
}

class _UsernameTakenException implements Exception {}

final usernameServiceProvider = Provider<UsernameService>((ref) {
  return UsernameService(ref.watch(authFirestoreProvider));
});

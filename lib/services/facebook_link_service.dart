import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../features/auth/data/models/user_profile_model.dart';
import '../features/auth/domain/entities/user_profile_entity.dart';

sealed class FacebookLinkResult<T> {
  const FacebookLinkResult();
}

final class FacebookLinkSuccess<T> extends FacebookLinkResult<T> {
  final T value;
  const FacebookLinkSuccess(this.value);
}

final class FacebookLinkCancelled<T> extends FacebookLinkResult<T> {
  const FacebookLinkCancelled();
}

final class FacebookLinkNoFriendsPermission<T> extends FacebookLinkResult<T> {
  final String facebookUid;
  const FacebookLinkNoFriendsPermission(this.facebookUid);
}

final class FacebookLinkFailure<T> extends FacebookLinkResult<T> {
  final String message;
  const FacebookLinkFailure(this.message);
}

class FacebookLinkService {
  final FirebaseFirestore _firestore;

  const FacebookLinkService({required this._firestore});

  /// Launches the Facebook login dialog, stores the facebookUid in Firestore,
  /// and returns matched Zyntro users who are friends on Facebook.
  Future<FacebookLinkResult<List<UserProfileEntity>>> connectFacebook(
    String userId,
  ) async {
    try {
      final loginResult = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'user_friends'],
      );

      if (loginResult.status == LoginStatus.cancelled) {
        return const FacebookLinkCancelled();
      }

      if (loginResult.status != LoginStatus.success ||
          loginResult.accessToken == null) {
        return const FacebookLinkFailure('Facebook login failed. Please try again.');
      }

      final token = loginResult.accessToken!;

      // Get Facebook user ID from profile data
      String? fbUserId;
      try {
        final userData = await FacebookAuth.instance.getUserData(fields: 'id');
        fbUserId = userData['id'] as String?;
      } catch (e) {
        debugPrint('[FacebookLinkService] getUserData(id) failed: $e');
      }

      // Fall back to ClassicToken.userId if available
      if (fbUserId == null && token is ClassicToken) {
        fbUserId = token.userId;
      }

      if (fbUserId == null) {
        return const FacebookLinkFailure('Could not read your Facebook ID. Please try again.');
      }

      await _writeFacebookUid(userId, fbUserId);

      // Check if user_friends permission was granted (ClassicToken only)
      if (token is ClassicToken) {
        final granted = token.grantedPermissions ?? [];
        if (!granted.contains('user_friends')) {
          return FacebookLinkNoFriendsPermission(fbUserId);
        }
      }

      final friends = await _fetchFriendsOnApp(token.tokenString);
      return FacebookLinkSuccess(friends);
    } catch (e) {
      debugPrint('[FacebookLinkService] connectFacebook error: $e');
      return const FacebookLinkFailure('Could not connect Facebook. Please try again.');
    }
  }

  /// Writes the Facebook UID directly from an existing access token string.
  /// Used after FB sign-in to ensure facebookUid is always stored.
  Future<void> storeFacebookUid(String userId, String fbUserId) async {
    try {
      await _writeFacebookUid(userId, fbUserId);
    } catch (e) {
      debugPrint('[FacebookLinkService] storeFacebookUid error: $e');
    }
  }

  /// Clears facebookUid from Firestore and logs out of the Facebook SDK.
  Future<void> disconnectFacebook(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'facebookUid': FieldValue.delete(),
        'facebookConnectedAt': FieldValue.delete(),
      });
      await FacebookAuth.instance.logOut();
    } catch (e) {
      debugPrint('[FacebookLinkService] disconnectFacebook error: $e');
    }
  }

  /// Fetches Zyntro users who are Facebook friends of the current user.
  /// Returns an empty list if no token is available or no friends are found.
  Future<List<UserProfileEntity>> fetchFriendsOnApp() async {
    try {
      final token = await FacebookAuth.instance.accessToken;
      if (token == null) return [];
      return _fetchFriendsOnApp(token.tokenString);
    } catch (e) {
      debugPrint('[FacebookLinkService] fetchFriendsOnApp error: $e');
      return [];
    }
  }

  Future<void> _writeFacebookUid(String userId, String fbUserId) async {
    await _firestore.collection('users').doc(userId).set({
      'facebookUid': fbUserId,
      'facebookConnectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<UserProfileEntity>> _fetchFriendsOnApp(String tokenString) async {
    try {
      final uri = Uri.https('graph.facebook.com', '/me/friends', {
        'fields': 'id',
        'limit': '200',
      });

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $tokenString'},
      );
      if (response.statusCode != 200) {
        debugPrint(
          '[FacebookLinkService] Graph API error: status=${response.statusCode}',
        );
        return [];
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];

      final fbIds = data
          .map((e) => (e as Map<String, dynamic>)['id'] as String?)
          .whereType<String>()
          .toList();

      if (fbIds.isEmpty) return [];

      // Firestore whereIn supports up to 30 (Z-DATA-005).
      const chunkSize = 30;
      final results = <UserProfileEntity>[];
      for (var i = 0; i < fbIds.length; i += chunkSize) {
        final chunk = fbIds.sublist(
          i,
          (i + chunkSize).clamp(0, fbIds.length),
        );
        final snapshot = await _firestore
            .collection('users')
            .where('facebookUid', whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          results.add(UserProfileModel.fromMap(doc.data(), doc.id).toEntity());
        }
      }

      return results;
    } catch (e) {
      debugPrint('[FacebookLinkService] _fetchFriendsOnApp error: $e');
      return [];
    }
  }
}

final facebookLinkServiceProvider = Provider<FacebookLinkService>((ref) {
  return FacebookLinkService(firestore: FirebaseFirestore.instance);
});

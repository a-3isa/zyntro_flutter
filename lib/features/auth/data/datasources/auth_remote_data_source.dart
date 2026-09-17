import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../services/notification_service.dart';
import '../exceptions/auth_data_exception.dart';
import '../models/auth_user_model.dart';
import '../models/user_profile_model.dart';

class AuthRemoteDataSource {
  static const _googleServerClientId =
      '146147804221-i1dgf7t2t2lf9puara1ukeskar1gtbkt.apps.googleusercontent.com';

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  DateTime? _lastReauthAt;

  AuthRemoteDataSource({
    required this._auth,
    required this._firestore,
    required this._notificationService,
  });

  /// True if the Firebase SDK already has a user in memory (synchronous read
  /// from local persistence — available immediately after initializeApp).
  bool get hasCurrentUser => _auth.currentUser != null;

  Stream<AuthUserModel?> authStateChanges() {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return AuthUserModel.fromFirebaseUser(user);
    });
  }

  Future<AuthUserModel?> getCurrentUser() async {
    final current = _auth.currentUser;
    if (current == null) return null;
    return AuthUserModel.fromFirebaseUser(current);
  }

  Future<AuthUserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw AuthDataException.unknown('No authenticated user returned.');
      }

      await _ensureNotBanned(user.uid);
      await _registerPushNotifications(user.uid);
      return AuthUserModel.fromFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (e) {
      throw AuthDataException.unknown(
        'Authentication failed. Please try again.',
      );
    }
  }

  Future<AuthUserModel> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw AuthDataException.unknown('No created user returned.');
      }

      // Best-effort: a mail-quota/network failure must not fail an otherwise
      // successful sign-up. The user can resend from the verification banner.
      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('[AuthRemoteDataSource] sendEmailVerification failed: $e');
      }

      await _registerPushNotifications(user.uid);
      return AuthUserModel.fromFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (e) {
      throw AuthDataException.unknown('Sign up failed. Please try again.');
    }
  }

  Future<AuthUserModel?> signInWithGoogle() async {
    try {
      final google = await _googleSignInResult();

      final result = await _auth.signInWithCredential(google.credential);
      final user = result.user;
      if (user == null) return null;

      await _ensureProfileExists(
        userId: user.uid,
        displayName: user.displayName ?? google.displayName ?? 'User',
        photoUrl: user.photoURL ?? google.photoUrl,
        authProvider: 'google',
      );

      await _ensureNotBanned(user.uid);
      await _registerPushNotifications(user.uid);
      return AuthUserModel.fromFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'canceled') return null;
      throw _mapFirebaseAuthException(e);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      throw AuthDataException.unknown(
        'Google Sign-In failed. Please try again.',
      );
    } on AuthDataException {
      rethrow;
    } catch (e) {
      debugPrint('[GoogleSignIn] error type: ${e.runtimeType} | $e');
      // PlatformException code sign_in_canceled means user dismissed
      final msg = e.toString();
      if (msg.contains('sign_in_canceled') || msg.contains('canceled')) {
        return null;
      }
      throw AuthDataException.unknown(
        'Google Sign-In failed. Please try again.',
      );
    }
  }

  Future<AuthUserModel?> signInWithFacebook() async {
    try {
      final loginResult = await FacebookAuth.instance.login();

      if (loginResult.status == LoginStatus.cancelled) {
        return null;
      }

      if (loginResult.status != LoginStatus.success ||
          loginResult.accessToken == null) {
        throw AuthDataException.auth(
          code: 'facebook-auth-failed',
          message: 'Facebook Sign-In failed. Please try again.',
        );
      }

      String? displayName;
      String? photoUrl;
      String? facebookUserId;
      try {
        final userData = await FacebookAuth.instance.getUserData(
          fields: 'id,name,email,picture.width(400).height(400)',
        );
        facebookUserId = userData['id'] as String?;
        displayName = userData['name'] as String?;
        final picture = userData['picture']?['data'];
        photoUrl = picture?['url'] as String?;
      } catch (e) {
        debugPrint('[AuthRemoteDataSource] failed to read Facebook user: $e');
      }

      final credential = fb.FacebookAuthProvider.credential(
        loginResult.accessToken!.tokenString,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw AuthDataException.unknown('No authenticated user returned.');
      }

      await _ensureProfileExists(
        userId: user.uid,
        displayName: displayName ?? user.displayName ?? 'User',
        photoUrl: photoUrl ?? user.photoURL,
        authProvider: 'facebook',
      );

      // Store Facebook UID so friend discovery works across all sign-in methods.
      if (facebookUserId != null) {
        await _storeFacebookUid(user.uid, facebookUserId);
      }

      await _ensureNotBanned(user.uid);
      await _registerPushNotifications(user.uid);
      return AuthUserModel.fromFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (e) {
      throw AuthDataException.unknown(
        'Facebook Sign-In failed. Please try again.',
      );
    }
  }

  Future<AuthUserModel?> signInWithApple() async {
    try {
      final apple = await _appleAuthCredential();
      final cred = await _auth.signInWithCredential(apple.credential);
      final user = cred.user;
      if (user == null) {
        throw AuthDataException.unknown(
          'Apple Sign-In failed. Please try again.',
        );
      }

      await _ensureProfileExists(
        userId: user.uid,
        displayName: user.displayName ?? apple.displayName ?? 'User',
        photoUrl: user.photoURL,
        authProvider: 'apple',
      );
      await _ensureNotBanned(user.uid);
      await _registerPushNotifications(user.uid);
      return AuthUserModel.fromFirebaseUser(user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw AuthDataException.unknown(
        'Apple Sign-In failed. Please try again.',
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (e) {
      throw AuthDataException.unknown(
        'Apple Sign-In failed. Please try again.',
      );
    }
  }

  Future<({fb.OAuthCredential credential, String? displayName})>
  _appleAuthCredential() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    if (appleCredential.identityToken == null) {
      throw AuthDataException.unknown(
        'Apple Sign-In failed. Please try again.',
      );
    }

    final given = appleCredential.givenName?.trim();
    final family = appleCredential.familyName?.trim();
    final parts = <String>[
      if (given != null && given.isNotEmpty) given,
      if (family != null && family.isNotEmpty) family,
    ];

    return (
      credential: fb.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      ),
      displayName: parts.isEmpty ? null : parts.join(' '),
    );
  }

  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  Future<void> signOut() async {
    try {
      final current = _auth.currentUser;
      if (current != null) {
        try {
          final deviceId = await _getOrCreateDeviceId();
          await _notificationService.removePushToken(current.uid, deviceId);
        } catch (e) {
          debugPrint('[AuthRemoteDataSource] remove push token failed: $e');
        }
      }

      await _auth.signOut();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('[AuthRemoteDataSource] Google signOut: $e');
      }
      try {
        await FacebookAuth.instance.logOut();
      } catch (e) {
        debugPrint('[AuthRemoteDataSource] Facebook logOut: $e');
      }
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (_) {
      throw AuthDataException.unknown('Sign out failed. Please try again.');
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthDataException.auth(
          code: 'user-not-found',
          message: 'No authenticated user found.',
        );
      }

      await user.sendEmailVerification();
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (_) {
      throw AuthDataException.unknown(
        'Could not send verification email. Please try again.',
      );
    }
  }

  Future<void> reloadCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthDataException.auth(
          code: 'user-not-found',
          message: 'No authenticated user found.',
        );
      }

      await user.reload();
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (_) {
      throw AuthDataException.unknown(
        'Unable to refresh authentication state.',
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (_) {
      throw AuthDataException.unknown(
        'Failed to send reset email. Please try again.',
      );
    }
  }

  Future<UserProfileModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserProfileModel.fromFirestore(doc);
    } on FirebaseException catch (_) {
      throw AuthDataException.server('Failed to load user profile.');
    }
  }

  Future<bool> isProfileComplete(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      if (data['isBanned'] == true) {
        await _auth.signOut();
        throw AuthDataException.auth(
          code: 'user-banned',
          message: 'This account has been suspended.',
        );
      }

      // A user is "set up" once they've finished onboarding. This single
      // explicit flag replaces the old multi-field heuristic so first-time
      // users are reliably sent to setup and returning users straight to home.
      return data['onboardingCompleted'] == true;
    } on AuthDataException {
      rethrow;
    } on FirebaseException catch (_) {
      throw AuthDataException.server('Failed to verify profile completeness.');
    }
  }

  Future<void> createUserProfile({
    required String userId,
    required String displayName,
    required WorkoutType workoutPreference,
    required bool beginnerFlag,
    String? photoUrl,
    String? avatarConfig,
    String? authProvider,
    int? trainingDaysPerWeek,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(userId);
      final snapshot = await docRef.get();
      final existing = snapshot.data();

      final data = <String, dynamic>{
        'displayName': displayName,
        // Only write photoURL when we actually have one. Writing null here on a
        // merge (e.g. when onboarding completes) would wipe the photo captured
        // from a Google/Facebook sign-in.
        'photoURL': ?photoUrl,
        'isPrivate': false,
        'workoutPreference': workoutPreference.value,
        'beginnerFlag': beginnerFlag,
        'avatarConfig': ?avatarConfig,
        'updatedAt': FieldValue.serverTimestamp(),
        'trainingDaysPerWeek': ?trainingDaysPerWeek,
      };

      // Preserve an existing auth provider (facebook/google). Only default to
      // 'email' the first time, so a later merge doesn't clobber it.
      if (authProvider != null) {
        data['authProvider'] = authProvider;
      } else if (existing == null || existing['authProvider'] == null) {
        data['authProvider'] = 'email';
      }

      if (!snapshot.exists ||
          existing == null ||
          !existing.containsKey('createdAt')) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await docRef.set(data, SetOptions(merge: true));
    } on FirebaseException catch (_) {
      throw AuthDataException.server('Failed to create user profile.');
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (_) {
      throw AuthDataException.server('Failed to update user profile.');
    }
  }

  Future<void> reauthenticate(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthDataException.auth(
          code: 'user-not-found',
          message: 'User not found. Please sign in again.',
        );
      }

      final providers = user.providerData.map((info) => info.providerId).toSet();

      if (password.isEmpty) {
        if (providers.contains('google.com')) {
          final google = await _googleSignInResult();
          await user.reauthenticateWithCredential(google.credential);
          _lastReauthAt = DateTime.now();
          return;
        }
        if (providers.contains('facebook.com')) {
          await user.reauthenticateWithCredential(
            await _facebookAuthCredential(),
          );
          _lastReauthAt = DateTime.now();
          return;
        }
        if (providers.contains('apple.com')) {
          final apple = await _appleAuthCredential();
          await user.reauthenticateWithCredential(apple.credential);
          _lastReauthAt = DateTime.now();
          return;
        }
        throw AuthDataException.auth(
          code: 'invalid-password',
          message: 'Please enter your password.',
        );
      }

      final email = user.email;
      if (email == null) {
        throw AuthDataException.auth(
          code: 'no-email-associated',
          message: 'No email is associated with this account.',
        );
      }

      final credential = fb.EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      _lastReauthAt = DateTime.now();
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } on GoogleSignInException {
      rethrow;
    } on SignInWithAppleAuthorizationException {
      rethrow;
    } catch (_) {
      throw AuthDataException.unknown(
        'Authentication failed. Please try again.',
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthDataException.auth(
          code: 'user-not-found',
          message: 'User not found. Please sign in again.',
        );
      }

      await reauthenticate(currentPassword);
      await user.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (_) {
      throw AuthDataException.unknown(
        'Failed to change password. Please try again.',
      );
    }
  }

  Future<void> changeEmail({
    required String password,
    required String newEmail,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthDataException.auth(
          code: 'user-not-found',
          message: 'User not found. Please sign in again.',
        );
      }

      await _reauthenticateIfStale(password);
      await user.verifyBeforeUpdateEmail(newEmail);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (_) {
      throw AuthDataException.unknown(
        'Failed to change email. Please try again.',
      );
    }
  }

  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthDataException.auth(
          code: 'user-not-found',
          message: 'User not found. Please sign in again.',
        );
      }

      final userId = user.uid;

      await _reauthenticateIfStale(password);

      try {
        final deviceId = await _getOrCreateDeviceId();
        await _notificationService.removePushToken(userId, deviceId);
      } catch (e) {
        debugPrint(
          '[AuthRemoteDataSource] remove push token before delete: $e',
        );
      }

      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
      rethrow;
    } catch (_) {
      throw AuthDataException.unknown(
        'Failed to delete account. Please try again.',
      );
    }
  }

  Future<void> _reauthenticateIfStale(String password) async {
    final last = _lastReauthAt;
    if (last != null && DateTime.now().difference(last) < const Duration(minutes: 5)) {
      return;
    }
    await reauthenticate(password);
  }

  Future<void> _ensureNotBanned(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.data()?['isBanned'] == true) {
        await _auth.signOut();
        throw AuthDataException.auth(
          code: 'user-banned',
          message: 'This account has been suspended.',
        );
      }
    } on AuthDataException {
      rethrow;
    } catch (e) {
      debugPrint('[AuthRemoteDataSource] ban check failed: $e');
    }
  }

  Future<
    ({fb.AuthCredential credential, String? displayName, String? photoUrl})
  >
  _googleSignInResult() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: _googleServerClientId);
    final googleUser = await googleSignIn.authenticate();
    return (
      credential: fb.GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
      ),
      displayName: googleUser.displayName,
      photoUrl: googleUser.photoUrl,
    );
  }

  Future<fb.AuthCredential> _facebookAuthCredential() async {
    final loginResult = await FacebookAuth.instance.login();
    if (loginResult.status == LoginStatus.cancelled) {
      throw AuthDataException.auth(
        code: 'canceled',
        message: 'Sign-in was cancelled.',
      );
    }
    if (loginResult.status != LoginStatus.success ||
        loginResult.accessToken == null) {
      throw AuthDataException.auth(
        code: 'facebook-auth-failed',
        message: 'Facebook Sign-In failed. Please try again.',
      );
    }
    return fb.FacebookAuthProvider.credential(
      loginResult.accessToken!.tokenString,
    );
  }

  Future<void> _storeFacebookUid(String userId, String facebookUserId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'facebookUid': facebookUserId,
        'facebookConnectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthRemoteDataSource] _storeFacebookUid failed: $e');
    }
  }

  Future<void> _ensureProfileExists({
    required String userId,
    required String displayName,
    required String? photoUrl,
    required String authProvider,
  }) async {
    final docRef = _firestore.collection('users').doc(userId);
    final doc = await docRef.get();

    if (doc.exists) return;

    await createUserProfile(
      userId: userId,
      displayName: displayName,
      workoutPreference: WorkoutType.other,
      beginnerFlag: false,
      photoUrl: photoUrl,
      authProvider: authProvider,
    );
  }

  Future<void> _registerPushNotifications(String userId) async {
    try {
      final token = await _notificationService.registerForPushNotifications();
      if (token == null) return;

      final deviceId = await _getOrCreateDeviceId();
      await _notificationService.savePushToken(userId, token, deviceId);
    } catch (e) {
      debugPrint('[AuthRemoteDataSource] register push token failed: $e');
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'device_id';
    var deviceId = prefs.getString(key);

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(key, deviceId);
    }

    return deviceId;
  }

  AuthDataException _mapFirebaseAuthException(fb.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return AuthDataException.auth(
          code: error.code,
          message: 'Please enter a valid email address.',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return AuthDataException.auth(
          code: error.code,
          message: 'Invalid email or password. Please try again.',
        );
      case 'weak-password':
        return AuthDataException.auth(
          code: error.code,
          message:
              'Password must be at least 8 characters with uppercase, number, and special character.',
        );
      case 'email-already-in-use':
        return AuthDataException.auth(
          code: error.code,
          message: 'An account with this email already exists.',
        );
      case 'user-disabled':
        return AuthDataException.auth(
          code: error.code,
          message: 'This account has been disabled. Please contact support.',
        );
      case 'network-request-failed':
        return AuthDataException.network();
      case 'too-many-requests':
        return AuthDataException.auth(
          code: error.code,
          message: 'Too many attempts. Please try again later.',
        );
      case 'user-not-found':
        return AuthDataException.auth(
          code: error.code,
          message: 'No account found with this email. Please sign up first.',
        );
      case 'operation-not-allowed':
        // Email/password provider is disabled in the Firebase console.
        return AuthDataException.auth(
          code: error.code,
          message: 'Email sign-in is not available right now.',
        );
      case 'requires-recent-login':
        return AuthDataException.auth(
          code: error.code,
          message: 'Please sign in again to complete this change.',
        );
      default:
        return AuthDataException.auth(
          code: error.code,
          message: 'Authentication failed. Please try again.',
        );
    }
  }
}

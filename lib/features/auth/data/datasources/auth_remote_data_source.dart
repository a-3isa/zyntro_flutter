import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../services/notification_service.dart';
import '../exceptions/auth_data_exception.dart';
import '../models/auth_user_model.dart';
import '../models/user_profile_model.dart';

class AuthRemoteDataSource {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  AuthRemoteDataSource({
    required fb.FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required NotificationService notificationService,
  }) : _auth = auth,
       _firestore = firestore,
       _notificationService = notificationService;

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
      // serverClientId must be the web/server OAuth client (client_type 3 in google-services.json).
      // GMS needs this to issue an idToken that Firebase Auth can verify.
      const serverClientId =
          '146147804221-i1dgf7t2t2lf9puara1ukeskar1gtbkt.apps.googleusercontent.com';
      final googleSignIn = GoogleSignIn(serverClientId: serverClientId);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // user dismissed picker

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) return null;

      await _ensureProfileExists(
        userId: user.uid,
        displayName: user.displayName ?? googleUser.displayName ?? 'User',
        photoUrl: user.photoURL ?? googleUser.photoUrl,
        authProvider: 'google',
      );

      await _registerPushNotifications(user.uid);
      return AuthUserModel.fromFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'canceled') return null;
      throw _mapFirebaseAuthException(e);
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
      try {
        final userData = await FacebookAuth.instance.getUserData(
          fields: 'name,email,picture.width(400).height(400)',
        );
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

      return (data['displayName'] as String?)?.isNotEmpty == true &&
          data['workoutPreference'] != null;
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

      final data = <String, dynamic>{
        'displayName': displayName,
        'photoURL': photoUrl,
        if (avatarConfig != null) 'avatarConfig': avatarConfig,
        'isPrivate': false,
        'workoutPreference': workoutPreference.value,
        'beginnerFlag': beginnerFlag,
        'authProvider': authProvider ?? 'email',
        'updatedAt': FieldValue.serverTimestamp(),
        if (trainingDaysPerWeek != null)
          'trainingDaysPerWeek': trainingDaysPerWeek,
      };

      final existing = snapshot.data();
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
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthDataException {
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

      await reauthenticate(password);
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

      await reauthenticate(password);

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
      default:
        return AuthDataException.auth(
          code: error.code,
          message: 'Authentication failed. Please try again.',
        );
    }
  }
}

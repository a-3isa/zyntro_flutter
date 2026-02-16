import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../core/models/models.dart';
import '../core/constants/constants.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Custom exception for authentication errors.
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Firebase Auth instance provider.
final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) {
  return fb.FirebaseAuth.instance;
});

/// Firestore instance provider.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Auth state stream provider.
/// Matches React Native's subscribeToAuthState behavior.
final authStateProvider = StreamProvider<fb.User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Current user profile provider.
final userProfileProvider = FutureProvider<User?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;

  if (uid == null) return null;

  final doc = await ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .get();

  if (!doc.exists) return null;
  return User.fromFirestore(doc);
});

/// Auth service for authentication operations.
class AuthService {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Ref _ref;

  AuthService(this._auth, this._firestore, this._ref);

  /// Get current user ID.
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if email is verified.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Send email verification.
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Reload user to refresh auth state (e.g. email verification).
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Sign in with email and password.
  /// Matches React Native's signInWithEmail.
  Future<fb.User> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Register for push notifications after successful sign in
      await _registerPushNotifications(result.user!.uid);

      return result.user!;
    } on fb.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Authentication failed. Please try again.');
    }
  }

  /// Sign up with email and password.
  /// Matches React Native's signUpWithEmail.
  Future<fb.User> signUpWithEmail(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email
      try {
        await result.user?.sendEmailVerification();
      } catch (e) {
        debugPrint('[AuthService] Error sending verification email: $e');
      }

      // Register for push notifications after successful sign up
      await _registerPushNotifications(result.user!.uid);

      return result.user!;
    } on fb.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Sign up failed. Please try again.');
    }
  }

  AuthException _handleAuthException(fb.FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'invalid-email':
        message = 'Please enter a valid email address.';
        break;
      case 'wrong-password':
      case 'invalid-credential':
        message = 'Invalid email or password. Please try again.';
        break;
      case 'weak-password':
        message =
            'Password must be at least 8 characters with uppercase, number, and special character.';
        break;
      case 'email-already-in-use':
        message = 'An account with this email already exists.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled. Please contact support.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection.';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please try again later.';
        break;
      case 'user-not-found':
        message = 'No account found with this email. Please sign up first.';
        break;
      default:
        message = 'Authentication failed. Please try again.';
    }
    return AuthException(message, code: e.code);
  }

  /// Register push notifications and save token.
  Future<void> _registerPushNotifications(String userId) async {
    try {
      final notificationService = _ref.read(notificationServiceProvider);
      final token = await notificationService.registerForPushNotifications();

      if (token != null) {
        final deviceId = await getDeviceId();
        await notificationService.savePushToken(userId, token, deviceId);
        debugPrint('[AuthService] Push token registered for user: $userId');
      }
    } catch (e) {
      debugPrint('[AuthService] Error registering push notifications: $e');
    }
  }

  /// Sign out the current user.
  /// Removes push token before signing out.
  Future<void> signOut() async {
    final userId = _auth.currentUser?.uid;

    if (userId != null) {
      try {
        final deviceId = await getDeviceId();
        await _ref
            .read(notificationServiceProvider)
            .removePushToken(userId, deviceId);
        debugPrint('[AuthService] Push token removed for user: $userId');
      } catch (e) {
        debugPrint('[AuthService] Error removing push token: $e');
      }
    }

    await _auth.signOut();
  }

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Get user profile from Firestore.
  Future<User?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return User.fromFirestore(doc);
  }

  /// Check if user profile is complete.
  Future<bool> isProfileComplete(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;

    final data = doc.data();
    if (data == null) return false;

    return data['displayName'] != null && data['workoutPreference'] != null;
  }

  /// Create user profile in Firestore.
  /// Matches React Native's createUserProfile.

  Future<void> createUserProfile({
    required String userId,
    required String displayName,
    required WorkoutType workoutPreference,
    required bool beginnerFlag,
    String? photoURL,
    String? avatarConfig, // Avatar configuration data (for custom avatars)
    String? authProvider, // Track auth provider (email/google/facebook)
  }) async {
    // Use SetOptions(merge: true) to preserve existing data (like createdAt)
    // while ensuring other fields are set.
    final data = {
      'displayName': displayName,
      'photoURL': photoURL,
      if (avatarConfig != null) 'avatarConfig': avatarConfig,
      'isPrivate': false,
      'workoutPreference': workoutPreference.value,
      'beginnerFlag': beginnerFlag,
      'authProvider': authProvider ?? 'email', // Track auth provider
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Check if we need to set createdAt (can't easily check existence here without read)
    // Instructions say "only set it if absent".
    // Since we are using merge: true, if we OMIT it, it won't be overwritten.
    // However, if it's a new doc, we want it.
    // Compromise: We will NOT include 'createdAt' in this set call.
    // If the document is new, 'createdAt' will be missing? That's bad.
    // But createUserProfile implies NEW profile.
    // Comment 3 says: "Creating profile overwrites existing user data and resets createdAt".
    // This implies the user document MIGHT already exist (e.g. from auth creation trigger?).
    // To solve strictly: read, check, then write. Or use a script that sets it only if null (not possible in simple set).
    // I will read first since I can't guarantee existence.
    // Actually, `createUserProfile` is called after successful sign up/in.
    // I'll read the doc first to check existence.
    final docRef = _firestore.collection('users').doc(userId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists || !docSnapshot.data()!.containsKey('createdAt')) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  /// Sign in with Google (using Firebase Provider flow).
  Future<fb.User?> signInWithGoogle() async {
    try {
      final fb.GoogleAuthProvider provider = fb.GoogleAuthProvider();

      // Using signInWithProvider for a unified middleware approach
      final result = await _auth.signInWithProvider(provider);

      // Register for push notifications and auto-create profile if needed
      if (result.user != null) {
        final user = result.user!;

        // Check if profile exists
        final docRef = _firestore.collection('users').doc(user.uid);
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          // Auto-create profile with Google data
          await createUserProfile(
            userId: user.uid,
            displayName: user.displayName ?? 'User',
            workoutPreference: WorkoutType.other,
            beginnerFlag: false,
            photoURL: user.photoURL,
            authProvider: 'google',
          );
        }

        await _registerPushNotifications(user.uid);
      }

      return result.user;
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In error: $e');
      if (e is fb.FirebaseAuthException && e.code == 'canceled') return null;
      rethrow;
    }
  }

  /// Sign in with Facebook (using flutter_facebook_auth flow).
  Future<fb.UserCredential> signInWithFacebook() async {
    try {
      // Trigger the sign-in flow
      final LoginResult loginResult = await FacebookAuth.instance.login();

      if (loginResult.status == LoginStatus.success) {
        // Get high-resolution profile photo from Facebook Graph API
        String? highResPhotoUrl;
        String? fbDisplayName;
        try {
          final userData = await FacebookAuth.instance.getUserData(
            fields: "name,email,picture.width(400).height(400)",
          );
          fbDisplayName = userData['name'] as String?;
          final pictureData = userData['picture']?['data'];
          if (pictureData != null) {
            highResPhotoUrl = pictureData['url'] as String?;
          }
          debugPrint(
            '[AuthService] Facebook user data retrieved: name=$fbDisplayName, hasPhoto=${highResPhotoUrl != null}',
          );
        } catch (e) {
          debugPrint('[AuthService] Error fetching Facebook user data: $e');
        }

        // Create a credential from the access token
        final fb.OAuthCredential facebookAuthCredential =
            fb.FacebookAuthProvider.credential(
              loginResult.accessToken!.tokenString,
            );

        // Once signed in, return the UserCredential
        final userCredential = await _auth.signInWithCredential(
          facebookAuthCredential,
        );

        // Register for push notifications and auto-create profile if needed
        if (userCredential.user != null) {
          final user = userCredential.user!;

          // Check if profile exists
          final docRef = _firestore.collection('users').doc(user.uid);
          final docSnapshot = await docRef.get();

          if (!docSnapshot.exists) {
            // Auto-create profile with Facebook data
            // Use high-res photo if available, fallback to Firebase Auth photo
            await createUserProfile(
              userId: user.uid,
              displayName: fbDisplayName ?? user.displayName ?? 'User',
              workoutPreference: WorkoutType.other,
              beginnerFlag: false,
              photoURL: highResPhotoUrl ?? user.photoURL,
              authProvider: 'facebook',
            );
          }

          await _registerPushNotifications(user.uid);
        }

        return userCredential;
      } else {
        throw AuthException('Facebook Sign-In canceled');
      }
    } catch (e) {
      debugPrint('[AuthService] Facebook Sign-In error: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Facebook Sign-In failed. Please try again.');
    }
  }

  /// Update user profile in Firestore.
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('users').doc(userId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get or create a persistent device ID.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'device_id';
    String? deviceId = prefs.getString(key);

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(key, deviceId);
    }
    return deviceId;
  }

  /// Re-authenticate user with password.
  /// Required before sensitive operations like password change, email change, or account deletion.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('user-not-found');
    }

    final email = user.email;
    if (email == null) {
      throw Exception('no-email-associated');
    }

    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  /// Change user password.
  /// Requires current password for re-authentication.
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('user-not-found');
    }

    // Re-authenticate first
    await reauthenticate(currentPassword);

    // Update password
    await user.updatePassword(newPassword);
    debugPrint('[AuthService] Password changed successfully');
  }

  /// Change user email.
  /// Sends verification email to new address. Email is only updated after verification.
  Future<void> changeEmail(String password, String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('user-not-found');
    }

    // Re-authenticate first
    await reauthenticate(password);

    // Send verification to new email
    await user.verifyBeforeUpdateEmail(newEmail);
    debugPrint('[AuthService] Verification email sent to $newEmail');
  }

  /// Delete user account.
  /// This permanently deletes the Firebase Auth account.
  /// Note: Firestore data cleanup should be handled by Cloud Functions.
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('user-not-found');
    }

    final userId = user.uid;

    // Re-authenticate first
    await reauthenticate(password);

    // Remove push token before deletion
    try {
      final deviceId = await getDeviceId();
      await _ref
          .read(notificationServiceProvider)
          .removePushToken(userId, deviceId);
    } catch (e) {
      debugPrint('[AuthService] Error removing push token: $e');
    }

    // Delete the user account
    await user.delete();
    debugPrint('[AuthService] Account deleted for user: $userId');
  }

  /// Check if user session is still valid.
  Future<bool> isSessionValid() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Force token refresh to verify session
      await user.getIdToken(true);
      return true;
    } catch (e) {
      debugPrint('[AuthService] Session invalid: $e');
      return false;
    }
  }

  /// Refresh auth token if needed.
  Future<String?> refreshAuthToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken(true);
    } catch (e) {
      debugPrint('[AuthService] Error refreshing token: $e');
      return null;
    }
  }

  /// Get profile completion percentage.
  Future<double> getProfileCompletionPercentage(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 0.0;

    final data = doc.data();
    if (data == null) return 0.0;

    int completedFields = 0;
    const int totalFields = 4; // displayName, photoURL, workoutPreference, bio

    if (data['displayName'] != null &&
        (data['displayName'] as String).isNotEmpty) {
      completedFields++;
    }
    if (data['photoURL'] != null && (data['photoURL'] as String).isNotEmpty) {
      completedFields++;
    }
    if (data['workoutPreference'] != null) completedFields++;
    if (data['bio'] != null && (data['bio'] as String).isNotEmpty) {
      completedFields++;
    }

    return completedFields / totalFields;
  }

  /// Get list of missing profile fields.
  Future<List<String>> getMissingProfileFields(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      return ['displayName', 'photoURL', 'workoutPreference', 'bio'];
    }

    final data = doc.data();
    if (data == null) {
      return ['displayName', 'photoURL', 'workoutPreference', 'bio'];
    }

    final List<String> missingFields = [];

    if (data['displayName'] == null ||
        (data['displayName'] as String).isEmpty) {
      missingFields.add('displayName');
    }
    if (data['photoURL'] == null || (data['photoURL'] as String).isEmpty) {
      missingFields.add('photoURL');
    }
    if (data['workoutPreference'] == null) {
      missingFields.add('workoutPreference');
    }
    if (data['bio'] == null || (data['bio'] as String).isEmpty) {
      missingFields.add('bio');
    }

    return missingFields;
  }
}

/// Auth service provider.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref,
  );
});

/// Profile completion provider.
final profileCompletionProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;

  if (uid == null) return false;

  return ref.read(authServiceProvider).isProfileComplete(uid);
});

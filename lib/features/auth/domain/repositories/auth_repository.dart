import '../../../../core/constants/constants.dart';
import '../entities/auth_user_entity.dart';
import '../entities/user_profile_entity.dart';

abstract class AuthRepository {
  Stream<AuthUserEntity?> authStateChanges();

  Future<AuthUserEntity?> getCurrentUser();

  Future<AuthUserEntity> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUserEntity> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUserEntity?> signInWithGoogle();

  Future<AuthUserEntity?> signInWithFacebook();

  Future<void> signOut();

  Future<void> sendEmailVerification();

  Future<void> reloadCurrentUser();

  Future<void> sendPasswordResetEmail(String email);

  Future<UserProfileEntity?> getUserProfile(String userId);

  Future<bool> isProfileComplete(String userId);

  Future<void> createUserProfile({
    required String userId,
    required String displayName,
    required WorkoutType workoutPreference,
    required bool beginnerFlag,
    String? photoUrl,
    String? avatarConfig,
    String? authProvider,
  });

  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  });

  Future<void> reauthenticate(String password);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> changeEmail({
    required String password,
    required String newEmail,
  });

  Future<void> deleteAccount(String password);
}

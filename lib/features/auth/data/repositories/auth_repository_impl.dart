import '../../../../core/constants/constants.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  @override
  Stream<AuthUserEntity?> authStateChanges() {
    // Snapshot the sync state before the stream opens. If Firebase already has
    // a user in memory (restored from disk after initializeApp), the first null
    // the stream emits is a transient cold-start emission — skip it entirely so
    // it never reaches the router or cache logic.
    final hasSyncUser = _remoteDataSource.hasCurrentUser;

    return _remoteDataSource
        .authStateChanges()
        .skipWhile((model) => model == null && hasSyncUser)
        .asyncMap((model) async {
          if (model != null) {
            await _localDataSource.cacheUser(model);
            return model.toEntity();
          }

          // Firebase emitted null. Before treating this as a sign-out, check the
          // local cache. This covers network-offline cold starts and other edge
          // cases where skipWhile doesn't apply (hasSyncUser was already false).
          // signOut() clears the cache before Firebase emits null, so a non-empty
          // cache here means the null is still transient (not a real logout).
          final cached = await _localDataSource.getCachedUser();
          if (cached != null) {
            return cached.toEntity();
          }

          await _localDataSource.clearCachedUser();
          return null;
        });
  }

  @override
  Future<AuthUserEntity?> getCurrentUser() async {
    final current = await _remoteDataSource.getCurrentUser();
    if (current != null) {
      await _localDataSource.cacheUser(current);
      return current.toEntity();
    }

    final cached = await _localDataSource.getCachedUser();
    return cached?.toEntity();
  }

  @override
  Future<AuthUserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final model = await _remoteDataSource.signInWithEmail(
      email: email,
      password: password,
    );
    await _localDataSource.cacheUser(model);
    return model.toEntity();
  }

  @override
  Future<AuthUserEntity> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final model = await _remoteDataSource.signUpWithEmail(
      email: email,
      password: password,
    );
    await _localDataSource.cacheUser(model);
    return model.toEntity();
  }

  @override
  Future<AuthUserEntity?> signInWithGoogle() async {
    final model = await _remoteDataSource.signInWithGoogle();
    if (model == null) return null;

    await _localDataSource.cacheUser(model);
    return model.toEntity();
  }

  @override
  Future<AuthUserEntity?> signInWithFacebook() async {
    final model = await _remoteDataSource.signInWithFacebook();
    if (model == null) return null;

    await _localDataSource.cacheUser(model);
    return model.toEntity();
  }

  @override
  Future<void> signOut() async {
    await _remoteDataSource.signOut();
    await _localDataSource.clearCachedUser();
  }

  @override
  Future<void> sendEmailVerification() {
    return _remoteDataSource.sendEmailVerification();
  }

  @override
  Future<void> reloadCurrentUser() {
    return _remoteDataSource.reloadCurrentUser();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _remoteDataSource.sendPasswordResetEmail(email);
  }

  @override
  Future<UserProfileEntity?> getUserProfile(String userId) async {
    final model = await _remoteDataSource.getUserProfile(userId);
    return model?.toEntity();
  }

  @override
  Future<bool> isProfileComplete(String userId) {
    return _remoteDataSource.isProfileComplete(userId);
  }

  @override
  Future<void> createUserProfile({
    required String userId,
    required String displayName,
    required WorkoutType workoutPreference,
    required bool beginnerFlag,
    String? photoUrl,
    String? avatarConfig,
    String? authProvider,
    int? trainingDaysPerWeek,
  }) {
    return _remoteDataSource.createUserProfile(
      userId: userId,
      displayName: displayName,
      workoutPreference: workoutPreference,
      beginnerFlag: beginnerFlag,
      photoUrl: photoUrl,
      avatarConfig: avatarConfig,
      authProvider: authProvider,
      trainingDaysPerWeek: trainingDaysPerWeek,
    );
  }

  @override
  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return _remoteDataSource.updateUserProfile(userId: userId, data: data);
  }

  @override
  Future<void> reauthenticate(String password) {
    return _remoteDataSource.reauthenticate(password);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> changeEmail({
    required String password,
    required String newEmail,
  }) {
    return _remoteDataSource.changeEmail(
      password: password,
      newEmail: newEmail,
    );
  }

  @override
  Future<void> deleteAccount(String password) {
    return _remoteDataSource.deleteAccount(password);
  }
}

import '../../../../core/common/result.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../entities/auth_user_entity.dart';
import '../entities/user_profile_entity.dart';
import '../failures/auth_failure.dart';
import '../repositories/auth_repository.dart';

class AuthenticationUseCase {
  final AuthRepository _repository;

  AuthenticationUseCase(this._repository);

  Stream<AuthUserEntity?> observeAuthState() {
    return _repository.authStateChanges();
  }

  Future<AuthUserEntity?> getCurrentUser() {
    return _repository.getCurrentUser();
  }

  Future<Result<AuthUserEntity, AuthFailure>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final validation = _validateEmailPassword(email: email, password: password);
    if (validation != null) {
      return Result.failure(validation);
    }

    try {
      final user = await _repository.signInWithEmail(
        email: email.trim(),
        password: password,
      );
      return Result.success(user);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<AuthUserEntity, AuthFailure>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final validation = _validateEmailPassword(email: email, password: password);
    if (validation != null) {
      return Result.failure(validation);
    }

    try {
      final user = await _repository.signUpWithEmail(
        email: email.trim(),
        password: password,
      );
      return Result.success(user);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<AuthUserEntity?, AuthFailure>> signInWithGoogle() async {
    try {
      final user = await _repository.signInWithGoogle();
      return Result.success(user);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<AuthUserEntity?, AuthFailure>> signInWithFacebook() async {
    try {
      final user = await _repository.signInWithFacebook();
      return Result.success(user);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> signOut() async {
    try {
      await _repository.signOut();
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> sendEmailVerification() async {
    try {
      await _repository.sendEmailVerification();
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> reloadCurrentUser() async {
    try {
      await _repository.reloadCurrentUser();
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> sendPasswordResetEmail(String email) async {
    if (!_isValidEmail(email.trim())) {
      return Result.failure(
        AuthFailure.validation(
          'Please enter a valid email address.',
          code: 'invalid-email',
        ),
      );
    }

    try {
      await _repository.sendPasswordResetEmail(email.trim());
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<UserProfileEntity?, AuthFailure>> getUserProfile(
    String userId,
  ) async {
    try {
      final profile = await _repository.getUserProfile(userId);
      return Result.success(profile);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<bool, AuthFailure>> isProfileComplete(String userId) async {
    try {
      final isComplete = await _repository.isProfileComplete(userId);
      return Result.success(isComplete);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> createUserProfile({
    required String userId,
    required String displayName,
    required WorkoutType workoutPreference,
    required bool beginnerFlag,
    String? photoUrl,
    String? avatarConfig,
    String? authProvider,
    int? trainingDaysPerWeek,
  }) async {
    if (displayName.trim().length < 2) {
      return Result.failure(
        AuthFailure.validation(
          'Name must be at least 2 characters.',
          code: 'invalid-display-name',
        ),
      );
    }

    try {
      await _repository.createUserProfile(
        userId: userId,
        displayName: displayName.trim(),
        workoutPreference: workoutPreference,
        beginnerFlag: beginnerFlag,
        photoUrl: photoUrl,
        avatarConfig: avatarConfig,
        authProvider: authProvider,
        trainingDaysPerWeek: trainingDaysPerWeek,
      );
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _repository.updateUserProfile(userId: userId, data: data);
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> reauthenticate(String password) async {
    if (password.isEmpty) {
      return Result.failure(
        AuthFailure.validation(
          'Please enter your password.',
          code: 'invalid-password',
        ),
      );
    }

    try {
      await _repository.reauthenticate(password);
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      return Result.failure(
        AuthFailure.validation(
          'Password must be at least 6 characters.',
          code: 'weak-password',
        ),
      );
    }

    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> changeEmail({
    required String password,
    required String newEmail,
  }) async {
    if (!_isValidEmail(newEmail.trim())) {
      return Result.failure(
        AuthFailure.validation(
          'Please enter a valid email address.',
          code: 'invalid-email',
        ),
      );
    }

    try {
      await _repository.changeEmail(
        password: password,
        newEmail: newEmail.trim(),
      );
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  Future<Result<void, AuthFailure>> deleteAccount(String password) async {
    if (password.isEmpty) {
      return Result.failure(
        AuthFailure.validation(
          'Please enter your password.',
          code: 'invalid-password',
        ),
      );
    }

    try {
      await _repository.deleteAccount(password);
      return Result.success<void, AuthFailure>(null);
    } catch (e) {
      return Result.failure(_mapFailure(e));
    }
  }

  AuthFailure? _validateEmailPassword({
    required String email,
    required String password,
  }) {
    if (!_isValidEmail(email.trim())) {
      return AuthFailure.validation(
        'Please enter a valid email address.',
        code: 'invalid-email',
      );
    }

    if (password.isEmpty) {
      return AuthFailure.validation(
        'Please enter your password.',
        code: 'invalid-password',
      );
    }

    return null;
  }

  bool _isValidEmail(String value) {
    if (value.isEmpty) return false;
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  AuthFailure _mapFailure(Object error) {
    if (error is AppException) {
      return AuthFailure(message: error.message, code: error.code);
    }

    if (error is AuthFailure) {
      return error;
    }

    return AuthFailure.unknown();
  }
}

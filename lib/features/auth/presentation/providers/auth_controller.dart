import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/common/result.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/migration/migration.dart';
import '../../auth_providers.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/usecases/authentication_usecase.dart';

class AuthFlowException implements Exception {
  final String message;
  final String? code;

  const AuthFlowException({required this.message, this.code});

  @override
  String toString() => message;
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(
    useCase: ref.read(authenticationUseCaseProvider),
    migrationRepository: ref.read(migrationGovernanceRepositoryProvider),
    validationEvidenceService: ref.read(validationEvidenceServiceProvider),
    domainFailureCategoryMapper: ref.read(domainFailureCategoryMapperProvider),
    telemetryBaselineService: ref.read(telemetryBaselineServiceProvider),
  );
});

class AuthController {
  final AuthenticationUseCase _useCase;
  final MigrationGovernanceRepository _migrationRepository;
  final ValidationEvidenceService _validationEvidenceService;
  final DomainFailureCategoryMapper _domainFailureCategoryMapper;
  final TelemetryBaselineService _telemetryBaselineService;

  AuthController({
    required this._useCase,
    required this._migrationRepository,
    required this._validationEvidenceService,
    required this._domainFailureCategoryMapper,
    required this._telemetryBaselineService,
  });

  Future<AuthUserEntity> signInWithEmail(String email, String password) async {
    await ensureMigrationSliceInitialized();
    final result = await _useCase.signInWithEmail(
      email: email,
      password: password,
    );
    return _resolveValue(result);
  }

  Future<AuthUserEntity> signUpWithEmail(String email, String password) async {
    await ensureMigrationSliceInitialized();
    final result = await _useCase.signUpWithEmail(
      email: email,
      password: password,
    );
    return _resolveValue(result);
  }

  Future<AuthUserEntity?> signInWithGoogle() async {
    await ensureMigrationSliceInitialized();
    final result = await _useCase.signInWithGoogle();
    return _resolveValue(result);
  }

  Future<AuthUserEntity?> signInWithFacebook() async {
    await ensureMigrationSliceInitialized();
    final result = await _useCase.signInWithFacebook();
    return _resolveValue(result);
  }

  Future<AuthUserEntity?> signInWithApple() async {
    await ensureMigrationSliceInitialized();
    final result = await _useCase.signInWithApple();
    return _resolveValue(result);
  }

  Future<void> signOut() async {
    final result = await _useCase.signOut();
    await _resolveVoid(result);
  }

  Future<void> sendEmailVerification() async {
    final result = await _useCase.sendEmailVerification();
    await _resolveVoid(result);
  }

  Future<void> reloadCurrentUser() async {
    final result = await _useCase.reloadCurrentUser();
    await _resolveVoid(result);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await ensureMigrationSliceInitialized();
    final result = await _useCase.sendPasswordResetEmail(email);
    await _resolveVoid(result);
  }

  Future<UserProfileEntity?> getUserProfile(String userId) async {
    final result = await _useCase.getUserProfile(userId);
    return _resolveValue(result);
  }

  Future<bool> isProfileComplete(String userId) async {
    final result = await _useCase.isProfileComplete(userId);
    return _resolveValue(result);
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
    final result = await _useCase.createUserProfile(
      userId: userId,
      displayName: displayName,
      workoutPreference: workoutPreference,
      beginnerFlag: beginnerFlag,
      photoUrl: photoUrl,
      avatarConfig: avatarConfig,
      authProvider: authProvider,
      trainingDaysPerWeek: trainingDaysPerWeek,
    );
    await _resolveVoid(result);
  }

  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final result = await _useCase.updateUserProfile(userId: userId, data: data);
    await _resolveVoid(result);
  }

  Future<void> reauthenticate(String password) async {
    final result = await _useCase.reauthenticate(password);
    await _resolveVoid(result);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await _useCase.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _resolveVoid(result);
  }

  Future<void> changeEmail({
    required String password,
    required String newEmail,
  }) async {
    final result = await _useCase.changeEmail(
      password: password,
      newEmail: newEmail,
    );
    await _resolveVoid(result);
  }

  Future<void> deleteAccount(String password) async {
    final result = await _useCase.deleteAccount(password);
    await _resolveVoid(result);
  }

  Future<AuthUserEntity?> getCurrentUser() async {
    return _useCase.getCurrentUser();
  }

  Future<MigrationSlice> ensureMigrationSliceInitialized() {
    return _migrationRepository.getOrCreateAuthSlice();
  }

  Future<ValidationGateAssessment> getMigrationReadiness() async {
    final slice = await ensureMigrationSliceInitialized();
    final reports = await _migrationRepository.getValidationReports(
      slice.sliceId,
    );
    final telemetryBaseline = await _migrationRepository.getTelemetryBaseline(
      slice.sliceId,
    );
    final hasOpenRollback = await _migrationRepository.hasOpenRollbackEvent(
      slice.sliceId,
    );

    return _validationEvidenceService.assess(
      reports: reports,
      telemetryBaselineActive: telemetryBaseline?.active ?? false,
      rollbackReadinessConfirmed: reports.any(
        (report) =>
            report.reportType == ValidationReportType.cutoverReadiness &&
            report.passes(),
      ),
      unresolvedCriticalDefects: hasOpenRollback ? 1 : 0,
    );
  }

  Future<bool> canRequestCutover() async {
    final slice = await ensureMigrationSliceInitialized();
    if (slice.state != MigrationState.validationComplete) {
      return false;
    }

    final readiness = await getMigrationReadiness();
    return readiness.readyForCutover;
  }

  Future<CutoverDecision> requestCutover({
    required String requestedBy,
    required String changeReference,
  }) async {
    final slice = await ensureMigrationSliceInitialized();
    return _migrationRepository.requestCutover(
      sliceId: slice.sliceId,
      requestedBy: requestedBy,
      changeReference: changeReference,
    );
  }

  Future<bool> isRollbackActive() async {
    final slice = await ensureMigrationSliceInitialized();
    return _migrationRepository.hasOpenRollbackEvent(slice.sliceId);
  }

  Future<void> handleRollbackTrigger({
    required AuthFailure failure,
    required double successRatePercent,
    required double errorRatePercent,
  }) async {
    final slice = await ensureMigrationSliceInitialized();
    final baseline = await _migrationRepository.getTelemetryBaseline(
      slice.sliceId,
    );
    if (baseline == null) return;

    final category = _domainFailureCategoryMapper.mapAuthFailure(failure);
    final evaluation = _telemetryBaselineService.evaluateRollbackTrigger(
      baseline: baseline,
      successRatePercent: successRatePercent,
      errorRatePercent: errorRatePercent,
      failureCategory: category,
    );

    if (!evaluation.shouldTriggerRollback) {
      return;
    }

    await _migrationRepository.addRollbackEvent(
      sliceId: slice.sliceId,
      triggerFailureCode: evaluation.triggerFailureCode,
      actionSummary: 'Rollback trigger detected: ${evaluation.reason}',
    );
  }

  Future<T> _resolveValue<T>(Result<T, AuthFailure> result) async {
    if (result.isSuccess) {
      return result.valueOrNull as T;
    }

    final failure = result.errorOrNull ?? AuthFailure.unknown();
    await _evaluateRollbackTriggerForFailure(failure);
    throw _toException(failure);
  }

  Future<void> _resolveVoid(Result<void, AuthFailure> result) async {
    if (result.isSuccess) return;

    final failure = result.errorOrNull ?? AuthFailure.unknown();
    await _evaluateRollbackTriggerForFailure(failure);
    throw _toException(failure);
  }

  Future<void> _evaluateRollbackTriggerForFailure(AuthFailure failure) async {
    final slice = await ensureMigrationSliceInitialized();
    final baseline = await _migrationRepository.getTelemetryBaseline(
      slice.sliceId,
    );
    if (baseline == null) return;

    final category = _domainFailureCategoryMapper.mapAuthFailure(failure);
    final evaluation = _telemetryBaselineService.evaluateRollbackTrigger(
      baseline: baseline,
      successRatePercent: 95,
      errorRatePercent: 5,
      failureCategory: category,
    );

    if (!evaluation.shouldTriggerRollback) return;

    await _migrationRepository.addRollbackEvent(
      sliceId: slice.sliceId,
      triggerFailureCode: evaluation.triggerFailureCode,
      actionSummary:
          'Auth failure auto-triggered rollback guard: ${evaluation.reason}',
    );
  }

  AuthFlowException _toException(AuthFailure failure) {
    final category = _domainFailureCategoryMapper.mapAuthFailure(failure);
    final message = category.categoryName == 'UNKNOWN_FAILURE'
        ? failure.message
        : category.userMessage;
    return AuthFlowException(message: message, code: category.failureCode);
  }
}

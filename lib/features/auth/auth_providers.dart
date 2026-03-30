import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/migration/migration.dart';
import '../../services/notification_service.dart';
import 'data/datasources/auth_local_data_source.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/entities/auth_user_entity.dart';
import 'domain/entities/user_profile_entity.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/authentication_usecase.dart';

final authFirebaseProvider = Provider<fb.FirebaseAuth>((ref) {
  return fb.FirebaseAuth.instance;
});

final authFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(
    auth: ref.watch(authFirebaseProvider),
    firestore: ref.watch(authFirestoreProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return const AuthLocalDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

final migrationTransitionGuardProvider = Provider<MigrationTransitionGuard>((
  ref,
) {
  return const MigrationTransitionGuard();
});

final migrationEvidencePolicyProvider = Provider<MigrationEvidencePolicy>((ref) {
  return const MigrationEvidencePolicy();
});

final migrationStateMachineProvider = Provider<MigrationStateMachine>((ref) {
  return MigrationStateMachine(ref.watch(migrationTransitionGuardProvider));
});

final validationEvidenceServiceProvider = Provider<ValidationEvidenceService>((
  ref,
) {
  return ValidationEvidenceService(ref.watch(migrationEvidencePolicyProvider));
});

final migrationGovernanceRepositoryProvider = Provider<MigrationGovernanceRepository>(
  (ref) {
    return MigrationGovernanceRepository(
      stateMachine: ref.watch(migrationStateMachineProvider),
      validationEvidenceService: ref.watch(validationEvidenceServiceProvider),
    );
  },
);

final migrationBacklogServiceProvider = Provider<MigrationBacklogService>((ref) {
  return MigrationBacklogService(ref.watch(migrationGovernanceRepositoryProvider));
});

final featureBlueprintValidatorProvider = Provider<FeatureBlueprintValidator>((
  ref,
) {
  return const FeatureBlueprintValidator();
});

final domainFailureCategoryMapperProvider = Provider<DomainFailureCategoryMapper>(
  (ref) {
    return const DomainFailureCategoryMapper();
  },
);

final telemetryBaselineServiceProvider = Provider<TelemetryBaselineService>((ref) {
  return TelemetryBaselineService(ref.watch(migrationEvidencePolicyProvider));
});

final authMigrationSliceProvider = FutureProvider<MigrationSlice>((ref) async {
  return ref.read(migrationGovernanceRepositoryProvider).getOrCreateAuthSlice();
});

final authMigrationRollbackActiveProvider = FutureProvider<bool>((ref) async {
  final repository = ref.read(migrationGovernanceRepositoryProvider);
  final slice = await repository.getOrCreateAuthSlice();
  return repository.hasOpenRollbackEvent(slice.sliceId);
});

final authenticationUseCaseProvider = Provider<AuthenticationUseCase>((ref) {
  return AuthenticationUseCase(ref.watch(authRepositoryProvider));
});

/// Domain-authenticated session state for migrated auth flows.
final authSessionProvider = StreamProvider<AuthUserEntity?>((ref) {
  return ref.watch(authenticationUseCaseProvider).observeAuthState();
});

/// Profile completion state used by routing decisions.
final authProfileCompletionProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.valueOrNull?.id;
  if (uid == null) return false;

  final result = await ref
      .read(authenticationUseCaseProvider)
      .isProfileComplete(uid);

  return result.when(
    success: (isComplete) => isComplete,
    failure: (_) => false,
  );
});

/// Current authenticated user's profile in domain form.
final authUserProfileProvider = FutureProvider<UserProfileEntity?>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.valueOrNull?.id;
  if (uid == null) return null;

  final result = await ref.read(authenticationUseCaseProvider).getUserProfile(
    uid,
  );
  return result.when(
    success: (profile) => profile,
    failure: (_) => null,
  );
});

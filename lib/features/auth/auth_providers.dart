import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
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

/// Narrow watch of the signed-in uid only (Z-CODE-001 / Riverpod.select).
/// Prefer this over `ref.watch(authSessionProvider).value?.id` in build methods
/// so AsyncValue loading/error transitions that keep the same id do not rebuild.
final authCurrentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(
    authSessionProvider.select((async) => async.asData?.value?.id),
  );
});

/// Profile completion state used by routing decisions.
final authProfileCompletionProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(authCurrentUserIdProvider);
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
  final uid = ref.watch(authCurrentUserIdProvider);
  if (uid == null) return null;

  final result = await ref.read(authenticationUseCaseProvider).getUserProfile(
    uid,
  );
  return result.when(
    success: (profile) => profile,
    failure: (_) => null,
  );
});

/// The current user's chosen accent color (stored in their profile as an
/// ARGB/RGB hex string). Defaults to brand signal orange when absent.
/// Drives [AppColors.userAccent] for avatars and gym type colour.
final accentColorProvider = Provider<Color>((ref) {
  final profile = ref.watch(authUserProfileProvider).value;
  return _parseAccent(profile?.avatarConfig) ?? AppColors.accentLime;
});

Color? _parseAccent(String? config) {
  if (config == null || config.isEmpty) return null;
  final hex = config.replaceFirst('#', '').trim();
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(hex.length <= 6 ? (0xFF000000 | value) : value);
}

/// Waits for Firebase to resolve persisted auth, then checks whether a restored
/// session belongs to a user who completed onboarding. Null means signed out.
final authStartupProfileCompletionProvider = FutureProvider<bool?>((ref) async {
  final user = await ref.watch(authSessionProvider.future);
  final uid = user?.id;
  if (uid == null) return null;

  final result = await ref
      .read(authenticationUseCaseProvider)
      .isProfileComplete(uid);
  return result.when(
    success: (isComplete) => isComplete,
    failure: (failure) => throw StateError(failure.toString()),
  );
});

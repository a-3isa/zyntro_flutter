import '../../../features/auth/domain/failures/auth_failure.dart';
import '../models/domain_failure_category.dart';
import '../models/migration_lifecycle.dart';

class DomainFailureCategoryMapper {
  const DomainFailureCategoryMapper();

  DomainFailureCategory mapAuthFailure(AuthFailure failure) {
    return _mapByCode(
      failure.code,
      fallbackMessage: failure.message,
    );
  }

  DomainFailureCategory mapError(Object error) {
    if (error is AuthFailure) {
      return mapAuthFailure(error);
    }

    return _mapByCode(
      null,
      fallbackMessage: 'Authentication request failed. Please try again.',
    );
  }

  DomainFailureCategory _mapByCode(
    String? code, {
    required String fallbackMessage,
  }) {
    final normalizedCode = code?.trim().toLowerCase();

    if (normalizedCode == null || normalizedCode.isEmpty) {
      return DomainFailureCategory(
        failureCode: 'unknown-error',
        categoryName: 'UNKNOWN_FAILURE',
        userMessage: fallbackMessage,
        severity: FailureSeverity.medium,
        rollbackTrigger: false,
      );
    }

    if (<String>{'invalid-email', 'invalid-password', 'weak-password'}
        .contains(normalizedCode)) {
      return const DomainFailureCategory(
        failureCode: 'validation-input',
        categoryName: 'INPUT_VALIDATION',
        userMessage: 'Please review your input and try again.',
        severity: FailureSeverity.low,
        rollbackTrigger: false,
      );
    }

    if (<String>{'invalid-credential', 'user-not-found', 'wrong-password'}
        .contains(normalizedCode)) {
      return const DomainFailureCategory(
        failureCode: 'auth-credentials',
        categoryName: 'AUTHENTICATION',
        userMessage: 'Your credentials were not accepted. Please try again.',
        severity: FailureSeverity.medium,
        rollbackTrigger: false,
      );
    }

    if (<String>{'permission-denied', 'unauthorized', 'forbidden'}
        .contains(normalizedCode)) {
      return const DomainFailureCategory(
        failureCode: 'authorization',
        categoryName: 'AUTHORIZATION',
        userMessage: 'You do not have permission for this action.',
        severity: FailureSeverity.high,
        rollbackTrigger: true,
      );
    }

    if (<String>{'session-expired', 'session-invalid'}
        .contains(normalizedCode)) {
      return const DomainFailureCategory(
        failureCode: 'session-handling',
        categoryName: 'SESSION',
        userMessage: 'Your session expired. Please sign in again.',
        severity: FailureSeverity.high,
        rollbackTrigger: true,
      );
    }

    if (<String>{'network-request-failed', 'network_error', 'timeout'}
        .contains(normalizedCode)) {
      return const DomainFailureCategory(
        failureCode: 'dependency-network',
        categoryName: 'EXTERNAL_DEPENDENCY',
        userMessage:
            'Network issues are preventing sign-in. Check connection and retry.',
        severity: FailureSeverity.medium,
        rollbackTrigger: false,
      );
    }

    if (normalizedCode == 'too-many-requests') {
      return const DomainFailureCategory(
        failureCode: 'rate-limited',
        categoryName: 'RATE_LIMIT',
        userMessage: 'Too many attempts. Please wait before trying again.',
        severity: FailureSeverity.medium,
        rollbackTrigger: false,
      );
    }

    return DomainFailureCategory(
      failureCode: normalizedCode,
      categoryName: 'UNKNOWN_FAILURE',
      userMessage: fallbackMessage,
      severity: FailureSeverity.medium,
      rollbackTrigger: false,
    );
  }
}

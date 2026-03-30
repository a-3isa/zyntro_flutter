import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';
import 'package:zyntro_flutter/features/auth/domain/failures/auth_failure.dart';

void main() {
  const mapper = DomainFailureCategoryMapper();

  test('maps validation failures to INPUT_VALIDATION', () {
    const failure = AuthFailure(
      message: 'Invalid email address.',
      code: 'invalid-email',
    );

    final category = mapper.mapAuthFailure(failure);
    expect(category.categoryName, 'INPUT_VALIDATION');
    expect(category.rollbackTrigger, isFalse);
  });

  test('maps authorization failures to rollback-triggering category', () {
    const failure = AuthFailure(
      message: 'Permission denied.',
      code: 'permission-denied',
    );

    final category = mapper.mapAuthFailure(failure);
    expect(category.categoryName, 'AUTHORIZATION');
    expect(category.rollbackTrigger, isTrue);
  });

  test('falls back to unknown failure category for unmapped codes', () {
    const failure = AuthFailure(
      message: 'Unexpected issue.',
      code: 'mystery-error',
    );

    final category = mapper.mapAuthFailure(failure);
    expect(category.categoryName, 'UNKNOWN_FAILURE');
    expect(category.failureCode, 'mystery-error');
  });
}

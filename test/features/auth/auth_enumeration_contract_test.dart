import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth mapper collapses user-not-found into invalid-credential copy', () {
    final source = File(
      'lib/features/auth/data/datasources/auth_remote_data_source.dart',
    ).readAsStringSync();
    expect(source, contains("case 'user-not-found':"));
    final idx = source.indexOf("case 'wrong-password':");
    expect(idx, isNonNegative);
    final snippet = source.substring(idx, idx + 450);
    expect(snippet, contains("case 'user-not-found':"));
    expect(
      snippet,
      contains('Invalid email or password. Please try again.'),
    );
    expect(snippet, isNot(contains('No account found')));
  });

  test('password reset swallows missing-user errors', () {
    final source = File(
      'lib/features/auth/data/datasources/auth_remote_data_source.dart',
    ).readAsStringSync();
    final idx = source.indexOf('Future<void> sendPasswordResetEmail');
    final body = source.substring(idx, idx + 500);
    expect(body, contains("e.code == 'user-not-found'"));
    expect(body, contains('return;'));
  });
}

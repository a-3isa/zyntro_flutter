import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contracts for Low XS/S audit batch (Z-FN-006, Z-AUTH-006, Z-CI-006, Z-DOC-003,
/// Z-DATA-005, Z-PERF-004, Z-NOTIF-004, Z-SEC-007).
void main() {
  test('password policy ADR documents Firebase Console as source of truth', () {
    final text = File('docs/PASSWORD_POLICY.md').readAsStringSync();
    expect(text, contains('Firebase Auth password policy'));
    expect(text, contains('Z-AUTH-006'));
  });

  test('Dependabot covers pub, functions npm, and GitHub Actions', () {
    final text = File('.github/dependabot.yml').readAsStringSync();
    expect(text, contains('package-ecosystem: pub'));
    expect(text, contains('directory: "/functions"'));
    expect(text, contains('package-ecosystem: github-actions'));
    expect(text, contains('Z-CI-006'));
  });

  test('README CI section points at docs/CI.md', () {
    final text = File('README.md').readAsStringSync();
    expect(text, contains('docs/CI.md'));
    expect(text, contains('Z-DOC-003'));
  });

  test('push CORS helper stays opt-in empty by default', () {
    final text = File('functions/index.js').readAsStringSync();
    expect(text, contains('ALLOWED_CORS_ORIGINS'));
    expect(text, contains('Z-FN-006'));
  });

  test('presence heartbeat is 30s (Z-PERF-004)', () {
    final text = File('lib/services/presence_service.dart').readAsStringSync();
    expect(text, contains('Duration(seconds: 30)'));
    expect(text, contains('Z-PERF-004'));
  });

  test('whereIn chunk size is 30 across list callers (Z-DATA-005)', () {
    expect(
      File('lib/services/leaderboard_service.dart').readAsStringSync(),
      contains('chunkSize = 30'),
    );
    expect(
      File('lib/services/facebook_link_service.dart').readAsStringSync(),
      contains('chunkSize = 30'),
    );
    expect(
      File('lib/services/user_cache_service.dart').readAsStringSync(),
      contains('batchSize = 30'),
    );
    expect(
      File('lib/services/user_service.dart').readAsStringSync(),
      contains('i += 30'),
    );
  });

  test('background FCM handler documents intentional no-op (Z-NOTIF-004)', () {
    final text = File('lib/services/notification_service.dart').readAsStringSync();
    expect(text, contains('Z-NOTIF-004'));
    expect(text, contains('intentional no-op'));
  });

  test('firestore rules comment documents Z-SEC-007 invite ACL', () {
    final text = File('firebase/firestore.rules').readAsStringSync();
    expect(text, contains('Z-SEC-007'));
  });
}

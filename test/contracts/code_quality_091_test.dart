import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authCurrentUserIdProvider uses Riverpod.select (Z-CODE-001)', () {
    final text = File('lib/features/auth/auth_providers.dart').readAsStringSync();
    expect(text, contains('authCurrentUserIdProvider'));
    expect(text, contains('authSessionProvider.select'));
  });

  test('FollowService exposes Result-based tryFollowUser', () {
    final text = File('lib/services/follow_service.dart').readAsStringSync();
    expect(text, contains('tryFollowUser'));
    expect(text, contains('Result<FollowStatus, String>'));
  });

  test('hot screens watch authCurrentUserIdProvider', () {
    for (final path in [
      'lib/features/social/presentation/social_page.dart',
      'lib/features/feed/presentation/feed_page.dart',
      'lib/features/session/presentation/session_room_page.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('authCurrentUserIdProvider'),
        reason: path,
      );
    }
  });

  test('CODE_QUALITY ADR and unawaited_futures lint exist', () {
    expect(File('docs/CODE_QUALITY.md').readAsStringSync(), contains('Z-CODE-001'));
    expect(
      File('analysis_options.yaml').readAsStringSync(),
      contains('unawaited_futures: true'),
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile and follow counts are backed by Firestore streams', () {
    final profile = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();
    final follows = File('lib/services/follow_service.dart').readAsStringSync();

    expect(profile, contains('StreamProvider.autoDispose.family<User?, String>'));
    expect(profile, contains('StreamProvider.autoDispose.family<int, String>'));
    expect(follows, contains('Stream<int> watchFollowersCount'));
    expect(follows, contains('Stream<int> watchFollowingCount'));
    expect(follows, contains('Stream<FollowStatus?> watchFollowStatus'));
    expect(profile, contains('watchUserSessions(userId, limit: 100)'));
  });

  test('every profile stream provider auto-disposes', () {
    final profile = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();

    // Each of these holds a live Firestore listener keyed by user id. Without
    // autoDispose, visiting N profiles leaves 5N listeners running for the rest
    // of the app session, each still billing for writes to what it watched.
    final plainStreamProviders = RegExp(
      r'StreamProvider(?!\.autoDispose)[.<]',
    ).allMatches(profile);

    expect(
      plainStreamProviders,
      isEmpty,
      reason:
          'found ${plainStreamProviders.length} profile StreamProvider(s) '
          'without autoDispose',
    );
  });

  test('visitor profile uses the social-first follow-back layout', () {
    final source = File(
      'lib/features/profile/presentation/profile_page.dart',
    ).readAsStringSync();

    expect(source, contains("'Follow back'"));
    expect(source, contains('decoration: TextDecoration.none'));
    expect(source, contains('borderRadius: BorderRadius.circular(18)'));
  });
}

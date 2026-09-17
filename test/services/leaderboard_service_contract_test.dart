import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leaderboard joins use a batch for joinedEvents and participantCount', () {
    final source = File('lib/services/leaderboard_service.dart').readAsStringSync();

    expect(source, contains('final batch = _firestore.batch();'));
    expect(source, contains('batch.set('));
    expect(source, contains('batch.update('));
  });

  test('friends leaderboard reads user streak docs in parallel', () {
    final source = File('lib/services/leaderboard_service.dart').readAsStringSync();

    final method = source.substring(
      source.indexOf('Future<List<LeaderboardEntry>> getFriendsLeaderboard'),
      source.indexOf('/// Get global leaderboard'),
    );

    expect(method, contains('Future.wait('));
    expect(method, contains('_buildFriendLeaderboardEntry('));
  });

  test('leaderboards exclude blocked users (Z-SOC-003)', () {
    final source = File('lib/services/leaderboard_service.dart').readAsStringSync();
    expect(source, contains('excludedUserIds'));
    expect(source, contains('blockedUserIdsProvider'));
    expect(source, contains('Z-SOC-003'));
  });
}

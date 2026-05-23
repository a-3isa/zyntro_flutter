import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firestore rules contracts', () {
    late String rules;

    setUpAll(() {
      rules = File('firebase/firestore.rules').readAsStringSync();
    });

    test('define owner-scoped user subcollections used by the app', () {
      expect(rules, contains('match /devices/{deviceId}'));
      expect(rules, contains('match /settings/{settingId}'));
      expect(rules, contains('match /notifications/{notificationId}'));
    });

    test('define session event, plan, and presence subcollection rules', () {
      expect(rules, contains('match /events/{eventId}'));
      expect(rules, contains('match /plans/{planUserId}'));
      expect(rules, contains('match /presence/{presenceUserId}'));
    });

    test('define invite code rules for buddy onboarding flow', () {
      expect(rules, contains('match /inviteCodes/{inviteCode}'));
    });

    test('require joined-event writes before leaderboard counts change', () {
      expect(
        rules,
        contains(
          r'getAfter(/databases/$(database)/documents/users/$(request.auth.uid)/joinedEvents/$(eventId))',
        ),
      );
    });

    test('deny direct client writes to the push queue', () {
      expect(rules, contains('match /pushQueue/{messageId}'));
      expect(rules, contains('allow read, create, update, delete: if false;'));
    });

    test('protect privileged user fields from owner writes', () {
      expect(rules, contains('privilegedUserFields()'));
      expect(rules, contains('isPrivilegedUserCreate()'));
      expect(rules, contains('isPrivilegedUserFieldChange()'));
      expect(rules, contains('hasGlobalLeaderboardAccess'));
      expect(rules, contains('isModerator'));
    });

    test('restrict cross-user notification creation to the owner', () {
      expect(
        rules,
        contains(
          'allow create: if isOwner(userId) && request.resource.data.userId == userId;',
        ),
      );
    });

    test('prevents followers from self-approving follow requests', () {
      expect(rules, contains('isFollowStatusChange()'));
      expect(
        rules,
        contains(
          'resource.data.followerId == request.auth.uid && !isFollowStatusChange()',
        ),
      );
    });
  });
}

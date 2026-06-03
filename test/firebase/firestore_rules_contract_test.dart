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

    test('paired session rules expose plan ownership and invite checks', () {
      expect(rules, contains('match /plans/{planUserId}'));
      expect(rules, contains('planUserId == request.auth.uid'));
      expect(rules, contains('invitedUserIds'));
      expect(rules, contains('participants'));
      expect(rules, contains('isMutualApprovedFollow'));
      expect(rules, contains('isNotBlockedPair'));
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

    test('allows bot-session hosts to write bot plans and bot events', () {
      expect(rules, contains('isBotSessionHost(sessionId)'));
      expect(rules, contains("planUserId == 'zyntro_bot_friend'"));
      expect(
        rules,
        contains("request.resource.data.userId == 'zyntro_bot_friend'"),
      );
    });

    // -------------------------------------------------------------------------
    // Exercise catalog rules (T013, T015)
    // -------------------------------------------------------------------------
    group('exercise catalog rules', () {
      test('define exerciseCatalog collection with isActive read guard', () {
        expect(rules, contains('match /exerciseCatalog/{exerciseId}'));
        expect(rules, contains('resource.data.isActive == true'));
      });

      test('catalog collection allow-read requires isAuthenticated', () {
        expect(rules, contains('match /exerciseCatalog/{exerciseId}'));
        expect(rules, contains('isAuthenticated()'));
      });

      test('catalog write is restricted to isModerator', () {
        expect(rules, contains('match /exerciseCatalog/{exerciseId}'));
        // isModerator() is present and gates the catalog write rule
        final catalogIdx = rules.indexOf('match /exerciseCatalog/{exerciseId}');
        expect(catalogIdx, isNonNegative);
        final afterCatalog = rules.substring(catalogIdx);
        expect(afterCatalog, contains('isModerator()'));
      });
    });

    // -------------------------------------------------------------------------
    // Personal exercise rules (T013, T015)
    // -------------------------------------------------------------------------
    group('personal exercise rules', () {
      test('define personalExercises subcollection scoped to user owner', () {
        expect(
          rules,
          contains(
              'match /users/{userId}/personalExercises/{personalExerciseId}'),
        );
      });

      test('personal exercises are guarded by isOwner(userId)', () {
        final idx = rules.indexOf(
            'match /users/{userId}/personalExercises/{personalExerciseId}');
        expect(idx, isNonNegative);
        expect(rules.substring(idx), contains('isOwner(userId)'));
      });
    });

    // -------------------------------------------------------------------------
    // Review submission rules (T013, T015)
    // -------------------------------------------------------------------------
    group('review submission rules', () {
      test('define exerciseReviewSubmissions collection', () {
        expect(
          rules,
          contains('match /exerciseReviewSubmissions/{submissionId}'),
        );
      });

      test('review submission create requires submittedBy == auth.uid', () {
        final idx =
            rules.indexOf('match /exerciseReviewSubmissions/{submissionId}');
        expect(idx, isNonNegative);
        expect(
          rules.substring(idx),
          contains('request.resource.data.submittedBy == request.auth.uid'),
        );
      });

      test('review submission update is restricted to isModerator', () {
        final idx =
            rules.indexOf('match /exerciseReviewSubmissions/{submissionId}');
        expect(idx, isNonNegative);
        expect(rules.substring(idx), contains('isModerator()'));
      });

      test('review submission delete is denied', () {
        final idx =
            rules.indexOf('match /exerciseReviewSubmissions/{submissionId}');
        expect(idx, isNonNegative);
        expect(
          rules.substring(idx),
          contains('allow delete: if false'),
        );
      });
    });
  });
}

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

    test('pending invitees can read only the session that names them', () {
      expect(rules, contains('isPendingSessionInvitee'));
      expect(
        rules,
        contains(
          'hasParticipant(resource.data.participants, request.auth.uid) ||\n        isPendingSessionInvitee(resource.data, request.auth.uid)',
        ),
      );
      expect(rules, contains('isPendingSessionInviteeById'));
    });

    test('define invite code rules for buddy onboarding flow', () {
      expect(rules, contains('match /inviteCodes/{inviteCode}'));
    });

    test('invite codes are redeemable by code but not listable', () {
      final idx = rules.indexOf('match /inviteCodes/{inviteCode}');
      expect(idx, isNonNegative);
      final section = rules.substring(
        idx,
        rules.indexOf('match /events/{eventId}', idx),
      );

      expect(section, contains('allow get: if isAuthenticated();'));
      expect(section, contains('allow list: if false;'));
      expect(section, contains('isBuddyInviteCodeRedeemUpdate()'));
      expect(
        rules,
        contains('request.resource.data.usedBy == request.auth.uid'),
      );
      expect(rules, contains('resource.data.expiresAt > request.time'));
    });

    test('buddy pair invite accept cannot add caller without redeemed code', () {
      final idx = rules.indexOf('match /buddyPairs/{pairId}');
      expect(idx, isNonNegative);
      final section = rules.substring(
        idx,
        rules.indexOf('match /inviteCodes/{inviteCode}', idx),
      );

      expect(section, contains('isBuddyPairInviteAcceptUpdate()'));
      expect(
        rules,
        contains(
          '!hasParticipant(resource.data.participants, request.auth.uid)',
        ),
      );
      expect(
        rules,
        contains(
          'request.resource.data.participants.hasAll(resource.data.participants)',
        ),
      );
      expect(
        rules,
        contains(
          r'getAfter(/databases/$(database)/documents/inviteCodes/$(resource.data.inviteCode)).data.usedBy == request.auth.uid',
        ),
      );
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
      expect(rules, contains('globalAccessGrantedAt'));
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

    test('allow authenticated clients to create bounded analytics events', () {
      expect(rules, contains('match /analytics/{eventId}'));
      expect(rules, contains('function isAnalyticsEventCreate()'));
      expect(
        rules,
        contains(
          "request.resource.data.diff({}).affectedKeys().hasOnly(['type', 'timestamp', 'userId', 'sessionId', 'hostId', 'partnerId', 'partnerKind', 'mode', 'workoutType', 'postId', 'originalSizeBytes', 'uploadDurationMs', 'finalSizeBytes', 'wasCompressed', 'compressionReductionPercent', 'errorType', 'errorMessage', 'attemptNumber', 'compressedSizeBytes', 'sizeReductionPercent', 'originalDimensions', 'planUserId', 'source', 'isReady', 'waitingOnPlan'])",
        ),
      );
      expect(
        rules,
        contains(
          "(!request.resource.data.keys().hasAny(['userId']) || request.resource.data.userId == request.auth.uid)",
        ),
      );
      expect(
        rules,
        contains(
          "(!request.resource.data.keys().hasAny(['hostId', 'partnerId']) || request.auth.uid in [request.resource.data.hostId, request.resource.data.partnerId])",
        ),
      );
    });

    test('post comments and reactions bind created identity to auth user', () {
      expect(
        rules,
        contains('request.resource.data.authorId == request.auth.uid'),
      );
      expect(rules, contains('reactionId == request.auth.uid'));
    });

    test('posts rules gate joint draft create + own-slot-only update + no client publish', () {
      expect(rules, contains('isJointDraftCreate()'));
      expect(rules, contains('isOwnAuthorSlotUpdate()'));
      // client can never set status on a coAuthored post:
      expect(
        rules,
        contains(
          "!request.resource.data.diff(resource.data).affectedKeys().hasAny(['status'])",
        ),
      );
    });

    test('joint draft create requires size-2 authorIds and matching authors keys', () {
      final idx = rules.indexOf('match /posts/{postId}');
      expect(idx, isNonNegative);
      final section = rules.substring(idx, rules.indexOf('match /follows/{followId}'));
      expect(section, contains("request.resource.data.status == 'draft'"));
      expect(section, contains('request.resource.data.authorIds.size() == 2'));
      expect(
        section,
        contains(
          'request.resource.data.authors.keys().hasAll(request.resource.data.authorIds)',
        ),
      );
      expect(
        section,
        contains(
          'request.resource.data.authorIds.hasAll(request.resource.data.authors.keys())',
        ),
      );
    });

    test('joint author slot update only touches caller own authors entry and freezes identity fields', () {
      final idx = rules.indexOf('match /posts/{postId}');
      expect(idx, isNonNegative);
      final section = rules.substring(idx, rules.indexOf('match /follows/{followId}'));
      expect(
        section,
        contains(
          "return ['authorIds', 'coAuthored', 'sessionId', 'authorId'];",
        ),
      );
      expect(
        section,
        contains(
          'request.resource.data.authors.diff(resource.data.authors).affectedKeys().hasOnly([request.auth.uid])',
        ),
      );
    });

    test('solo post delete stays scoped to non-coAuthored owner posts', () {
      final idx = rules.indexOf('match /posts/{postId}');
      expect(idx, isNonNegative);
      final section = rules.substring(idx, rules.indexOf('match /follows/{followId}'));
      expect(
        section,
        contains(
          'allow delete: if isAuthenticated() && resource.data.authorId == request.auth.uid\n        && resource.data.coAuthored != true;',
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
    // Session lobby handshake hardening (Task 6)
    // -------------------------------------------------------------------------
    test('participant updates can only change their own participantTypes', () {
      expect(
        rules,
        contains(
          "request.resource.data.participantTypes.diff(resource.data.participantTypes).affectedKeys().hasOnly([request.auth.uid])",
        ),
      );
    });

    test('invite accept is scoped to an active session still in setup', () {
      final idx = rules.indexOf('function isInviteAcceptUpdate()');
      expect(idx, isNonNegative);
      final body = rules.substring(idx, idx + 800);
      expect(body, contains("resource.data.status == 'active'"));
      expect(body, contains("resource.data.phase == 'setup'"));
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
            'match /users/{userId}/personalExercises/{personalExerciseId}',
          ),
        );
      });

      test('personal exercises are guarded by isOwner(userId)', () {
        final idx = rules.indexOf(
          'match /users/{userId}/personalExercises/{personalExerciseId}',
        );
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
        final idx = rules.indexOf(
          'match /exerciseReviewSubmissions/{submissionId}',
        );
        expect(idx, isNonNegative);
        expect(
          rules.substring(idx),
          contains('request.resource.data.submittedBy == request.auth.uid'),
        );
      });

      test('review submission update is restricted to isModerator', () {
        final idx = rules.indexOf(
          'match /exerciseReviewSubmissions/{submissionId}',
        );
        expect(idx, isNonNegative);
        expect(rules.substring(idx), contains('isModerator()'));
      });

      test('review submission delete is denied', () {
        final idx = rules.indexOf(
          'match /exerciseReviewSubmissions/{submissionId}',
        );
        expect(idx, isNonNegative);
        expect(rules.substring(idx), contains('allow delete: if false'));
      });
    });
  });
}

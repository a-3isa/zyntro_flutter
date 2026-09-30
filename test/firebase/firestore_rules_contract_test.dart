import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// NOTE: these are *source-text* contracts — they prove a predicate is present
/// in firebase/firestore.rules, not that it behaves correctly at runtime. The
/// behavioral counterpart lives in `test/rules/posts_joint.rules.test.mjs`
/// (@firebase/rules-unit-testing against the Firestore emulator); run it with
/// `cd test/rules && npm install && npm test`. Any change to the co-authored
/// post rules should be covered there, not just here.
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

      expect(section, contains('isEmailVerifiedForSocial()'));
      expect(section, contains("inviteCode.matches('^[A-Z0-9]{8}\$')"));
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
      expect(rules, contains("'workoutScore'"));
      expect(rules, contains("'currentStreak'"));
    });

    test('matchmaking claimer updates require block check and allowlist', () {
      final idx = rules.indexOf('match /matchmaking_queue/{entryId}');
      expect(idx, isNonNegative);
      final section = rules.substring(idx, idx + 1800);
      expect(section, contains('isNotBlockedPair(request.auth.uid, resource.data.userId)'));
      expect(section, contains("'claimedBy'"));
      expect(section, contains("'matchedWithUserId'"));
      expect(section, contains('.hasOnly(['));
      // Z-SEC-003: claimer must stamp self; cannot hijack another claim.
      expect(
        section,
        contains('request.resource.data.claimedBy == request.auth.uid'),
      );
      expect(
        section,
        contains('resource.data.claimedBy == request.auth.uid'),
      );
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
      // The joint update branch constrains the FULL top-level diff to
      // ['authors'], which is what keeps `status` (client publish),
      // `visibility` (private-wins bypass), and the identity fields frozen.
      expect(
        rules,
        contains(
          "request.resource.data.diff(resource.data).affectedKeys().hasOnly(['authors'])",
        ),
      );
    });

    test('joint draft create requires both authors to be session participants', () {
      expect(rules, contains('function sessionHasAllParticipants(sessionId, userIds)'));
      expect(rules, contains('get(path).data.participants.hasAll(userIds)'));
      final idx = rules.indexOf('function isJointDraftCreate()');
      expect(idx, isNonNegative);
      final section = rules.substring(idx, rules.indexOf('allow create:', idx));
      expect(section, contains('request.resource.data.sessionId is string'));
      expect(section, contains('sessionHasAllParticipants('));
    });

    test('engagement counters are ±1 only for any auth user (Z-SEC-006)', () {
      expect(rules, contains('function isEngagementCounterUpdate()'));
      expect(rules, contains('function isSoloAuthorContentUpdate()'));
      expect(rules, contains('isEngagementCounterUpdate()'));
      expect(rules, isNot(contains('isJointAuthorCounterUpdate')));
      expect(
        rules,
        contains(
          "request.resource.data.likesCount == resource.data.get('likesCount', 0) + 1",
        ),
      );
    });

    test('solo update path forbids self-promotion to a coAuthored/joint post', () {
      final idx = rules.indexOf('match /posts/{postId}');
      expect(idx, isNonNegative);
      final section = rules.substring(idx, rules.indexOf('match /follows/{followId}'));
      // The new state must also stay solo, not just the old state:
      expect(section, contains('request.resource.data.coAuthored != true'));
      // authorIds/authors/authorId/coAuthored must be frozen on the solo-owner update branch:
      expect(section, contains('function isSoloAuthorContentUpdate()'));
      expect(
        section,
        contains("'likesCount'"),
      );
    });

    test('isSoloCreate forbids planting extra authorIds or an authors map at create time', () {
      final idx = rules.indexOf('match /posts/{postId}');
      expect(idx, isNonNegative);
      final section = rules.substring(idx, rules.indexOf('match /follows/{followId}'));
      expect(
        section,
        contains('request.resource.data.authorIds == [request.auth.uid]'),
      );
      expect(
        section,
        contains('request.resource.data.authors.size() == 0'),
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
      // The whole top-level diff is pinned to `authors` — enumerating frozen
      // fields was vacuously satisfiable when the real diff hit another field.
      expect(
        section,
        contains(
          "request.resource.data.diff(resource.data).affectedKeys().hasOnly(['authors'])",
        ),
      );
      expect(section, isNot(contains('frozenPostFields()')));
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
      expect(rules, contains('function canReadPostData'));
      expect(rules, contains('match /matchmaking_queue/{entryId}'));
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

    test('host-only pause/resume status transitions (Z-RT-005)', () {
      expect(rules, contains('function isHostPauseResumeUpdate()'));
      expect(rules, contains('isHostPauseResumeUpdate()'));
      expect(rules, contains("resource.data.status == 'paused'"));
      expect(rules, contains("request.resource.data.status == 'paused'"));
      expect(rules, contains("resource.data.status != 'paused'"));
      expect(rules, contains("request.resource.data.status != 'paused'"));
    });

    // -------------------------------------------------------------------------
    // Session lobby handshake hardening (Task 6)
    // -------------------------------------------------------------------------
    test('private profiles are not gettable by strangers', () {
      expect(rules, contains('function canReadUserProfile'));
      expect(
        rules,
        contains('allow get: if isAuthenticated() && canReadUserProfile(userId);'),
      );
      expect(rules, contains('function canListUserProfile'));
      expect(rules, isNot(contains('allow list: if isAuthenticated();')));
      expect(rules, contains('canListUserProfile()'));
      expect(rules, contains("request.auth.token.get('moderator', false) == true"));
    });

    test('username registry is gettable but not listable', () {
      final idx = rules.indexOf('match /usernames/{username}');
      expect(idx, isNonNegative);
      final section = rules.substring(
        idx,
        rules.indexOf('match /config/{document}', idx),
      );
      expect(section, contains('allow get: if isAuthenticated();'));
      expect(section, contains('allow list: if false;'));
    });

    test('pending follow edges are hidden from strangers', () {
      final idx = rules.indexOf('match /follows/{followId}');
      expect(idx, isNonNegative);
      final section = rules.substring(
        idx,
        rules.indexOf('match /blocks/{blockId}', idx),
      );
      expect(section, contains("resource.data.status == 'approved'"));
      expect(section, isNot(contains('allow read: if isAuthenticated();')));
    });

    test('workouts are not world-readable among authenticated users', () {
      final idx = rules.indexOf('match /workouts/{workoutId}');
      expect(idx, isNonNegative);
      final section = rules.substring(
        idx,
        rules.indexOf('match /analytics/{eventId}', idx),
      );
      expect(section, contains('isPublicProfile(resource.data.userId)'));
      expect(section, contains('isApprovedFollowerOf(resource.data.userId)'));
      expect(section, isNot(contains('allow read: if isAuthenticated();')));
    });

    test('participant session writes use an allowlist, not a field blocklist', () {
      expect(rules, contains('function participantLiveKeys'));
      expect(rules, contains('function isLastLiveMemberCompleting'));
      expect(rules, contains('function isNotBanned'));
      expect(rules, contains("request.resource.data.status != 'completed'"));
      final liveIdx = rules.indexOf('function participantLiveKeys');
      final liveBody = rules.substring(liveIdx, liveIdx + 500);
      expect(liveBody, isNot(contains("'mode'")));
    });

    test('invite accept cannot write mode', () {
      final idx = rules.indexOf('function isInviteAcceptUpdate()');
      expect(idx, isNonNegative);
      final nextFn = rules.indexOf('function activityStampKeys()', idx);
      final body = rules.substring(idx, nextFn > idx ? nextFn : idx + 2000);
      expect(
        body,
        contains(
          "['participants', 'participantTypes', 'invitationStatus'].concat(activityStampKeys())",
        ),
      );
      expect(body, isNot(contains("'mode'")));
    });

    test('participant updates can only change their own participantTypes', () {
      expect(
        rules,
        contains(
          'request.resource.data.participantTypes.diff(resource.data.participantTypes)',
        ),
      );
      expect(
        rules,
        contains('.affectedKeys().hasOnly([request.auth.uid])'),
      );
    });

    test('password social writes require email verification (Z-AUTH-002)', () {
      expect(rules, contains('function isPasswordProvider'));
      expect(rules, contains('function isEmailVerifiedForSocial'));
      expect(rules, contains('function isEmailVerifiedForInviteCreate'));
      expect(rules, contains("sign_in_provider == 'password'"));
      expect(rules, contains('isEmailVerifiedForSocial()'));
      expect(rules, contains('isEmailVerifiedForInviteCreate()'));
    });

    test('analytics and reports creates are bounded (Z-SEC-005)', () {
      expect(rules, contains('function isReportCreate()'));
      expect(rules, contains('allow create: if isReportCreate()'));
      expect(
        rules,
        contains("request.resource.data.type.matches('^[a-z0-9_]+\$')"),
      );
      expect(
        rules,
        contains(
          "request.resource.data.reason in ['spam', 'harassment', 'inappropriate', 'other']",
        ),
      );
    });

    test('rateLimits collection is client-inaccessible (Z-FN-001)', () {
      expect(rules, contains('match /rateLimits/{docId}'));
      expect(rules, contains('allow read, write: if false'));
      final idx = rules.indexOf('match /rateLimits/{docId}');
      expect(idx, isNonNegative);
      final section = rules.substring(idx);
      expect(section, contains('allow read, write: if false'));
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

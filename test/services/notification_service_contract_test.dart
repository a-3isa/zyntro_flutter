import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/services/notification_service.dart';

void main() {
  group('NotificationTypeExtension', () {
    test('round-trips every supported notification type', () {
      const cases = <NotificationType, String>{
        NotificationType.sessionInvite: 'session_invite',
        NotificationType.voiceNote: 'voice_note',
        NotificationType.newFollower: 'new_follower',
        NotificationType.followRequest: 'follow_request',
        NotificationType.followAccepted: 'follow_accepted',
        NotificationType.buddyInvite: 'buddy_invite',
        NotificationType.buddyAccepted: 'buddy_accepted',
        NotificationType.buddySession: 'buddy_session',
        NotificationType.postLike: 'post_like',
        NotificationType.postComment: 'post_comment',
        NotificationType.sessionMilestone: 'session_milestone',
        NotificationType.streakMilestone: 'streak_milestone',
        NotificationType.friendStreakBroken: 'friend_streak_broken',
        NotificationType.friendStreakExtended: 'friend_streak_extended',
        NotificationType.turnChange: 'turn_change',
        NotificationType.jointPostInvite: 'joint_post_invite',
        NotificationType.jointPostExpired: 'joint_post_expired',
      };

      for (final entry in cases.entries) {
        expect(entry.key.value, entry.value);
        expect(NotificationTypeExtension.fromString(entry.value), entry.key);
      }
    });

    test('maps unsupported strings to unknown instead of session invites', () {
      expect(
        NotificationTypeExtension.fromString('unsupported_event'),
        NotificationType.unknown,
      );
    });

    test('joint-post invite and expiry types round-trip in snake_case', () {
      // joint_post_expired is written server-side by
      // expireStaleJointPostDrafts (functions/index.js) — the client must
      // parse that exact snake_case string, not a camelCase variant.
      expect(NotificationType.jointPostInvite.value, 'joint_post_invite');
      expect(
        NotificationTypeExtension.fromString('joint_post_invite'),
        NotificationType.jointPostInvite,
      );

      expect(NotificationType.jointPostExpired.value, 'joint_post_expired');
      expect(
        NotificationTypeExtension.fromString('joint_post_expired'),
        NotificationType.jointPostExpired,
      );
    });
  });

  group('NotificationPreferences', () {
    test('defaults opt into the supported notification channels', () {
      const prefs = NotificationPreferences.defaults;

      expect(prefs.pushEnabled, isTrue);
      expect(prefs.sessionInvites, isTrue);
      expect(prefs.voiceNotes, isTrue);
      expect(prefs.followRequests, isTrue);
      expect(prefs.followAccepted, isTrue);
      expect(prefs.buddyInvites, isTrue);
      expect(prefs.postLikes, isTrue);
      expect(prefs.postComments, isTrue);
      expect(prefs.sessionMilestones, isTrue);
      expect(prefs.streakNotifications, isTrue);
    });

    test('serializes and deserializes consistently', () {
      final prefs = const NotificationPreferences(
        sessionInvites: false,
        voiceNotes: true,
        followRequests: false,
        followAccepted: true,
        buddyInvites: false,
        postLikes: true,
        postComments: false,
        sessionMilestones: true,
        streakNotifications: false,
        pushEnabled: true,
      );

      expect(
        NotificationPreferences.fromMap(prefs.toMap()).toMap(),
        prefs.toMap(),
      );
    });
  });

  group('session invite payload', () {
    test('contains one-to-one invite dialog fields', () {
      final expiresAt = DateTime(2026, 1, 1, 12, 0, 30);
      final payload = NotificationService.sessionInvitePayload(
        sessionId: 'session-1',
        hostId: 'host-1',
        hostName: 'Coach Alex',
        sessionType: 'gym',
        expiresAt: expiresAt,
      );

      expect(payload['type'], 'session_invite');
      expect(payload['sessionId'], 'session-1');
      expect(payload['hostId'], 'host-1');
      expect(payload['hostName'], 'Coach Alex');
      expect(payload['sessionType'], 'gym');
      expect(payload['expiresAt'], expiresAt.toIso8601String());
      expect(payload['context'], 'one_to_one');
    });
  });
}

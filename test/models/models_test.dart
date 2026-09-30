/// Deep unit tests for core models and data validation.
/// Tests data structures, serialization, and business logic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/models/models.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';

void main() {
  group('User Model Tests', () {
    test('User model creates with required fields', () {
      final user = User(
        id: 'test-user-id',
        displayName: 'Test User',
        isPrivate: false,
        workoutPreference: WorkoutType.gym,
        beginnerFlag: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(user.id, 'test-user-id');
      expect(user.displayName, 'Test User');
      expect(user.isPrivate, false);
      expect(user.workoutPreference, WorkoutType.gym);
      expect(user.beginnerFlag, true);
    });

    test('User model handles optional photoURL', () {
      final userWithPhoto = User(
        id: 'test-id',
        displayName: 'With Photo',
        photoURL: 'https://example.com/photo.jpg',
        isPrivate: false,
        workoutPreference: WorkoutType.running,
        beginnerFlag: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final userWithoutPhoto = User(
        id: 'test-id-2',
        displayName: 'No Photo',
        isPrivate: false,
        workoutPreference: WorkoutType.other,
        beginnerFlag: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(userWithPhoto.photoURL, isNotNull);
      expect(userWithoutPhoto.photoURL, isNull);
    });

    test('User toFirestore includes all fields', () {
      final user = User(
        id: 'test-id',
        displayName: 'Test',
        photoURL: 'https://photo.url',
        isPrivate: true,
        workoutPreference: WorkoutType.gym,
        beginnerFlag: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final data = user.toFirestore();

      expect(data['displayName'], 'Test');
      expect(data['photoURL'], 'https://photo.url');
      expect(data['isPrivate'], true);
      expect(data['workoutPreference'], 'gym');
      expect(data['beginnerFlag'], false);
    });

    test('User handles moderation fields', () {
      final bannedUser = User(
        id: 'banned-user',
        displayName: 'Banned',
        isPrivate: false,
        workoutPreference: WorkoutType.gym,
        beginnerFlag: false,
        isBanned: true,
        bannedUntil: DateTime(2026, 12, 31),
        banReason: 'Violated ToS',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(bannedUser.isBanned, true);
      expect(bannedUser.banReason, 'Violated ToS');
    });

    test('User handles leaderboard fields', () {
      final leaderUser = User(
        id: 'leader-user',
        displayName: 'Leader',
        isPrivate: false,
        workoutPreference: WorkoutType.other,
        beginnerFlag: false,
        workoutScore: 1500,
        hasGlobalLeaderboardAccess: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(leaderUser.workoutScore, 1500);
      expect(leaderUser.hasGlobalLeaderboardAccess, true);
    });
  });

  group('Session Model Tests', () {
    test('Session creates with required fields', () {
      final session = Session(
        id: 'session-id',
        hostId: 'host-user-id',
        type: 'strength',
        title: 'Morning Workout',
        status: SessionStatus.active,
        participants: ['host-user-id'],
        participantTypes: const {'host-user-id': 'strength'},
        createdAt: DateTime.now(),
        startedAt: DateTime.now(),
      );

      expect(session.id, 'session-id');
      expect(session.hostId, 'host-user-id');
      expect(session.type, 'strength');
      expect(session.status, SessionStatus.active);
      expect(session.participants, contains('host-user-id'));
    });

    test('Session supports buddy pair', () {
      final buddySession = Session(
        id: 'buddy-session',
        hostId: 'user-1',
        type: 'cardio',
        title: 'Partner Run',
        status: SessionStatus.active,
        participants: ['user-1', 'user-2'],
        buddyPairId: 'pair-123',
        participantTypes: const {'user-1': 'cardio', 'user-2': 'gym'},
        createdAt: DateTime.now(),
        startedAt: DateTime.now(),
      );

      expect(buddySession.buddyPairId, 'pair-123');
      expect(buddySession.participants.length, 2);
    });

    test('Session modes are correct', () {
      expect(SessionMode.turnBased.value, 'turn_based');
      expect(SessionMode.parallel.value, 'parallel');
    });

    test('paired session constants are stable', () {
      expect(pairedBotFriendId, 'zyntro_bot_friend');
      expect(
        pairedInviteTimeout,
        greaterThanOrEqualTo(const Duration(minutes: 5)),
      );
      expect(PairedPartnerKind.bot.value, 'bot');
      expect(PairedPartnerKind.realFriend.value, 'real_friend');
    });

    test('Session parses paired friend metadata', () {
      final session = Session.fromMap(
        id: 'session-1',
        data: {
          'type': 'gym',
          'title': 'Paired Gym',
          'hostId': 'host-1',
          'participants': ['host-1', 'friend-1'],
          'status': 'active',
          'phase': 'setup',
          'partnerKind': 'real_friend',
          'partnerId': 'friend-1',
          'invitationStatus': 'pending',
          'sharedClockStartedAt': DateTime(2026, 1, 1),
          'participantTypes': {'host-1': 'gym', 'friend-1': 'running'},
          'createdAt': DateTime(2026, 1, 1),
          'startedAt': DateTime(2026, 1, 1),
        },
      );

      expect(session.partnerKind, PairedPartnerKind.realFriend);
      expect(session.partnerId, 'friend-1');
      expect(session.invitationStatus, WorkoutInvitationStatus.pending);
      expect(session.sharedClockStartedAt, DateTime(2026, 1, 1));
      expect(session.derivedMode, SessionMode.parallel);
      expect(session.hasExactlyTwoParticipants, isTrue);
    });

    test('Session.derivedMode is turn-based only for gym+gym', () {
      expect(
        Session.modeFromParticipantTypes(const {
          'a': 'gym',
          'b': 'gym',
        }),
        SessionMode.turnBased,
      );
      expect(
        Session.modeFromParticipantTypes(const {
          'a': 'running',
          'b': 'running',
        }),
        SessionMode.parallel,
      );
      expect(
        Session.modeFromParticipantTypes(const {}),
        SessionMode.parallel,
      );
    });

    test('participant progress serializes type-specific metrics', () {
      final progress = ParticipantProgress(
        sessionId: 'session-1',
        userId: 'runner-1',
        workoutType: WorkoutType.running,
        status: ParticipantProgressStatus.active,
        sharedElapsedSeconds: 42,
        gymMetrics: const GymProgressMetrics(
          setSeconds: 7,
          reps: 8,
          weightKg: 80,
        ),
        timeMetrics: const TimeProgressMetrics(elapsedSeconds: 42),
        distanceMetrics: const DistanceProgressMetrics(distanceKm: 0.12),
        roundMetrics: const RoundProgressMetrics(completedRounds: 2),
        mobilityMetrics: const MobilityProgressMetrics(completedStages: 3),
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = progress.toMap();

      expect(map['workoutType'], 'running');
      expect(map['status'], 'active');
      expect(map['sharedElapsedSeconds'], 42);
      expect(map['gymMetrics']['weightKg'], 80);
      expect(map['timeMetrics']['elapsedSeconds'], 42);
      expect(map['distanceMetrics']['distanceKm'], 0.12);
      expect(map['roundMetrics']['completedRounds'], 2);
      expect(map['mobilityMetrics']['completedStages'], 3);
    });

    test('bot friend has fixed gym simulation profile', () {
      final bot = BotFriend.gymSimulation();

      expect(bot.id, pairedBotFriendId);
      expect(bot.displayName, 'Zyntro Bot');
      expect(bot.gymSetSeconds, 7);
      expect(bot.gymReps, 8);
      expect(bot.gymWeightKg, 80);
    });

    test('Session statuses are correct', () {
      expect(SessionStatus.active.value, 'active');
      expect(SessionStatus.completed.value, 'completed');
      expect(SessionStatus.cancelled.value, 'cancelled');
    });
  });

  group('SessionSummary Model Tests', () {
    test('SessionSummary creates with strength data', () {
      final summary = SessionSummary(
        totalSets: 15,
        totalExercises: 5,
        exercises: [
          ExerciseSummary(name: 'Bench Press', sets: 3),
          ExerciseSummary(name: 'Squats', sets: 4),
        ],
      );

      expect(summary.totalSets, 15);
      expect(summary.totalExercises, 5);
      expect(summary.exercises!.length, 2);
    });

    test('SessionSummary creates with cardio data', () {
      final summary = SessionSummary(
        duration: '30:00',
        distance: 5.0,
        pace: '6:00 /km',
      );

      expect(summary.distance, 5.0);
      expect(summary.pace, '6:00 /km');
    });

    test('SessionSummary toMap serializes correctly', () {
      final summary = SessionSummary(totalSets: 20, totalExercises: 6);

      final map = summary.toMap();

      expect(map['totalSets'], 20);
      expect(map['totalExercises'], 6);
    });
  });

  group('Post Model Tests', () {
    test('Post creates with required fields', () {
      final post = Post(
        id: 'post-id',
        authorId: 'author-id',
        sessionId: 'session-id',
        visibility: 'public',
        title: 'My Workout',
        type: 'strength',
        summary: SessionSummary(totalSets: 10),
        likesCount: 0,
        commentsCount: 0,
        createdAt: DateTime.now(),
      );

      expect(post.id, 'post-id');
      expect(post.authorId, 'author-id');
      expect(post.visibility, 'public');
    });

    test('Post handles media URLs', () {
      final postWithMedia = Post(
        id: 'post-media',
        authorId: 'author-id',
        sessionId: 'session-id',
        visibility: 'followers',
        title: 'Workout Post',
        type: 'cardio',
        summary: SessionSummary(),
        mediaURLs: ['https://photo1.jpg', 'https://photo2.jpg'],
        likesCount: 10,
        commentsCount: 5,
        createdAt: DateTime.now(),
      );

      expect(postWithMedia.mediaURLs, hasLength(2));
      expect(postWithMedia.likesCount, 10);
    });
  });

  group('Follow Model Tests', () {
    test('Follow creates with pending status', () {
      final follow = Follow(
        followerId: 'user-1',
        followeeId: 'user-2',
        status: FollowStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(follow.status, FollowStatus.pending);
    });

    test('Follow status values are correct', () {
      expect(FollowStatus.pending.value, 'pending');
      expect(FollowStatus.approved.value, 'approved');
      expect(FollowStatus.declined.value, 'declined');
    });
  });

  group('BuddyPair Model Tests', () {
    test('BuddyPair creates correctly', () {
      final pair = BuddyPair(
        id: 'pair-id',
        participants: ['user-1', 'user-2'],
        initiatorId: 'user-1',
        status: BuddyPairStatus.active,
        inviteCode: 'ABC123',
        createdAt: DateTime.now(),
      );

      expect(pair.participants, hasLength(2));
      expect(pair.status, BuddyPairStatus.active);
      expect(pair.inviteCode, 'ABC123');
    });
  });

  group('TimelineEvent Model Tests', () {
    test('TimelineEvent types are correct', () {
      final events = [
        SessionEventType.start,
        SessionEventType.finish,
        SessionEventType.setLogged,
        SessionEventType.voiceNote,
        SessionEventType.cardioEntry,
        SessionEventType.cheer,
        SessionEventType.join,
        SessionEventType.leave,
      ];

      for (final eventType in events) {
        expect(eventType.value, isNotEmpty);
      }
    });
  });

  group('Report Model Tests', () {
    test('Report creates correctly', () {
      final report = Report(
        id: 'report-id',
        reporterId: 'reporter-id',
        reportedUserId: 'target-id',
        reason: ReportReason.spam,
        status: ReportStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(report.reason, ReportReason.spam);
      expect(report.status, ReportStatus.pending);
    });

    test('Report reasons parse correctly', () {
      expect(ReportReason.fromString('spam'), ReportReason.spam);
      expect(ReportReason.fromString('harassment'), ReportReason.harassment);
      expect(
        ReportReason.fromString('inappropriate'),
        ReportReason.inappropriate,
      );
    });

    test('Report toFirestore serializes', () {
      final report = Report(
        id: 'report-id',
        reporterId: 'reporter',
        reportedUserId: 'target',
        reason: ReportReason.harassment,
        status: ReportStatus.pending,
        description: 'Detailed description',
        createdAt: DateTime.now(),
      );

      final data = report.toFirestore();

      expect(data['reporterId'], 'reporter');
      expect(data['reportedUserId'], 'target');
      expect(data['reason'], 'harassment');
      expect(data['description'], 'Detailed description');
    });
  });

  group('Block Model Tests', () {
    test('Block creates correctly', () {
      final block = Block(
        blockerId: 'blocker',
        blockedUserId: 'blocked',
        createdAt: DateTime.now(),
      );

      expect(block.blockerId, 'blocker');
      expect(block.blockedUserId, 'blocked');
    });

    test('Block toFirestore serializes', () {
      final block = Block(
        blockerId: 'blocker',
        blockedUserId: 'blocked',
        createdAt: DateTime(2026, 1, 1),
      );

      final data = block.toFirestore();

      expect(data['blockerId'], 'blocker');
      expect(data['blockedUserId'], 'blocked');
    });
  });

  group('SetData Model Tests', () {
    test('SetData creates correctly', () {
      final set = SetData(weight: 100, reps: 10, rpe: 8);

      expect(set.weight, 100);
      expect(set.reps, 10);
      expect(set.rpe, 8);
    });

    test('SetData toMap serializes', () {
      final set = SetData(weight: 225, reps: 5);
      final map = set.toMap();

      expect(map['weight'], 225);
      expect(map['reps'], 5);
    });
  });

  group('Exercise Model Tests', () {
    test('Exercise creates with sets', () {
      final exercise = Exercise(
        id: 'exercise-id',
        name: 'Deadlift',
        sets: [
          SetData(weight: 315, reps: 5),
          SetData(weight: 335, reps: 3),
          SetData(weight: 355, reps: 1),
        ],
      );

      expect(exercise.name, 'Deadlift');
      expect(exercise.sets, hasLength(3));
    });

    test('Exercise copyWith works', () {
      final exercise = Exercise(
        id: 'id',
        name: 'Bench',
        sets: [SetData(weight: 135, reps: 10)],
      );

      final updated = exercise.copyWith(
        sets: [...exercise.sets, SetData(weight: 155, reps: 8)],
      );

      expect(updated.sets, hasLength(2));
      expect(exercise.sets, hasLength(1)); // Original unchanged
    });
  });

  group('Constants Tests', () {
    test('WorkoutType values are correct', () {
      expect(WorkoutType.gym.value, 'gym');
      expect(WorkoutType.running.value, 'running');
      expect(WorkoutType.other.value, 'other');
    });

    test('SessionEventType values are correct', () {
      expect(SessionEventType.start.value, 'start');
      expect(SessionEventType.finish.value, 'finish');
      expect(SessionEventType.setLogged.value, 'set_logged');
      expect(SessionEventType.voiceNote.value, 'voice_note');
      expect(SessionEventType.cardioEntry.value, 'cardio_entry_logged');
    });
  });
}

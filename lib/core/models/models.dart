import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/constants.dart';

/// User model matching Firestore users collection.
class User {
  final String id;
  final String displayName;
  final String?
  username; // Unique handle (lowercase a-z 0-9 _), shown as @username
  final String? photoURL;
  final bool isPrivate;
  final WorkoutType workoutPreference;
  final bool beginnerFlag;
  final String? avatarConfig;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActive; // Added for presence caching
  final List<String>? buddyIds;

  // Leaderboard fields
  final int workoutScore;
  final int totalWorkouts;
  final bool hasGlobalLeaderboardAccess;
  final DateTime? globalAccessGrantedAt;

  // Moderation fields
  final bool isModerator;
  final bool isBanned;
  final DateTime? bannedUntil;
  final String? banReason;

  User({
    required this.id,
    required this.displayName,
    this.username,
    this.photoURL,
    required this.isPrivate,
    required this.workoutPreference,
    required this.beginnerFlag,
    this.avatarConfig,
    required this.createdAt,
    required this.updatedAt,
    this.buddyIds,
    this.lastActive,
    this.workoutScore = 0,
    this.totalWorkouts = 0,
    this.hasGlobalLeaderboardAccess = false,
    this.globalAccessGrantedAt,
    this.isModerator = false,
    this.isBanned = false,
    this.bannedUntil,
    this.banReason,
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      username: data['username'] as String?,
      photoURL: data['photoURL'],
      isPrivate: data['isPrivate'] ?? false,
      workoutPreference: WorkoutType.fromString(
        data['workoutPreference'] ?? 'both',
      ),
      beginnerFlag: data['beginnerFlag'] ?? false,
      avatarConfig: data['avatarConfig'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      buddyIds: (data['buddyIds'] as List<dynamic>?)?.cast<String>(),
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      workoutScore: data['workoutScore'] ?? 0,
      totalWorkouts: data['totalWorkouts'] ?? 0,
      hasGlobalLeaderboardAccess: data['hasGlobalLeaderboardAccess'] ?? false,
      globalAccessGrantedAt: (data['globalAccessGrantedAt'] as Timestamp?)
          ?.toDate(),
      isModerator: data['isModerator'] ?? false,
      isBanned: data['isBanned'] ?? false,
      bannedUntil: (data['bannedUntil'] as Timestamp?)?.toDate(),
      banReason: data['banReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      if (username != null) 'username': username,
      'photoURL': photoURL,
      'isPrivate': isPrivate,
      'workoutPreference': workoutPreference.value,
      'beginnerFlag': beginnerFlag,
      if (avatarConfig != null) 'avatarConfig': avatarConfig,
      'updatedAt': FieldValue.serverTimestamp(),
      if (lastActive != null) 'lastActive': Timestamp.fromDate(lastActive!),
      'workoutScore': workoutScore,
      'totalWorkouts': totalWorkouts,
      'hasGlobalLeaderboardAccess': hasGlobalLeaderboardAccess,
      if (globalAccessGrantedAt != null)
        'globalAccessGrantedAt': Timestamp.fromDate(globalAccessGrantedAt!),
      'isModerator': isModerator,
      'isBanned': isBanned,
      if (bannedUntil != null) 'bannedUntil': Timestamp.fromDate(bannedUntil!),
      if (banReason != null) 'banReason': banReason,
    };
  }
}

/// Session model matching Firestore sessions collection.
class Session {
  final String id;
  final String type; // 'strength' | 'cardio'
  final String title;
  final String hostId;
  final List<String> participants;
  final SessionStatus status;
  final SessionPhase phase;
  final String? buddyPairId;
  final String? activeUserId;
  final PairedPartnerKind? partnerKind;
  final String? partnerId;
  final WorkoutInvitationStatus? invitationStatus;
  final DateTime? sharedClockStartedAt;
  /// When the current active participant started their current set (tapped
  /// START). Null between sets. Drives the partner's per-set timer so it counts
  /// the set, not the whole session.
  final DateTime? activeSetStartedAt;
  final SessionSummary? summary;
  final DateTime createdAt;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Per-participant workout type choice. {userId: workoutTypeValue}
  final Map<String, String> participantTypes;

  Session({
    required this.id,
    required this.type,
    required this.title,
    required this.hostId,
    required this.participants,
    required this.status,
    this.phase = SessionPhase.live,
    this.buddyPairId,
    this.activeUserId,
    this.partnerKind,
    this.partnerId,
    this.invitationStatus,
    this.sharedClockStartedAt,
    this.activeSetStartedAt,
    this.summary,
    required this.createdAt,
    required this.startedAt,
    this.endedAt,
    this.participantTypes = const {},
  });

  /// Derive session mode from participant workout types.
  /// Same type for all → turn-based; mixed types → parallel.
  SessionMode get derivedMode {
    if (participantTypes.isEmpty ||
        participantTypes.values.toSet().length == 1) {
      return SessionMode.turnBased;
    }
    return SessionMode.parallel;
  }

  bool get hasExactlyTwoParticipants => participants.length == 2;

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Session.fromMap(id: doc.id, data: data);
  }

  factory Session.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final rawTypes = data['participantTypes'] as Map<String, dynamic>?;
    return Session(
      id: id,
      type: data['type'] ?? 'strength',
      title: data['title'] ?? '',
      hostId: data['hostId'] ?? '',
      participants:
          (data['participants'] as List<dynamic>?)?.cast<String>() ?? [],
      status: SessionStatus.fromString(data['status'] ?? 'active'),
      phase: SessionPhase.fromString(data['phase'] ?? 'live'),
      buddyPairId: data['buddyPairId'],
      activeUserId: data['activeUserId'],
      partnerKind: data['partnerKind'] != null
          ? PairedPartnerKind.fromString(data['partnerKind'] as String)
          : null,
      partnerId: data['partnerId'],
      invitationStatus: data['invitationStatus'] != null
          ? WorkoutInvitationStatus.fromString(
              data['invitationStatus'] as String,
            )
          : null,
      sharedClockStartedAt: _dateTimeFromValue(data['sharedClockStartedAt']),
      activeSetStartedAt: _dateTimeFromValue(data['activeSetStartedAt']),
      summary: data['summary'] != null
          ? SessionSummary.fromMap(data['summary'] as Map<String, dynamic>)
          : null,
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      startedAt: _dateTimeFromValue(data['startedAt']) ?? DateTime.now(),
      endedAt: _dateTimeFromValue(data['endedAt']),
      participantTypes: rawTypes != null
          ? rawTypes.map((k, v) => MapEntry(k, v as String))
          : const {},
    );
  }
}

DateTime? _dateTimeFromValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class DistanceProgressMetrics {
  final double distanceKm;

  const DistanceProgressMetrics({required this.distanceKm});

  Map<String, dynamic> toMap() {
    return {'distanceKm': distanceKm};
  }
}

class GymProgressMetrics {
  final int setSeconds;
  final int reps;
  final double weightKg;

  const GymProgressMetrics({
    required this.setSeconds,
    required this.reps,
    required this.weightKg,
  });

  Map<String, dynamic> toMap() {
    return {'setSeconds': setSeconds, 'reps': reps, 'weightKg': weightKg};
  }
}

class TimeProgressMetrics {
  final int elapsedSeconds;

  const TimeProgressMetrics({required this.elapsedSeconds});

  Map<String, dynamic> toMap() {
    return {'elapsedSeconds': elapsedSeconds};
  }
}

class RoundProgressMetrics {
  final int completedRounds;

  const RoundProgressMetrics({required this.completedRounds});

  Map<String, dynamic> toMap() {
    return {'completedRounds': completedRounds};
  }
}

class MobilityProgressMetrics {
  final int completedStages;

  const MobilityProgressMetrics({required this.completedStages});

  Map<String, dynamic> toMap() {
    return {'completedStages': completedStages};
  }
}

class ParticipantProgress {
  final String sessionId;
  final String userId;
  final WorkoutType workoutType;
  final ParticipantProgressStatus status;
  final int sharedElapsedSeconds;
  final GymProgressMetrics? gymMetrics;
  final TimeProgressMetrics? timeMetrics;
  final DistanceProgressMetrics? distanceMetrics;
  final RoundProgressMetrics? roundMetrics;
  final MobilityProgressMetrics? mobilityMetrics;
  final DateTime updatedAt;

  const ParticipantProgress({
    required this.sessionId,
    required this.userId,
    required this.workoutType,
    required this.status,
    required this.sharedElapsedSeconds,
    this.gymMetrics,
    this.timeMetrics,
    this.distanceMetrics,
    this.roundMetrics,
    this.mobilityMetrics,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'workoutType': workoutType.value,
      'status': status.value,
      'sharedElapsedSeconds': sharedElapsedSeconds,
      if (gymMetrics != null) 'gymMetrics': gymMetrics!.toMap(),
      if (timeMetrics != null) 'timeMetrics': timeMetrics!.toMap(),
      if (distanceMetrics != null) 'distanceMetrics': distanceMetrics!.toMap(),
      if (roundMetrics != null) 'roundMetrics': roundMetrics!.toMap(),
      if (mobilityMetrics != null) 'mobilityMetrics': mobilityMetrics!.toMap(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class BotFriend {
  final String id;
  final String displayName;
  final int gymSetSeconds;
  final int gymReps;
  final double gymWeightKg;

  const BotFriend({
    required this.id,
    required this.displayName,
    required this.gymSetSeconds,
    required this.gymReps,
    required this.gymWeightKg,
  });

  factory BotFriend.gymSimulation() {
    return const BotFriend(
      id: pairedBotFriendId,
      displayName: 'Zyntro Bot',
      gymSetSeconds: 7,
      gymReps: 8,
      gymWeightKg: 80,
    );
  }
}

/// Per-user session statistics for buddy sessions.
class UserSessionStats {
  final String userId;
  final List<ExerciseSummary> exercises;
  final int totalSets;
  final double totalVolume;
  final int activeCalories;

  UserSessionStats({
    required this.userId,
    required this.exercises,
    required this.totalSets,
    required this.totalVolume,
    required this.activeCalories,
  });

  factory UserSessionStats.fromMap(Map<String, dynamic> data) {
    return UserSessionStats(
      userId: data['userId'] ?? '',
      exercises:
          (data['exercises'] as List<dynamic>?)
              ?.map((e) => ExerciseSummary.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalSets: data['totalSets'] ?? 0,
      totalVolume: (data['totalVolume'] as num?)?.toDouble() ?? 0.0,
      activeCalories: data['activeCalories'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'totalSets': totalSets,
      'totalVolume': totalVolume,
      'activeCalories': activeCalories,
    };
  }
}

/// Session summary model with support for diverse workout metrics.
class SessionSummary {
  final int? totalSets;
  final int? totalExercises;
  final List<ExerciseSummary>? exercises;
  final double? distance;
  final String? duration;
  final String? pace;

  // Added for RecapPage
  final double? totalVolume;
  final int? activeCalories;

  // Per-participant statistics for buddy sessions
  final Map<String, UserSessionStats>? participantStats;

  // New fields for expanded workout type support
  /// Specific activity type (e.g., 'running', 'cycling', 'swimming')
  final String? activityType;

  /// Average speed for cardio activities (km/h or mph)
  final double? averageSpeed;

  /// Elevation gain for outdoor activities (in meters)
  final int? elevationGain;

  /// GPS coordinates for route tracking (list of {lat, lng, timestamp})
  final List<Map<String, dynamic>>? routePoints;

  /// Estimated calories burned
  final int? caloriesBurned;

  /// Average heart rate for fitness tracker integration
  final double? averageHeartRate;

  /// Flexible field for workout-specific data
  final Map<String, dynamic>? additionalMetrics;

  SessionSummary({
    this.totalSets,
    this.totalExercises,
    this.exercises,
    this.distance,
    this.duration,
    this.pace,
    this.totalVolume,
    this.activeCalories,
    this.participantStats,
    this.activityType,
    this.averageSpeed,
    this.elevationGain,
    this.routePoints,
    this.caloriesBurned,
    this.averageHeartRate,
    this.additionalMetrics,
  });

  /// Check if this is a cardio workout (has distance/pace fields).
  bool get isCardioWorkout =>
      distance != null || pace != null || activityType != null;

  factory SessionSummary.fromMap(Map<String, dynamic> data) {
    Map<String, UserSessionStats>? participantStats;
    if (data['participantStats'] != null) {
      final statsMap = data['participantStats'] as Map<String, dynamic>;
      participantStats = statsMap.map(
        (key, value) => MapEntry(
          key,
          UserSessionStats.fromMap(value as Map<String, dynamic>),
        ),
      );
    }

    // Parse route points if present
    List<Map<String, dynamic>>? routePoints;
    if (data['routePoints'] != null) {
      routePoints = (data['routePoints'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return SessionSummary(
      totalSets: data['totalSets'],
      totalExercises: data['totalExercises'],
      exercises: (data['exercises'] as List<dynamic>?)
          ?.map((e) => ExerciseSummary.fromMap(e as Map<String, dynamic>))
          .toList(),
      distance: (data['distance'] as num?)?.toDouble(),
      duration: data['duration'],
      pace: data['pace'],
      totalVolume: (data['totalVolume'] as num?)?.toDouble(),
      activeCalories: data['activeCalories'],
      participantStats: participantStats,
      activityType: data['activityType'],
      averageSpeed: (data['averageSpeed'] as num?)?.toDouble(),
      elevationGain: data['elevationGain'],
      routePoints: routePoints,
      caloriesBurned: data['caloriesBurned'],
      averageHeartRate: (data['averageHeartRate'] as num?)?.toDouble(),
      additionalMetrics: data['additionalMetrics'] != null
          ? Map<String, dynamic>.from(data['additionalMetrics'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (totalSets != null) 'totalSets': totalSets,
      if (totalExercises != null) 'totalExercises': totalExercises,
      if (exercises != null)
        'exercises': exercises!.map((e) => e.toMap()).toList(),
      if (distance != null) 'distance': distance,
      if (duration != null) 'duration': duration,
      if (pace != null) 'pace': pace,
      if (totalVolume != null) 'totalVolume': totalVolume,
      if (activeCalories != null) 'activeCalories': activeCalories,
      if (participantStats != null)
        'participantStats': participantStats!.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
      if (activityType != null) 'activityType': activityType,
      if (averageSpeed != null) 'averageSpeed': averageSpeed,
      if (elevationGain != null) 'elevationGain': elevationGain,
      if (routePoints != null) 'routePoints': routePoints,
      if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
      if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
      if (additionalMetrics != null) 'additionalMetrics': additionalMetrics,
    };
  }
}

/// Per-set detail stored inside an ExerciseSummary.
class SetSummary {
  final int reps;
  final double weight;
  final int durationSeconds;

  SetSummary({
    required this.reps,
    required this.weight,
    required this.durationSeconds,
  });

  factory SetSummary.fromMap(Map<String, dynamic> data) {
    return SetSummary(
      reps: data['reps'] ?? 0,
      weight: (data['weight'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: data['durationSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'reps': reps,
    'weight': weight,
    'durationSeconds': durationSeconds,
  };
}

/// Exercise summary for session recap.
class ExerciseSummary {
  final String name;
  final int sets;
  final List<SetSummary> setDetails;

  ExerciseSummary({
    required this.name,
    required this.sets,
    this.setDetails = const [],
  });

  factory ExerciseSummary.fromMap(Map<String, dynamic> data) {
    return ExerciseSummary(
      name: data['name'] ?? '',
      sets: data['sets'] ?? 0,
      setDetails:
          (data['setDetails'] as List<dynamic>?)
              ?.map((e) => SetSummary.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'sets': sets,
    if (setDetails.isNotEmpty)
      'setDetails': setDetails.map((s) => s.toMap()).toList(),
  };
}

/// Timeline event model for session room.
class TimelineEvent {
  final String id;
  final SessionEventType type;
  final String userId;
  final String text;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  TimelineEvent({
    required this.id,
    required this.type,
    required this.userId,
    required this.text,
    required this.timestamp,
    this.data,
  });

  factory TimelineEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimelineEvent(
      id: doc.id,
      type: SessionEventType.fromString(data['type'] ?? 'start'),
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data: data['data'] as Map<String, dynamic>?,
    );
  }
}

/// Buddy pair model.
class BuddyPair {
  final String id;
  final List<String> participants;
  final String initiatorId;
  final BuddyPairStatus status;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? endedAt;

  BuddyPair({
    required this.id,
    required this.participants,
    required this.initiatorId,
    required this.status,
    this.inviteCode,
    required this.createdAt,
    this.activatedAt,
    this.endedAt,
  });

  factory BuddyPair.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BuddyPair(
      id: doc.id,
      participants:
          (data['participants'] as List<dynamic>?)?.cast<String>() ?? [],
      initiatorId: data['initiatorId'] ?? '',
      status: BuddyPairStatus.fromString(data['status'] ?? 'pending'),
      inviteCode: data['inviteCode'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      activatedAt: (data['activatedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// PostAuthorSlot model for co-authored posts.
class PostAuthorSlot {
  final String userId;
  final String? caption;
  final String? photoUrl;
  final bool confirmed;
  final bool removed;
  final String visibility; // this author's chosen 'public' | 'private'
  final SessionSummary summary;

  const PostAuthorSlot({
    required this.userId,
    this.caption,
    this.photoUrl,
    this.confirmed = false,
    this.removed = false,
    this.visibility = 'public',
    required this.summary,
  });

  factory PostAuthorSlot.fromMap(Map<String, dynamic> d) => PostAuthorSlot(
        userId: d['userId'] ?? '',
        caption: d['caption'],
        photoUrl: d['photoUrl'],
        confirmed: d['confirmed'] ?? false,
        removed: d['removed'] ?? false,
        visibility: d['visibility'] ?? 'public',
        summary: SessionSummary.fromMap(Map<String, dynamic>.from(d['summary'] as Map? ?? {})),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'caption': caption,
        'photoUrl': photoUrl,
        'confirmed': confirmed,
        'removed': removed,
        'visibility': visibility,
        'summary': summary.toMap(),
      };
}

/// Post model matching Firestore posts collection.
class Post {
  final String id;
  final String authorId;
  final List<String> authorIds;
  final String status;
  final bool coAuthored;
  final Map<String, PostAuthorSlot> authors;
  final String sessionId;
  final String visibility; // 'public' | 'private' | 'friends'
  final String title;
  final String type; // 'strength' | 'cardio'
  final SessionSummary summary;
  final List<String>? mediaURLs;
  final String? buddyId;
  final String? buddyName;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final Map<String, int>?
  reactionCounts; // Optional cached reaction counts by type

  Post({
    required this.id,
    required this.authorId,
    required this.authorIds,
    required this.status,
    required this.coAuthored,
    required this.authors,
    required this.sessionId,
    required this.visibility,
    required this.title,
    required this.type,
    required this.summary,
    this.mediaURLs,
    this.buddyId,
    this.buddyName,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    this.reactionCounts,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) =>
      Post.fromMap(doc.id, doc.data() as Map<String, dynamic>);

  factory Post.fromMap(String id, Map<String, dynamic> data) {
    final authorId = data['authorId'] ?? '';
    Map<String, PostAuthorSlot>? authorsMap;
    if (data['authors'] != null) {
      final authorsData = data['authors'] as Map<String, dynamic>;
      authorsMap = authorsData.map(
        (k, v) => MapEntry(k, PostAuthorSlot.fromMap(Map<String, dynamic>.from(v as Map))),
      );
    }

    return Post(
      id: id,
      authorId: authorId,
      authorIds: (data['authorIds'] as List<dynamic>?)?.cast<String>() ??
          (authorId.isEmpty ? const [] : [authorId]),
      status: data['status'] ?? 'published',
      coAuthored: data['coAuthored'] ?? false,
      authors: authorsMap ?? const {},
      sessionId: data['sessionId'] ?? '',
      visibility: data['visibility'] ?? 'public',
      title: data['title'] ?? '',
      type: data['type'] ?? 'strength',
      summary: SessionSummary.fromMap(Map<String, dynamic>.from(data['summary'] as Map? ?? {})),
      mediaURLs: (data['mediaURLs'] as List<dynamic>?)?.cast<String>(),
      buddyId: data['buddyId'],
      buddyName: data['buddyName'],
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactionCounts: (data['reactionCounts'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)),
    );
  }
}

/// Follow relationship model.
class Follow {
  final String followerId;
  final String followeeId;
  final FollowStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Follow({
    required this.followerId,
    required this.followeeId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory Follow.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Follow(
      followerId: data['followerId'] ?? '',
      followeeId: data['followeeId'] ?? '',
      status: FollowStatus.fromString(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Set data for exercise tracking.
class SetData {
  final double weight;
  final int reps;
  final int? rpe;
  final int durationSeconds;

  SetData({
    required this.weight,
    required this.reps,
    this.rpe,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'reps': reps,
      if (rpe != null) 'rpe': rpe,
      'durationSeconds': durationSeconds,
    };
  }
}

/// Local exercise model for session room.
class Exercise {
  final String id;
  final String name;
  final List<SetData> sets;

  Exercise({required this.id, required this.name, required this.sets});

  Exercise copyWith({List<SetData>? sets}) {
    return Exercise(id: id, name: name, sets: sets ?? this.sets);
  }
}

/// Reaction type enum for posts.
enum ReactionType {
  fire('fire'),
  strong('strong'),
  clap('clap');

  final String value;
  const ReactionType(this.value);

  static ReactionType fromString(String value) {
    if (value == 'beast') return ReactionType.strong;
    return ReactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReactionType.fire,
    );
  }
}

/// Report reason enum.
enum ReportReason {
  spam('spam'),
  harassment('harassment'),
  inappropriate('inappropriate'),
  other('other');

  final String value;
  const ReportReason(this.value);

  static ReportReason fromString(String value) {
    return ReportReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportReason.other,
    );
  }
}

/// Report status enum.
enum ReportStatus {
  pending('pending'),
  reviewed('reviewed'),
  dismissed('dismissed');

  final String value;
  const ReportStatus(this.value);

  static ReportStatus fromString(String value) {
    return ReportStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportStatus.pending,
    );
  }
}

/// Report model for user/post/comment reports.
class Report {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String? reportedPostId;
  final String? reportedCommentId;
  final ReportReason reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  Report({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    this.reportedPostId,
    this.reportedCommentId,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reportedUserId: data['reportedUserId'] ?? '',
      reportedPostId: data['reportedPostId'],
      reportedCommentId: data['reportedCommentId'],
      reason: ReportReason.fromString(data['reason'] ?? 'other'),
      description: data['description'],
      status: ReportStatus.fromString(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      if (reportedPostId != null) 'reportedPostId': reportedPostId,
      if (reportedCommentId != null) 'reportedCommentId': reportedCommentId,
      'reason': reason.value,
      if (description != null) 'description': description,
      'status': status.value,
      'createdAt': FieldValue.serverTimestamp(),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
    };
  }
}

/// Block model for blocked users.
class Block {
  final String blockerId;
  final String blockedUserId;
  final DateTime createdAt;

  Block({
    required this.blockerId,
    required this.blockedUserId,
    required this.createdAt,
  });

  factory Block.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Block(
      blockerId: data['blockerId'] ?? '',
      blockedUserId: data['blockedUserId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'blockerId': blockerId,
      'blockedUserId': blockedUserId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Workout model for completed sessions.
class Workout {
  final String id;
  final String userId;
  final String sessionId;
  final String type; // workout type value (gym, running, cycling, etc.)
  final String title;
  final SessionSummary? summary;
  final DateTime endedAt;
  final DateTime createdAt;

  Workout({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.type,
    required this.title,
    this.summary,
    required this.endedAt,
    required this.createdAt,
  });

  /// Get the WorkoutType enum value.
  WorkoutType get workoutType => WorkoutType.fromString(type);

  /// Get the category of this workout (strength, cardio, flexibility, mixed).
  String get category => workoutType.category;

  /// Check if this is a cardio workout.
  bool get isCardio => workoutType.isCardio;

  /// Check if this is a strength workout.
  bool get isStrength => workoutType.isStrength;

  factory Workout.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Workout(
      id: doc.id,
      userId: data['userId'] ?? '',
      sessionId: data['sessionId'] ?? '',
      type: data['type'] ?? 'gym',
      title: data['title'] ?? '',
      summary: data['summary'] != null
          ? SessionSummary.fromMap(data['summary'] as Map<String, dynamic>)
          : null,
      endedAt: data['endedAt'] != null && data['endedAt'] is String
          ? DateTime.parse(data['endedAt'])
          : data['endedAt'] is Timestamp
          ? (data['endedAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Result of paginated workout queries.
class WorkoutQueryResult {
  final List<Workout> workouts;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  WorkoutQueryResult({
    required this.workouts,
    this.lastDoc,
    required this.hasMore,
  });
}

/// Unified activity item model for recent activity carousel.
/// Wraps either a Workout or Post for display in the social feed.
class ActivityItem {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoURL;
  final String type; // 'workout' or 'post'
  final String workoutType; // 'gym', 'running', etc.
  final String title;
  final SessionSummary? summary;
  final List<String>? mediaURLs;
  final DateTime timestamp;

  ActivityItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoURL,
    required this.type,
    required this.workoutType,
    required this.title,
    this.summary,
    this.mediaURLs,
    required this.timestamp,
  });

  /// Check if this activity is a workout.
  bool get isWorkout => type == 'workout';

  /// Check if this activity is a post.
  bool get isPost => type == 'post';

  /// Get the WorkoutType enum value.
  WorkoutType get workoutTypeEnum => WorkoutType.fromString(workoutType);

  /// Factory constructor from Workout with user data.
  factory ActivityItem.fromWorkout(Workout workout, User user) {
    return ActivityItem(
      id: workout.id,
      userId: workout.userId,
      userName: user.displayName,
      userPhotoURL: user.photoURL,
      type: 'workout',
      workoutType: workout.type,
      title: workout.title,
      summary: workout.summary,
      mediaURLs: null,
      timestamp: workout.endedAt,
    );
  }

  /// Factory constructor from Post with user data.
  factory ActivityItem.fromPost(Post post, User user) {
    return ActivityItem(
      id: post.id,
      userId: post.authorId,
      userName: user.displayName,
      userPhotoURL: user.photoURL,
      type: 'post',
      workoutType: post.type,
      title: post.title,
      summary: post.summary,
      mediaURLs: post.mediaURLs,
      timestamp: post.createdAt,
    );
  }

  /// Factory constructor from Post data map with user data.
  factory ActivityItem.fromPostData({
    required String id,
    required Map<String, dynamic> data,
    required User user,
  }) {
    return ActivityItem(
      id: id,
      userId: data['authorId'] ?? '',
      userName: user.displayName,
      userPhotoURL: user.photoURL,
      type: 'post',
      workoutType: data['type'] ?? 'gym',
      title: data['title'] ?? '',
      summary: data['summary'] != null
          ? SessionSummary.fromMap(data['summary'] as Map<String, dynamic>)
          : null,
      mediaURLs: (data['mediaURLs'] as List<dynamic>?)?.cast<String>(),
      timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

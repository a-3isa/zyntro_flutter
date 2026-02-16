import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/constants.dart';

/// User model matching Firestore users collection.
class User {
  final String id;
  final String displayName;
  final String? photoURL;
  final String?
  avatarConfig; // Stores avatar customization data (for custom avatars)
  final bool isPrivate;
  final WorkoutType workoutPreference;
  final bool beginnerFlag;
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
    this.photoURL,
    this.avatarConfig,
    required this.isPrivate,
    required this.workoutPreference,
    required this.beginnerFlag,
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
      photoURL: data['photoURL'],
      avatarConfig: data['avatarConfig'],
      isPrivate: data['isPrivate'] ?? false,
      workoutPreference: WorkoutType.fromString(
        data['workoutPreference'] ?? 'both',
      ),
      beginnerFlag: data['beginnerFlag'] ?? false,
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
      'photoURL': photoURL,
      if (avatarConfig != null) 'avatarConfig': avatarConfig,
      'isPrivate': isPrivate,
      'workoutPreference': workoutPreference.value,
      'beginnerFlag': beginnerFlag,
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
  final String? buddyPairId;
  final SessionMode mode;
  final String? activeUserId;
  final SessionSummary? summary;
  final DateTime createdAt;
  final DateTime startedAt;
  final DateTime? endedAt;

  Session({
    required this.id,
    required this.type,
    required this.title,
    required this.hostId,
    required this.participants,
    required this.status,
    this.buddyPairId,
    required this.mode,
    this.activeUserId,
    this.summary,
    required this.createdAt,
    required this.startedAt,
    this.endedAt,
  });

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      type: data['type'] ?? 'strength',
      title: data['title'] ?? '',
      hostId: data['hostId'] ?? '',
      participants:
          (data['participants'] as List<dynamic>?)?.cast<String>() ?? [],
      status: SessionStatus.fromString(data['status'] ?? 'active'),
      buddyPairId: data['buddyPairId'],
      mode: SessionMode.fromString(data['mode'] ?? 'turn_based'),
      activeUserId: data['activeUserId'],
      summary: data['summary'] != null
          ? SessionSummary.fromMap(data['summary'] as Map<String, dynamic>)
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
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

/// Exercise summary for session recap.
class ExerciseSummary {
  final String name;
  final int sets;

  ExerciseSummary({required this.name, required this.sets});

  factory ExerciseSummary.fromMap(Map<String, dynamic> data) {
    return ExerciseSummary(name: data['name'] ?? '', sets: data['sets'] ?? 0);
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'sets': sets};
  }
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

/// Post model matching Firestore posts collection.
class Post {
  final String id;
  final String authorId;
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

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      sessionId: data['sessionId'] ?? '',
      visibility: data['visibility'] ?? 'public',
      title: data['title'] ?? '',
      type: data['type'] ?? 'strength',
      summary: SessionSummary.fromMap(data['summary'] ?? {}),
      mediaURLs: (data['mediaURLs'] as List<dynamic>?)?.cast<String>(),
      buddyId: data['buddyId'],
      buddyName: data['buddyName'],
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactionCounts: (data['reactionCounts'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as int),
      ),
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

  SetData({required this.weight, required this.reps, this.rpe});

  Map<String, dynamic> toMap() {
    return {'weight': weight, 'reps': reps, if (rpe != null) 'rpe': rpe};
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
  final String? userAvatarConfig;
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
    this.userAvatarConfig,
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
      userAvatarConfig: user.avatarConfig,
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
      userAvatarConfig: user.avatarConfig,
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
      userAvatarConfig: user.avatarConfig,
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

import '../../../../core/constants/constants.dart';

class UserProfileEntity {
  final String id;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final String? avatarConfig;
  final bool isPrivate;
  final WorkoutType workoutPreference;
  final bool beginnerFlag;
  final int? trainingDaysPerWeek;
  final String? facebookUid;
  final DateTime? facebookConnectedAt;

  const UserProfileEntity({
    required this.id,
    required this.displayName,
    this.username,
    required this.photoUrl,
    required this.avatarConfig,
    required this.isPrivate,
    required this.workoutPreference,
    required this.beginnerFlag,
    this.trainingDaysPerWeek,
    this.facebookUid,
    this.facebookConnectedAt,
  });

  bool get isFacebookConnected => facebookUid != null;

  UserProfileEntity copyWith({
    String? id,
    String? displayName,
    String? username,
    String? photoUrl,
    String? avatarConfig,
    bool? isPrivate,
    WorkoutType? workoutPreference,
    bool? beginnerFlag,
    int? trainingDaysPerWeek,
    String? facebookUid,
    DateTime? facebookConnectedAt,
    bool clearFacebookUid = false,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      isPrivate: isPrivate ?? this.isPrivate,
      workoutPreference: workoutPreference ?? this.workoutPreference,
      beginnerFlag: beginnerFlag ?? this.beginnerFlag,
      trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
      facebookUid: clearFacebookUid ? null : (facebookUid ?? this.facebookUid),
      facebookConnectedAt: clearFacebookUid ? null : (facebookConnectedAt ?? this.facebookConnectedAt),
    );
  }
}

import '../../../../core/constants/constants.dart';

class UserProfileEntity {
  final String id;
  final String displayName;
  final String? username;
  final String? photoUrl;
  final bool isPrivate;
  final WorkoutType workoutPreference;
  final bool beginnerFlag;
  final String? avatarConfig;
  final int? trainingDaysPerWeek;
  final String? facebookUid;
  final DateTime? facebookConnectedAt;

  const UserProfileEntity({
    required this.id,
    required this.displayName,
    this.username,
    required this.photoUrl,
    required this.isPrivate,
    required this.workoutPreference,
    required this.beginnerFlag,
    this.avatarConfig,
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
    bool? isPrivate,
    WorkoutType? workoutPreference,
    bool? beginnerFlag,
    String? avatarConfig,
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
      isPrivate: isPrivate ?? this.isPrivate,
      workoutPreference: workoutPreference ?? this.workoutPreference,
      beginnerFlag: beginnerFlag ?? this.beginnerFlag,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
      facebookUid: clearFacebookUid ? null : (facebookUid ?? this.facebookUid),
      facebookConnectedAt: clearFacebookUid
          ? null
          : (facebookConnectedAt ?? this.facebookConnectedAt),
    );
  }
}

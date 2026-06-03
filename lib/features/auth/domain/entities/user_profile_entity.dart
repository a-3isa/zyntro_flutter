import '../../../../core/constants/constants.dart';

class UserProfileEntity {
  final String id;
  final String displayName;
  final String? photoUrl;
  final String? avatarConfig;
  final bool isPrivate;
  final WorkoutType workoutPreference;
  final bool beginnerFlag;
  final int? trainingDaysPerWeek;

  const UserProfileEntity({
    required this.id,
    required this.displayName,
    required this.photoUrl,
    required this.avatarConfig,
    required this.isPrivate,
    required this.workoutPreference,
    required this.beginnerFlag,
    this.trainingDaysPerWeek,
  });

  UserProfileEntity copyWith({
    String? id,
    String? displayName,
    String? photoUrl,
    String? avatarConfig,
    bool? isPrivate,
    WorkoutType? workoutPreference,
    bool? beginnerFlag,
    int? trainingDaysPerWeek,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      isPrivate: isPrivate ?? this.isPrivate,
      workoutPreference: workoutPreference ?? this.workoutPreference,
      beginnerFlag: beginnerFlag ?? this.beginnerFlag,
      trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
    );
  }
}

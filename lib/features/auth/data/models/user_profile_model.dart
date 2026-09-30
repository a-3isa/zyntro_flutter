import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/constants.dart';
import '../../domain/entities/user_profile_entity.dart';

class UserProfileModel {
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

  const UserProfileModel({
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

  factory UserProfileModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final fbConnectedRaw = data['facebookConnectedAt'];

    return UserProfileModel(
      id: doc.id,
      displayName: data['displayName'] as String? ?? '',
      username: data['username'] as String?,
      photoUrl: data['photoURL'] as String?,
      isPrivate: data['isPrivate'] as bool? ?? false,
      workoutPreference: WorkoutType.fromString(
        data['workoutPreference'] as String? ?? 'other',
      ),
      beginnerFlag: data['beginnerFlag'] as bool? ?? false,
      avatarConfig: data['avatarConfig'] as String?,
      trainingDaysPerWeek: data['trainingDaysPerWeek'] as int?,
      facebookUid: data['facebookUid'] as String?,
      facebookConnectedAt: fbConnectedRaw is Timestamp
          ? fbConnectedRaw.toDate()
          : null,
    );
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> data, String id) {
    final fbConnectedRaw = data['facebookConnectedAt'];
    return UserProfileModel(
      id: id,
      displayName: data['displayName'] as String? ?? '',
      username: data['username'] as String?,
      photoUrl: data['photoURL'] as String?,
      isPrivate: data['isPrivate'] as bool? ?? false,
      workoutPreference: WorkoutType.fromString(
        data['workoutPreference'] as String? ?? 'other',
      ),
      beginnerFlag: data['beginnerFlag'] as bool? ?? false,
      avatarConfig: data['avatarConfig'] as String?,
      trainingDaysPerWeek: data['trainingDaysPerWeek'] as int?,
      facebookUid: data['facebookUid'] as String?,
      facebookConnectedAt: fbConnectedRaw is Timestamp
          ? fbConnectedRaw.toDate()
          : null,
    );
  }

  UserProfileEntity toEntity() {
    return UserProfileEntity(
      id: id,
      displayName: displayName,
      username: username,
      photoUrl: photoUrl,
      isPrivate: isPrivate,
      workoutPreference: workoutPreference,
      beginnerFlag: beginnerFlag,
      avatarConfig: avatarConfig,
      trainingDaysPerWeek: trainingDaysPerWeek,
      facebookUid: facebookUid,
      facebookConnectedAt: facebookConnectedAt,
    );
  }
}

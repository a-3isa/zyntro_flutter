import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/constants.dart';
import '../../domain/entities/user_profile_entity.dart';

class UserProfileModel {
  final String id;
  final String displayName;
  final String? photoUrl;
  final String? avatarConfig;
  final bool isPrivate;
  final WorkoutType workoutPreference;
  final bool beginnerFlag;
  final int? trainingDaysPerWeek;

  const UserProfileModel({
    required this.id,
    required this.displayName,
    required this.photoUrl,
    required this.avatarConfig,
    required this.isPrivate,
    required this.workoutPreference,
    required this.beginnerFlag,
    this.trainingDaysPerWeek,
  });

  factory UserProfileModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return UserProfileModel(
      id: doc.id,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoURL'] as String?,
      avatarConfig: data['avatarConfig'] as String?,
      isPrivate: data['isPrivate'] as bool? ?? false,
      workoutPreference: WorkoutType.fromString(
        data['workoutPreference'] as String? ?? 'other',
      ),
      beginnerFlag: data['beginnerFlag'] as bool? ?? false,
      trainingDaysPerWeek: data['trainingDaysPerWeek'] as int?,
    );
  }

  UserProfileEntity toEntity() {
    return UserProfileEntity(
      id: id,
      displayName: displayName,
      photoUrl: photoUrl,
      avatarConfig: avatarConfig,
      isPrivate: isPrivate,
      workoutPreference: workoutPreference,
      beginnerFlag: beginnerFlag,
      trainingDaysPerWeek: trainingDaysPerWeek,
    );
  }
}

/// Avatar constants for profile setup.
class AvatarConstants {
  static const String _basePath = 'assets/avatars';

  /// Male avatar paths
  static const List<String> maleAvatars = [
    '$_basePath/male_avatar_1.png',
    '$_basePath/male_avatar_2.png',
    '$_basePath/male_avatar_3.png',
    '$_basePath/male_avatar_4.png',
    '$_basePath/male_avatar_5.png',
    '$_basePath/male_avatar_6.png',
    '$_basePath/male_avatar_7.png',
    '$_basePath/male_avatar_8.png',
    '$_basePath/male_avatar_9.png',
    '$_basePath/male_avatar_10.png',
  ];

  /// Female avatar paths
  static const List<String> femaleAvatars = [
    '$_basePath/female_avatar_1.png',
    '$_basePath/female_avatar_2.png',
    '$_basePath/female_avatar_3.png',
    '$_basePath/female_avatar_4.png',
    '$_basePath/female_avatar_5.png',
    '$_basePath/female_avatar_6.png',
    '$_basePath/female_avatar_7.png',
    '$_basePath/female_avatar_8.png',
    '$_basePath/female_avatar_9.png',
    '$_basePath/female_avatar_10.png',
  ];

  /// Get avatars by gender
  static List<String> getAvatarsByGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return maleAvatars;
      case 'female':
        return femaleAvatars;
      default:
        return [...maleAvatars, ...femaleAvatars];
    }
  }
}

/// Gender options for avatar selection
enum AvatarGender { male, female }

extension AvatarGenderExtension on AvatarGender {
  String get displayName {
    switch (this) {
      case AvatarGender.male:
        return 'Male';
      case AvatarGender.female:
        return 'Female';
    }
  }

  List<String> get avatars {
    switch (this) {
      case AvatarGender.male:
        return AvatarConstants.maleAvatars;
      case AvatarGender.female:
        return AvatarConstants.femaleAvatars;
    }
  }
}

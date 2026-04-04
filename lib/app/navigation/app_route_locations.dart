import '../../core/constants/constants.dart';

enum MainShellTab {
  feed('feed'),
  session('session'),
  social('social'),
  profile('profile');

  final String value;
  const MainShellTab(this.value);

  static MainShellTab fromString(String? value) {
    return MainShellTab.values.firstWhere(
      (tab) => tab.value == value,
      orElse: () => MainShellTab.feed,
    );
  }
}

enum SocialTab {
  buddies('buddies'),
  challenges('challenges'),
  leaderboard('leaderboard');

  final String value;
  const SocialTab(this.value);

  static SocialTab fromString(String? value) {
    return SocialTab.values.firstWhere(
      (tab) => tab.value == value,
      orElse: () => SocialTab.buddies,
    );
  }
}

class AppRouteLocations {
  static const String main = '/';

  static String mainTab(
    MainShellTab tab, {
    SocialTab? socialTab,
  }) {
    final queryParts = <String>[];
    if (tab != MainShellTab.feed) {
      queryParts.add('tab=${tab.value}');
    }
    if (tab == MainShellTab.social && socialTab != null) {
      queryParts.add('socialTab=${socialTab.value}');
    }

    if (queryParts.isEmpty) {
      return main;
    }

    return '$main?${queryParts.join('&')}';
  }

  static String gymSessionSetup(String sessionId) {
    return '/session/setup/$sessionId';
  }

  static String sessionRoom(
    String sessionId, {
    required String type,
    String? audioUrl,
  }) {
    final queryParts = <String>['type=$type'];
    if (audioUrl != null && audioUrl.isNotEmpty) {
      queryParts.add('audioUrl=$audioUrl');
    }

    return '/session/room/$sessionId?${queryParts.join('&')}';
  }

  static String sessionRecap(String sessionId) {
    return '/session/recap/$sessionId';
  }

  static String userFollowers(String userId) {
    return '/user/$userId/followers';
  }

  static String userFollowing(String userId) {
    return '/user/$userId/following';
  }

  static String sessionEntry({
    required String sessionId,
    required String type,
    required SessionPhase phase,
    String? audioUrl,
  }) {
    final workoutType = WorkoutType.fromString(type);
    if (workoutType == WorkoutType.gym && phase == SessionPhase.setup) {
      return gymSessionSetup(sessionId);
    }

    return sessionRoom(sessionId, type: type, audioUrl: audioUrl);
  }
}

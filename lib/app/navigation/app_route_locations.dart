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
  board('board'),
  buddies('buddies'),
  find('find');

  final String value;
  const SocialTab(this.value);

  static SocialTab fromString(String? value) {
    return SocialTab.values.firstWhere(
      (tab) => tab.value == value,
      orElse: () => SocialTab.board,
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

  static String matchmaking(WorkoutType type) {
    return Uri(
      path: '/session/matchmaking',
      queryParameters: {'type': type.value},
    ).toString();
  }

  static String gymSessionSetup(String sessionId) {
    return '/session/setup/$sessionId';
  }

  static String sessionRoom(
    String sessionId, {
    required String type,
    String? audioUrl,
  }) {
    final queryParameters = <String, String>{'type': type};
    if (audioUrl != null && audioUrl.isNotEmpty) {
      queryParameters['audioUrl'] = audioUrl;
    }

    return Uri(
      path: '/session/room/$sessionId',
      queryParameters: queryParameters,
    ).toString();
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

  static String sessionAccept(String sessionId) {
    return '/session/accept/$sessionId';
  }

  static String sessionEntry({
    required String sessionId,
    required String type,
    required SessionPhase phase,
    String? audioUrl,
  }) {
    if (type == WorkoutType.gym.value && phase == SessionPhase.setup) {
      return gymSessionSetup(sessionId);
    }
    return sessionRoom(sessionId, type: type, audioUrl: audioUrl);
  }
}

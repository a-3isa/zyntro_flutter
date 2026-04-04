import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/app/navigation/app_route_locations.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';

void main() {
  group('AppRouteLocations', () {
    test('builds main-shell tab routes with stable query params', () {
      expect(AppRouteLocations.mainTab(MainShellTab.feed), '/');
      expect(AppRouteLocations.mainTab(MainShellTab.session), '/?tab=session');
      expect(
        AppRouteLocations.mainTab(
          MainShellTab.social,
          socialTab: SocialTab.leaderboard,
        ),
        '/?tab=social&socialTab=leaderboard',
      );
    });

    test('routes gym setup sessions into setup before live room', () {
      expect(
        AppRouteLocations.sessionEntry(
          sessionId: 'session-1',
          type: WorkoutType.gym.value,
          phase: SessionPhase.setup,
        ),
        '/session/setup/session-1',
      );
      expect(
        AppRouteLocations.sessionEntry(
          sessionId: 'session-1',
          type: WorkoutType.running.value,
          phase: SessionPhase.live,
        ),
        '/session/room/session-1?type=running',
      );
      expect(
        AppRouteLocations.sessionEntry(
          sessionId: 'session-1',
          type: 'strength',
          phase: SessionPhase.live,
        ),
        '/session/room/session-1?type=strength',
      );
    });
  });
}

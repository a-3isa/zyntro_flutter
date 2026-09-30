import 'dart:io';

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
          socialTab: SocialTab.board,
        ),
        '/?tab=social&socialTab=board',
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

    test('does not encode session room audio urls into query parameters', () {
      final location = AppRouteLocations.sessionRoom(
        'session-1',
        type: WorkoutType.gym.value,
      );
      final locationsSource = File(
        'lib/app/navigation/app_route_locations.dart',
      ).readAsStringSync();

      final uri = Uri.parse(location);
      expect(uri.path, '/session/room/session-1');
      expect(uri.queryParameters['type'], WorkoutType.gym.value);
      expect(uri.queryParameters, isNot(contains('audioUrl')));
      expect(location, isNot(contains('token=a')));
      expect(locationsSource, isNot(contains("queryParameters['audioUrl']")));
    });

    test('session room route reads transient audio urls from extra only', () {
      final routerSource = File(
        'lib/app/navigation/app_router.dart',
      ).readAsStringSync();

      expect(routerSource, contains("extra?['audioUrl'] as String?"));
      expect(
        routerSource,
        isNot(contains("state.uri.queryParameters['audioUrl']")),
      );
    });
  });
}

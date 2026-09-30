import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/app/launch_intent.dart';
import 'package:zyntro_flutter/app/navigation/app_route_locations.dart';
import 'package:zyntro_flutter/app/navigation/app_router.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';
import 'package:zyntro_flutter/features/session/domain/resume_decision.dart';

/// Covers the start-up navigation itself: what the router does with a decision,
/// and the launch-intent guard that stops the redirect racing a notification
/// tap.
///
/// [resumeStartupLocation] is the real function the redirect closure calls, not
/// a re-implementation of it, so these cannot drift from production behaviour.
void main() {
  const sessionRoom = '/session/room/s1';

  group('start-up navigation', () {
    test('a warm decision goes straight to the session room', () {
      expect(
        resumeStartupLocation(
          decision: const ResumeRedirect('s1', 'gym'),
          decisionResolved: true,
          currentLocation: AppRoutes.splash,
        ),
        startsWith(sessionRoom),
      );
    });

    test('carries the workout type through, so the room opens the right view', () {
      final location = resumeStartupLocation(
        decision: const ResumeRedirect('s1', 'running'),
        decisionResolved: true,
        currentLocation: AppRoutes.splash,
      );

      expect(location, AppRouteLocations.sessionRoom('s1', type: 'running'));
    });

    test('nothing to resume lands on the normal home screen', () {
      expect(
        resumeStartupLocation(
          decision: const ResumeNone(),
          decisionResolved: true,
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.main,
      );
    });

    test('a quiet session lands on home — the prompt is not a navigation', () {
      expect(
        resumeStartupLocation(
          decision: const ResumePrompt('s1', 'gym'),
          decisionResolved: true,
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.main,
      );
    });

    test('an expiry notice lands on home — the notice is not a navigation', () {
      expect(
        resumeStartupLocation(
          decision: const ResumeExpiredNotice('s1'),
          decisionResolved: true,
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.main,
      );
    });
  });

  group('no intermediate home-screen flash', () {
    test('holds on splash while the decision is still resolving', () {
      // Returning main here and navigating afterwards would show the member the
      // home screen for a frame before yanking them into their session.
      expect(
        resumeStartupLocation(
          decision: null,
          decisionResolved: false,
          currentLocation: AppRoutes.splash,
        ),
        isNull,
        reason: 'already on splash — stay put rather than re-navigating',
      );
    });

    test('sends the member back to splash if they are anywhere else', () {
      expect(
        resumeStartupLocation(
          decision: null,
          decisionResolved: false,
          currentLocation: AppRoutes.login,
        ),
        AppRoutes.splash,
      );
    });

    test('resolving to a redirect is a single navigation, not two', () {
      // Unresolved holds; resolved goes straight to the room. The member never
      // passes through main on the way.
      expect(
        resumeStartupLocation(
          decision: null,
          decisionResolved: false,
          currentLocation: AppRoutes.splash,
        ),
        isNull,
      );
      expect(
        resumeStartupLocation(
          decision: const ResumeRedirect('s1', 'gym'),
          decisionResolved: true,
          currentLocation: AppRoutes.splash,
        ),
        isNot(AppRoutes.main),
      );
    });

    test('repeated cold starts each produce exactly one destination', () {
      // Killing and reopening the app several times in a row must land the
      // member in the same place each time, with no duplicate navigation.
      for (var i = 0; i < 3; i++) {
        expect(
          resumeStartupLocation(
            decision: const ResumeRedirect('s1', 'gym'),
            decisionResolved: true,
            currentLocation: AppRoutes.splash,
          ),
          AppRouteLocations.sessionRoom('s1', type: 'gym'),
        );
      }
    });
  });

  group('launch intent', () {
    setUp(() => LaunchIntent.instance.resetForTest());
    tearDown(() => LaunchIntent.instance.resetForTest());

    test('an unresolved launch does not claim an explicit destination', () {
      // Ordinary cold start must be allowed to resume. Notification taps are
      // recorded in main() before runApp, so this default is only the
      // pre-capture window.
      expect(LaunchIntent.instance.isResolved, isFalse);
      expect(LaunchIntent.instance.hasExplicitDestination, isFalse);
    });

    test('a launch with a notification payload has a destination', () {
      LaunchIntent.instance.hasExplicitDestination = true;
      expect(LaunchIntent.instance.hasExplicitDestination, isTrue);
      expect(LaunchIntent.instance.isResolved, isTrue);
    });

    test('an ordinary launch has none', () {
      LaunchIntent.instance.hasExplicitDestination = false;
      expect(LaunchIntent.instance.hasExplicitDestination, isFalse);
      expect(LaunchIntent.instance.isResolved, isTrue);
    });

    test('a notification tap suppresses an otherwise warm redirect', () {
      LaunchIntent.instance.hasExplicitDestination = true;

      final decision = resolveResumeDecision(
        candidate: ResumeCandidate(
          sessionId: 's1',
          workoutType: 'gym',
          phase: SessionPhase.live,
          status: SessionStatus.active,
          lastActivityAt: DateTime.utc(2026, 8, 5, 11, 59),
          expiresAt: DateTime.utc(2026, 8, 5, 14, 0),
          memberHasTerminated: false,
          otherParticipantPresent: false,
        ),
        now: DateTime.utc(2026, 8, 5, 12, 0),
        hasExplicitLaunchDestination:
            LaunchIntent.instance.hasExplicitDestination,
        resumeEnabled: true,
        expiryAlreadyNotified: false,
      );

      expect(decision, isA<ResumeNone>());
      expect(
        resumeStartupLocation(
          decision: decision,
          decisionResolved: true,
          currentLocation: AppRoutes.splash,
        ),
        AppRoutes.main,
        reason: 'the notification handler owns this launch, not resume',
      );
    });

    test('an unresolved launch still allows a warm redirect', () {
      // Capture happens in main() before runApp. If that has not run yet,
      // treating unknown as "no destination" lets a live session resume.
      final decision = resolveResumeDecision(
        candidate: ResumeCandidate(
          sessionId: 's1',
          workoutType: 'gym',
          phase: SessionPhase.live,
          status: SessionStatus.active,
          lastActivityAt: DateTime.utc(2026, 8, 5, 11, 59),
          expiresAt: DateTime.utc(2026, 8, 5, 14, 0),
          memberHasTerminated: false,
          otherParticipantPresent: false,
        ),
        now: DateTime.utc(2026, 8, 5, 12, 0),
        hasExplicitLaunchDestination:
            LaunchIntent.instance.hasExplicitDestination,
        resumeEnabled: true,
        expiryAlreadyNotified: false,
      );

      expect(decision, isA<ResumeRedirect>());
    });
  });
}

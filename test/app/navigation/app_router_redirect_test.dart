import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/app/navigation/app_router.dart';

// Mirrors the GoRouter redirect closure in app_router.dart so redirect
// logic can be verified without Firebase or widget-test overhead.
String? _computeRedirect({
  required bool isLoggedIn,
  required bool isLoading,
  required bool? isProfileComplete, // null = still loading
  required bool profileHasError,
  required bool rollbackActive,
  required String currentLocation,
  String? fromQuery,
}) {
  final isOnAuthPage = currentLocation == AppRoutes.login ||
      currentLocation == AppRoutes.signUp ||
      currentLocation == AppRoutes.splash ||
      currentLocation == AppRoutes.forgotPassword ||
      currentLocation == AppRoutes.onboarding;

  if (isLoading) {
    return currentLocation == AppRoutes.splash ? null : AppRoutes.splash;
  }

  if (!isLoggedIn && !isOnAuthPage) {
    return loginWithReturnTo(currentLocation);
  }

  if (rollbackActive && !isOnAuthPage) return AppRoutes.login;

  if (isLoggedIn) {
    if (profileHasError) {
      return currentLocation == AppRoutes.onboarding ||
              currentLocation == AppRoutes.profileSetup
          ? null
          : AppRoutes.onboarding;
    }

    // Profile check still loading
    if (isProfileComplete == null) return null;

    if (!isProfileComplete) {
      if (currentLocation != AppRoutes.onboarding &&
          currentLocation != AppRoutes.profileSetup) {
        return AppRoutes.onboarding;
      }
      return null;
    }

    // Profile complete — redirect off auth/onboarding pages to main,
    // or to a safe stashed deep link (Z-AUTH-007).
    if (currentLocation == AppRoutes.login ||
        currentLocation == AppRoutes.signUp ||
        currentLocation == AppRoutes.splash ||
        currentLocation == AppRoutes.onboarding ||
        currentLocation == AppRoutes.profileSetup) {
      final returnTo = safePostAuthReturnTo(fromQuery);
      if (returnTo != null) return returnTo;
      return AppRoutes.main;
    }
  }

  return null;
}

void main() {
  group('Startup session validation', () {
    test('restored authenticated session is signed out when profile is incomplete', () {
      expect(
        shouldSignOutStartupSession(
          isAuthenticated: true,
          profileCheckCompleted: true,
          isProfileComplete: false,
        ),
        isTrue,
      );
    });

    test('does not sign out before auth and profile validation finish', () {
      expect(
        shouldSignOutStartupSession(
          isAuthenticated: true,
          profileCheckCompleted: false,
          isProfileComplete: null,
        ),
        isFalse,
      );
    });
  });

  group('Router redirect — US2: returning user routing', () {
    // T016: regression — hasSeenOnboarding no longer drives routing; only
    // server-side isProfileComplete matters.
    test(
        'T016: logged-in user with complete profile reaches main '
        'regardless of hasSeenOnboarding (local flag removed)', () {
      final result = _computeRedirect(
        isLoggedIn: true,
        isLoading: false,
        isProfileComplete: true,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.splash,
      );

      expect(result, AppRoutes.main);
      expect(result, isNot(AppRoutes.onboarding));
    });

    // T017: regression — incomplete profile must go to /onboarding, not
    // /profile-setup (which was the old target).
    test(
        'T017: logged-in user with incomplete profile redirects to /onboarding, '
        'not /profile-setup', () {
      final result = _computeRedirect(
        isLoggedIn: true,
        isLoading: false,
        isProfileComplete: false,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.splash,
      );

      expect(result, AppRoutes.onboarding);
      expect(result, isNot(AppRoutes.profileSetup));
    });

    test(
        'logged-in user with complete profile on main stays on main '
        '(no redirect)', () {
      final result = _computeRedirect(
        isLoggedIn: true,
        isLoading: false,
        isProfileComplete: true,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.main,
      );

      expect(result, isNull);
    });
  });

  group('Router redirect — US3: incomplete profile recovery', () {
    // T019: a user with an incomplete profile who is on an arbitrary app page
    // (e.g., main) must be redirected to /onboarding, not /profile-setup.
    test(
        'T019: incomplete profile on arbitrary route redirects to '
        '/onboarding (not /profile-setup)', () {
      final result = _computeRedirect(
        isLoggedIn: true,
        isLoading: false,
        isProfileComplete: false,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.main,
      );

      expect(result, AppRoutes.onboarding);
      expect(result, isNot(AppRoutes.profileSetup));
    });

    // T020: a user on /profile-setup with an incomplete profile must NOT be
    // redirected (ProfileSetupPage stays reachable as legacy fallback).
    test(
        'T020: incomplete profile on /profile-setup returns null '
        '(no redirect loop)', () {
      final result = _computeRedirect(
        isLoggedIn: true,
        isLoading: false,
        isProfileComplete: false,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.profileSetup,
      );

      expect(result, isNull);
    });

    test(
        'incomplete profile already on /onboarding stays on /onboarding '
        '(no redirect loop)', () {
      final result = _computeRedirect(
        isLoggedIn: true,
        isLoading: false,
        isProfileComplete: false,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.onboarding,
      );

      expect(result, isNull);
    });
  });

  group('Router redirect — loading and unauthenticated states', () {
    test('loading state keeps user on splash', () {
      final result = _computeRedirect(
        isLoggedIn: false,
        isLoading: true,
        isProfileComplete: null,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.splash,
      );

      expect(result, isNull);
    });

    test('unauthenticated user on main redirects to login with from', () {
      final result = _computeRedirect(
        isLoggedIn: false,
        isLoading: false,
        isProfileComplete: null,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.main,
      );

      expect(result, loginWithReturnTo(AppRoutes.main));
      expect(result, contains(kPostAuthRedirectFrom));
    });
  });

  group('safePostAuthReturnTo (Z-AUTH-007)', () {
    test('restores a session deep link', () {
      expect(
        safePostAuthReturnTo(
          Uri.encodeComponent('/session/room/abc?type=gym'),
        ),
        '/session/room/abc?type=gym',
      );
    });

    test('rejects absolute and scheme-relative URLs', () {
      expect(safePostAuthReturnTo('https://evil.test/phish'), isNull);
      expect(safePostAuthReturnTo('//evil.test/phish'), isNull);
      expect(
        safePostAuthReturnTo(Uri.encodeComponent('https://evil.test')),
        isNull,
      );
    });

    test('rejects auth-entry pages', () {
      expect(safePostAuthReturnTo(Uri.encodeComponent(AppRoutes.login)), isNull);
      expect(
        safePostAuthReturnTo(Uri.encodeComponent(AppRoutes.onboarding)),
        isNull,
      );
    });

    test('post-login restore prefers from over main', () {
      final result = _computeRedirect(
        isLoggedIn: true,
        isLoading: false,
        isProfileComplete: true,
        profileHasError: false,
        rollbackActive: false,
        currentLocation: AppRoutes.login,
        fromQuery: Uri.encodeComponent('/session/room/xyz'),
      );
      expect(result, '/session/room/xyz');
    });
  });

  group('moderationQueueRedirect (Z-SOC-002)', () {
    test('non-moderator is sent home once the claim resolves', () {
      expect(
        moderationQueueRedirect(
          location: AppRoutes.moderationQueue,
          moderatorResolved: true,
          isModerator: false,
        ),
        AppRoutes.main,
      );
    });

    test('moderator may stay on the queue', () {
      expect(
        moderationQueueRedirect(
          location: AppRoutes.moderationQueue,
          moderatorResolved: true,
          isModerator: true,
        ),
        isNull,
      );
    });

    test('unresolved claim does not bounce yet', () {
      expect(
        moderationQueueRedirect(
          location: AppRoutes.moderationQueue,
          moderatorResolved: false,
          isModerator: false,
        ),
        isNull,
      );
    });

    test('other routes are untouched', () {
      expect(
        moderationQueueRedirect(
          location: AppRoutes.settings,
          moderatorResolved: true,
          isModerator: false,
        ),
        isNull,
      );
    });
  });
}

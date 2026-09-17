import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_route_locations.dart';
import '../app_runtime_config.dart';
import '../launch_intent.dart';
import '../../core/constants/constants.dart';
import '../../core/constants/feature_flags.dart';
import '../../features/session/domain/resume_decision.dart';
import '../../services/session_analytics_service.dart';
import '../../services/session_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/profile_setup_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/main/presentation/main_shell.dart';
import '../../features/session/presentation/start_session_page.dart';
import '../../features/session/presentation/gym_session_setup_page.dart';
import '../../features/session/presentation/matchmaking_page.dart';
import '../../features/session/presentation/session_room_page.dart';
import '../../features/session/presentation/recap_page.dart';
import '../../features/session/domain/gym_session_plan.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/notifications/presentation/notification_preferences_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/privacy_settings_page.dart';
import '../../features/settings/presentation/blocked_users_page.dart';
import '../../features/settings/presentation/community_guidelines_page.dart';
import '../../features/settings/presentation/terms_of_service_page.dart';
import '../../features/settings/presentation/privacy_policy_page.dart';
import '../../features/settings/presentation/change_password_page.dart';
import '../../features/settings/presentation/change_email_page.dart';
import '../../features/settings/presentation/delete_account_page.dart';
import '../../features/profile/presentation/follow_requests_page.dart';
import '../../features/profile/presentation/connections_list_page.dart';
import '../../features/profile/presentation/user_posts_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/workout_history_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/moderation/presentation/moderation_queue_page.dart';
import '../../features/feed/presentation/post_detail_page.dart';
import '../../features/session/presentation/joint_post_page.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/domain/entities/auth_user_entity.dart';

/// Route names for type-safe navigation.
class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const signUp = '/signup';
  static const onboarding = '/onboarding';
  static const profileSetup = '/profile-setup';
  static const forgotPassword = '/forgot-password';
  static const main = '/';
  static const startSession = '/session/start';
  static const matchmaking = '/session/matchmaking';
  static const gymSessionSetup = '/session/setup/:sessionId';
  static const sessionRoom = '/session/room/:sessionId';
  static const recap = '/session/recap/:sessionId';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const notificationPreferences = '/notifications/preferences';
  static const userProfile = '/user/:userId';
  static const postDetail = '/post/:postId';
  static const jointPostComposer = '/joint-post/:postId';

  // Privacy & moderation routes
  static const privacySettings = '/settings/privacy';
  static const followRequests = '/profile/follow-requests';
  static const blockedUsers = '/settings/blocked-users';
  static const moderationQueue = '/moderation/queue';
  static const communityGuidelines = '/settings/guidelines';
  static const termsOfService = '/settings/terms';
  static const privacyPolicy = '/settings/privacy-policy';

  // Account management routes
  static const changePassword = '/settings/change-password';
  static const changeEmail = '/settings/change-email';
  static const deleteAccount = '/settings/delete-account';

  // Profile routes
  static const userPosts = '/user/:userId/posts';
  static const userFollowers = '/user/:userId/followers';
  static const userFollowing = '/user/:userId/following';
  static const editProfile = '/profile/edit';
  static const workoutHistory = '/profile/workout-history';
}

/// Navigation key for accessing navigator state.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Custom page transition with fade + slide animation.
/// Respects accessibility settings for reduced motion.
CustomTransitionPage<T> buildPremiumPageTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.normal,
    reverseTransitionDuration: AppDurations.normal,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Respect reduced motion accessibility settings
      final bool reduceMotion = MediaQuery.of(context).disableAnimations;

      if (reduceMotion) {
        // Instant transition for reduced motion
        return FadeTransition(
          opacity: animation.drive(
            Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.linear)),
          ),
          child: child,
        );
      }

      // Premium fade + slide transition
      final fadeAnimation = animation.drive(
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: AppCurves.premium)),
      );

      final slideAnimation = animation.drive(
        Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: AppCurves.premium)),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(position: slideAnimation, child: child),
      );
    },
  );
}

/// Custom modal page transition with slide up animation.
CustomTransitionPage<T> buildModalPageTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.normal,
    reverseTransitionDuration: AppDurations.normal,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final bool reduceMotion = MediaQuery.of(context).disableAnimations;

      if (reduceMotion) {
        return FadeTransition(opacity: animation, child: child);
      }

      final slideAnimation = animation.drive(
        Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).chain(CurveTween(curve: AppCurves.premium)),
      );

      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slideAnimation, child: child),
      );
    },
  );
}

/// Simple slide-from-right page transition (280 ms, AppCurves.premium).
CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: AppCurves.premium)),
        child: child,
      );
    },
    child: child,
  );
}

/// Resolves, once per cold start, what to do about a session the member may
/// still be in.
///
/// One-shot on purpose. The router re-evaluates its redirect on every auth
/// event via [authChangeNotifier]; if this were recomputed each time, an
/// ordinary token refresh would re-fire the redirect and yank a member back
/// into a session they had already moved on from. Resolved during the splash
/// hold the router already performs, so it costs no extra frame.
final resumeDecisionProvider = FutureProvider<ResumeDecision>((ref) async {
  final user = ref.watch(authSessionProvider).value;
  if (user == null) return const ResumeNone();

  // A launch that already has a destination outranks resuming — see
  // LaunchIntent for why this is read rather than synchronised.
  final launchIntent = ref.watch(launchIntentProvider);

  // Kill switch. Reading it must never block start-up, so a failure degrades to
  // the compile-time default rather than propagating.
  final resumeEnabled = await ref
      .watch(resumeActiveSessionEnabledProvider.future)
      .catchError((_) => FeatureFlags.isResumeActiveSessionEnabledByDefault);

  final candidate = await ref
      .read(sessionServiceProvider)
      .findResumableSession(user.id);

  final decision = resolveResumeDecision(
    candidate: candidate,
    now: DateTime.now().toUtc(),
    hasExplicitLaunchDestination: launchIntent.hasExplicitDestination,
    resumeEnabled: resumeEnabled,
    // The landing screen owns the notice, and marks it seen when it shows it.
    expiryAlreadyNotified: false,
  );

  if (decision is ResumeRedirect) {
    unawaited(
      ref
          .read(sessionAnalyticsServiceProvider)
          .trackResumeEvent(
            ResumeSessionAnalyticsEvent.redirect,
            sessionId: decision.sessionId,
          ),
    );
  }

  return decision;
});

/// Redirect non-moderators away from the moderation queue (Z-SOC-002).
///
/// While the moderator flag is still loading, stay on the route (null) so we
/// do not bounce a real moderator to home before their claim resolves.
String? moderationQueueRedirect({
  required String location,
  required bool moderatorResolved,
  required bool isModerator,
  String fallback = AppRoutes.main,
}) {
  if (location != AppRoutes.moderationQueue) return null;
  if (!moderatorResolved) return null;
  if (!isModerator) return fallback;
  return null;
}

/// Where an authenticated, onboarded member should land at start-up, given the
/// resume decision.
///
/// Extracted from the redirect closure so it can be tested against the real
/// implementation. The rest of this file's redirect logic is covered by a test
/// that re-implements it, which cannot catch drift between the copy and the
/// original; this branch does not have that problem.
///
/// Only called once auth and onboarding have already settled, so it never has
/// to reason about either.
String? resumeStartupLocation({
  required ResumeDecision? decision,
  required bool decisionResolved,
  required String currentLocation,
}) {
  // Hold on splash until the decision is in. Returning `main` here and
  // navigating afterwards would show the member the home screen for a frame
  // before yanking them into their session.
  if (!decisionResolved) {
    return currentLocation == AppRoutes.splash ? null : AppRoutes.splash;
  }

  if (decision is ResumeRedirect) {
    return AppRouteLocations.sessionRoom(
      decision.sessionId,
      type: decision.workoutType,
    );
  }

  // A prompt or an expiry notice is not a navigation — the landing screen
  // surfaces both, so the member still lands on main.
  return AppRoutes.main;
}

/// GoRouter provider with auth-based redirects and premium transitions.
/// The router is created once and re-evaluates its redirect via [refreshListenable]
/// when auth state changes, preventing the GoRouter rebuild that caused a
/// splash-frame flash on every auth event.
final routerProvider = Provider<GoRouter>((ref) {
  // Mutable closure vars updated by ref.listen — the redirect callback always
  // reads current values without the GoRouter being recreated.
  var authState = const AsyncValue<AuthUserEntity?>.loading();
  var profileComplete = const AsyncValue<bool>.loading();
  var rollbackActive = const AsyncValue<bool>.data(false);
  var isModerator = false;
  var moderatorResolved = false;

  // Validate restored sessions before allowing startup navigation.
  var startupProfileCheckDone = false;
  var signingOut = false;

  // Latched once per process start, exactly like startupProfileCheckDone below.
  // Recomputing it on refreshListenable ticks would re-fire the redirect on
  // ordinary auth events.
  ResumeDecision? resumeDecision;
  var resumeDecisionDone = false;

  ref.listen<AsyncValue<ResumeDecision>>(resumeDecisionProvider, (_, next) {
    if (resumeDecisionDone) return;
    if (next.hasValue) {
      resumeDecision = next.value;
      resumeDecisionDone = true;
    } else if (next.hasError) {
      // Never block start-up on this. Falling through to the landing screen is
      // the correct failure mode (FR-016).
      resumeDecision = const ResumeNone();
      resumeDecisionDone = true;
    }
    authChangeNotifier.trigger();
  });

  ref.listen<AsyncValue<AuthUserEntity?>>(authSessionProvider, (_, next) {
    authState = next;
    authChangeNotifier.trigger();
  });
  ref.listen<AsyncValue<bool>>(authProfileCompletionProvider, (_, next) {
    profileComplete = next;
    authChangeNotifier.trigger();
  });
  ref.listen<AsyncValue<bool>>(authMigrationRollbackActiveProvider, (_, next) {
    rollbackActive = next;
    authChangeNotifier.trigger();
  });
  ref.listen<AsyncValue<bool>>(isModeratorProvider, (_, next) {
    if (next.hasValue) {
      isModerator = next.value ?? false;
      moderatorResolved = true;
    } else if (next.hasError) {
      isModerator = false;
      moderatorResolved = true;
    }
    authChangeNotifier.trigger();
  });
  ref.listen<AsyncValue<bool?>>(authStartupProfileCompletionProvider, (
    _,
    next,
  ) {
    if (!startupProfileCheckDone && next.hasError) {
      startupProfileCheckDone = true;
    } else if (!startupProfileCheckDone && next.hasValue) {
      startupProfileCheckDone = true;
      if (shouldSignOutStartupSession(
        isAuthenticated: next.value != null,
        profileCheckCompleted: next.hasValue,
        isProfileComplete: next.value,
      )) {
        signingOut = true;
        ref.read(authenticationUseCaseProvider).signOut().whenComplete(() {
          signingOut = false;
          authChangeNotifier.trigger();
        });
      }
    }
    authChangeNotifier.trigger();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: authChangeNotifier,
    debugLogDiagnostics: shouldEnableRouterDiagnostics(isDebugMode: kDebugMode),
    redirect: (context, state) {
      // Hold on splash while an incomplete restored session is signed out.
      if (signingOut) {
        return state.matchedLocation == AppRoutes.splash
            ? null
            : AppRoutes.splash;
      }

      final isLoggedIn = authState.value != null;
      final isLoading = authState.isLoading;
      final isRollbackActive = rollbackActive.value ?? false;

      final loc = state.matchedLocation;
      // Entry pages a logged-out user may sit on. Onboarding is intentionally
      // excluded — it requires an authenticated session.
      final isOnAuthEntry =
          loc == AppRoutes.login ||
          loc == AppRoutes.signUp ||
          loc == AppRoutes.splash ||
          loc == AppRoutes.forgotPassword;
      final isOnSetup =
          loc == AppRoutes.onboarding || loc == AppRoutes.profileSetup;

      // Still loading auth state → hold on splash.
      if (isLoading) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (isLoggedIn && !startupProfileCheckDone) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Not logged in: only auth-entry pages are reachable.
      if (!isLoggedIn) {
        return isOnAuthEntry ? null : AppRoutes.login;
      }

      // Guardrail: if a migration rollback is active, keep on auth-entry routes.
      if (isRollbackActive) {
        return isOnAuthEntry ? null : AppRoutes.login;
      }

      // Logged in. Resolve profile completeness (treat an error as incomplete).
      final hasCompletionError = profileComplete.hasError;
      if (!hasCompletionError &&
          (profileComplete.isLoading || !profileComplete.hasValue)) {
        return null; // wait for the check before deciding
      }
      final isProfileComplete =
          !hasCompletionError && (profileComplete.value ?? false);

      if (isProfileComplete) {
        final moderationRedirect = moderationQueueRedirect(
          location: loc,
          moderatorResolved: moderatorResolved,
          isModerator: isModerator,
        );
        if (moderationRedirect != null) return moderationRedirect;

        // Returning, set-up users go straight to the app (home/feed) — unless
        // they left a workout running. Placed here so authentication and
        // onboarding are already settled: a member is never pulled into a
        // session ahead of signing in or finishing setup.
        if (isOnAuthEntry || isOnSetup) {
          return resumeStartupLocation(
            decision: resumeDecision,
            decisionResolved: resumeDecisionDone,
            currentLocation: loc,
          );
        }
        return null;
      }

      // Signed in but hasn't finished onboarding → profile setup. First-time
      // users can't skip it (onboarding also blocks back navigation).
      return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    },
    routes: [
      // Auth flow routes
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _slidePage(state, const SplashPage()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const SignUpPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const OnboardingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const ProfileSetupPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => buildModalPageTransition(
          context: context,
          state: state,
          child: const ForgotPasswordPage(),
        ),
      ),

      // Main app with bottom navigation
      GoRoute(
        path: AppRoutes.main,
        builder: (context, state) {
          final initialTab = MainShellTab.fromString(
            state.uri.queryParameters['tab'],
          );
          final initialSocialTab = SocialTab.fromString(
            state.uri.queryParameters['socialTab'],
          );

          return MainShell(
            initialTab: initialTab,
            initialSocialTab: initialSocialTab,
          );
        },
      ),

      // Notifications
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const NotificationsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notificationPreferences,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const NotificationPreferencesPage(),
        ),
      ),

      // Session flow
      GoRoute(
        path: AppRoutes.startSession,
        pageBuilder: (context, state) => buildModalPageTransition(
          context: context,
          state: state,
          child: const StartSessionPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.matchmaking,
        pageBuilder: (context, state) {
          final type = WorkoutType.fromString(
            state.uri.queryParameters['type'] ?? WorkoutType.gym.value,
          );
          return buildModalPageTransition(
            context: context,
            state: state,
            child: MatchmakingPage(workoutType: type),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.gymSessionSetup,
        pageBuilder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          final extra = state.extra as Map<String, dynamic>?;
          final seededExercises = extra?['seededExercises'] as List<dynamic>?;

          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: GymSessionSetupPage(
              sessionId: sessionId,
              seededExercises: seededExercises?.cast<PlannedExercise>(),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sessionRoom,
        pageBuilder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          final type = state.uri.queryParameters['type'] ?? 'strength';
          final extra = state.extra as Map<String, dynamic>?;
          final initialAudioUrl =
              extra?['initialAudioUrl'] as String? ??
              extra?['audioUrl'] as String?;
          final plannedExercises =
              (extra?['plannedExercises'] as List<dynamic>?)
                  ?.cast<PlannedExercise>();

          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: SessionRoomPage(
              sessionId: sessionId,
              type: type,
              initialAudioUrl: initialAudioUrl,
              plannedExercises: plannedExercises,
            ),
          );
        },
      ),
      GoRoute(
        path: '/session/recap/:sessionId',
        pageBuilder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: RecapPage(sessionId: sessionId),
          );
        },
      ),

      // Settings
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const SettingsPage(),
        ),
      ),

      // Privacy & Moderation routes
      GoRoute(
        path: AppRoutes.privacySettings,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const PrivacySettingsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.followRequests,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const FollowRequestsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.blockedUsers,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const BlockedUsersPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.moderationQueue,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const ModerationQueuePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.communityGuidelines,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const CommunityGuidelinesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const TermsOfServicePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const PrivacyPolicyPage(),
        ),
      ),

      // Account management routes
      GoRoute(
        path: AppRoutes.changePassword,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.changeEmail,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const ChangeEmailPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const DeleteAccountPage(),
        ),
      ),

      // Joint post composer (invited partner completing a joint draft)
      GoRoute(
        path: '/joint-post/:postId',
        pageBuilder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: JointPostPage(postId: postId),
          );
        },
      ),

      // Post detail
      GoRoute(
        path: '/post/:postId',
        pageBuilder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: PostDetailPage(postId: postId),
          );
        },
      ),

      // Profile routes
      GoRoute(
        path: '/user/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: ProfilePage(userId: userId),
          );
        },
      ),
      GoRoute(
        path: '/user/:userId/posts',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: UserPostsPage(userId: userId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.userFollowers,
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: ConnectionsListPage(
              userId: userId,
              kind: ConnectionsListKind.followers,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.userFollowing,
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: ConnectionsListPage(
              userId: userId,
              kind: ConnectionsListKind.following,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const EditProfilePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.workoutHistory,
        pageBuilder: (context, state) => buildPremiumPageTransition(
          context: context,
          state: state,
          child: const WorkoutHistoryPage(),
        ),
      ),
    ],
  );
});

/// Notifier used as GoRouter.refreshListenable so the router re-evaluates
/// its redirect without recreating the GoRouter instance on every auth event.
class _AuthChangeNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
}

final authChangeNotifier = _AuthChangeNotifier();

bool shouldSignOutStartupSession({
  required bool isAuthenticated,
  required bool profileCheckCompleted,
  required bool? isProfileComplete,
}) {
  return isAuthenticated && profileCheckCompleted && isProfileComplete == false;
}

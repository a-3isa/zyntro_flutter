import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_route_locations.dart';
import '../app_runtime_config.dart';
import '../../core/constants/constants.dart';
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
import '../../features/session/presentation/session_invite_acceptance_page.dart';
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
import '../../features/auth/auth_providers.dart';
import '../../services/storage_service.dart';

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
  static const sessionAccept = '/session/accept/:sessionId';
  static const gymSessionSetup = '/session/setup/:sessionId';
  static const sessionRoom = '/session/room/:sessionId';
  static const recap = '/session/recap/:sessionId';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const notificationPreferences = '/notifications/preferences';
  static const userProfile = '/user/:userId';
  static const postDetail = '/post/:postId';

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

/// GoRouter provider with auth-based redirects and premium transitions.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authSessionProvider);
  final profileCompleteAsync = ref.watch(authProfileCompletionProvider);
  final rollbackActiveAsync = ref.watch(authMigrationRollbackActiveProvider);
  final storageService = ref.watch(storageServiceProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: shouldEnableRouterDiagnostics(isDebugMode: kDebugMode),
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading;
      final rollbackActive = rollbackActiveAsync.valueOrNull ?? false;
      final isOnAuthPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signUp ||
          state.matchedLocation == AppRoutes.splash ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.onboarding;

      // Still loading auth state
      if (isLoading) {
        return state.matchedLocation == AppRoutes.splash
            ? null
            : AppRoutes.splash;
      }

      // Not logged in, redirect to login
      if (!isLoggedIn && !isOnAuthPage) {
        return AppRoutes.login;
      }

      // Guardrail: if rollback is active, keep navigation on auth entry routes.
      if (rollbackActive && !isOnAuthPage) {
        return AppRoutes.login;
      }

      // Logged in but on auth page, go to main
      // Logged in but on auth page, go to main or profile setup
      if (isLoggedIn) {
        // Check if user has seen onboarding
        if (!storageService.hasSeenOnboarding) {
          if (state.matchedLocation != AppRoutes.onboarding) {
            return AppRoutes.onboarding;
          }
          return null;
        }

        if (profileCompleteAsync.hasError) {
          debugPrint(
            '[Router] Profile completion check failed; routing to profile setup.',
          );
          return state.matchedLocation == AppRoutes.profileSetup
              ? null
              : AppRoutes.profileSetup;
        }

        // If profile completion check is still loading, don't redirect yet
        if (profileCompleteAsync.isLoading || !profileCompleteAsync.hasValue) {
          return null;
        }

        final isProfileComplete = profileCompleteAsync.valueOrNull ?? false;

        if (!isProfileComplete) {
          // Determine where they can go if profile is incomplete
          // Allowed: Onboarding, ProfileSetup
          if (state.matchedLocation != AppRoutes.onboarding &&
              state.matchedLocation != AppRoutes.profileSetup) {
            return AppRoutes.profileSetup;
          }
          return null; // Stay where they are (Onboarding or ProfileSetup)
        }

        if (state.matchedLocation == AppRoutes.login ||
            state.matchedLocation == AppRoutes.signUp ||
            state.matchedLocation == AppRoutes.splash ||
            state.matchedLocation == AppRoutes.onboarding ||
            state.matchedLocation == AppRoutes.profileSetup) {
          return AppRoutes.main;
        }
      }

      return null;
    },
    routes: [
      // Auth flow routes
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
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
        path: AppRoutes.sessionAccept,
        pageBuilder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return buildModalPageTransition(
            context: context,
            state: state,
            child: SessionInviteAcceptancePage(
              sessionId: sessionId,
              notificationData: extra,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.startSession,
        pageBuilder: (context, state) {
          final initialType = WorkoutType.fromString(
            state.uri.queryParameters['type'] ?? WorkoutType.gym.value,
          );

          return buildModalPageTransition(
            context: context,
            state: state,
            child: StartSessionPage(initialType: initialType),
          );
        },
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
              state.uri.queryParameters['audioUrl'];

          return buildPremiumPageTransition(
            context: context,
            state: state,
            child: SessionRoomPage(
              sessionId: sessionId,
              type: type,
              initialAudioUrl: initialAudioUrl,
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

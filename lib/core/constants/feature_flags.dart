/// Feature Flags Configuration
///
/// This file controls the availability of features in the application using a
/// feature flag system. It allows us to manage the rollout of features for
/// the MVP (Minimum Viable Product) release and beyond.
///
/// MVP Strategy:
/// - Core features (Auth, Sessions, Feed) are ENABLED to provide immediate value.
/// - Advanced features (Challenges, Leaderboard, Payments, etc.) are DISABLED
///   to focus development and testing on the core experience.
/// - Disabled features are visible in the UI but show a "Coming Soon" dialog
///   when interacted with, maintaining the app structure while setting expectations.
///
/// Usage:
/// To enable a feature post-MVP or for testing:
/// 1. Locate the corresponding getter in [FeatureFlags].
/// 2. Change the return value from `false` to `true`.
///
/// Example:
/// To enable challenges:
/// ```dart
/// static bool get isChallengesEnabled => true;
/// ```
///
/// To check a flag in code using [MVPFeatureWrapper]:
/// ```dart
/// MVPFeatureWrapper(
///   feature: FeatureFlag.challenges,
///   featureName: 'Challenges',
///   child: ChallengeButton(),
/// )
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Enumeration of all controllable features in the application.
enum FeatureFlag {
  auth,
  sessions,
  feed,
  isLocalLeaderboardEnabled,
  challenges,
  leaderboard,
  payments,
  advancedAnalytics,
  pairedFriendSessions,
  challengeInvites,
  comments,
  // Security features (MVP Coming Soon)
  activeSessions,
  twoFactorAuth,
  loginHistory,
}

final pairedFriendSessionsEnabledProvider = Provider<bool>(
  (ref) => FeatureFlags.isPairedFriendSessionsEnabled,
);

/// Static feature configuration class.
class FeatureFlags {
  // ===========================================================================
  // ENABLED FEATURES (MVP Scope)
  // ===========================================================================

  /// Authentication and user profile management.
  /// [MVP Status] ENABLED: Core feature.
  static bool get isAuthEnabled => true;

  /// Workout sessions and tracking.
  /// [MVP Status] ENABLED: Core feature.
  static bool get isSessionsEnabled => true;

  /// Social feed and activity updates.
  /// [MVP Status] ENABLED: Core feature.
  static bool get isFeedEnabled => true;

  /// Local leaderboard for friends.
  ///
  /// [MVP Status] ENABLED: Core feature for social engagement.
  static bool get isLocalLeaderboardEnabled => true;

  // ===========================================================================
  // DISABLED FEATURES (Post-MVP / In Development)
  // ===========================================================================

  /// User challenges and competitions.
  static bool get isChallengesEnabled => false;

  /// Global and friend leaderboards.
  static bool get isLeaderboardEnabled => false;

  /// Premium subscriptions and payments.
  static bool get isPaymentsEnabled => false;

  /// Detailed workout analytics and insights.
  static bool get isAdvancedAnalyticsEnabled => false;

  /// One-to-one bot/friend workout sessions.
  static bool get isPairedFriendSessionsEnabled => true;

  /// Sending invites for challenges.
  static bool get isChallengeInvitesEnabled => false;

  /// Post comments and discussions.
  static bool get isCommentsEnabled => false;

  /// Active sessions management.
  static bool get isActiveSessionsEnabled => false;

  /// Two-factor authentication.
  static bool get isTwoFactorAuthEnabled => false;

  /// Login history tracking.
  static bool get isLoginHistoryEnabled => false;

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// Checks if a specific [feature] is currently enabled.
  static bool isFeatureEnabled(FeatureFlag feature) {
    switch (feature) {
      case FeatureFlag.auth:
        return isAuthEnabled;
      case FeatureFlag.sessions:
        return isSessionsEnabled;
      case FeatureFlag.feed:
        return isFeedEnabled;
      case FeatureFlag.isLocalLeaderboardEnabled:
        return isLocalLeaderboardEnabled;
      case FeatureFlag.challenges:
        return isChallengesEnabled;
      case FeatureFlag.leaderboard:
        return isLeaderboardEnabled;
      case FeatureFlag.payments:
        return isPaymentsEnabled;
      case FeatureFlag.advancedAnalytics:
        return isAdvancedAnalyticsEnabled;
      case FeatureFlag.pairedFriendSessions:
        return isPairedFriendSessionsEnabled;
      case FeatureFlag.challengeInvites:
        return isChallengeInvitesEnabled;
      case FeatureFlag.comments:
        return isCommentsEnabled;
      case FeatureFlag.activeSessions:
        return isActiveSessionsEnabled;
      case FeatureFlag.twoFactorAuth:
        return isTwoFactorAuthEnabled;
      case FeatureFlag.loginHistory:
        return isLoginHistoryEnabled;
    }
  }
}

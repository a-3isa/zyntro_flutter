import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:avatar_plus/avatar_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/constants/constants.dart';
import '../../../app/navigation/app_router.dart';
import '../../../services/user_service.dart';
import '../../../services/moderation_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/post_service.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/streak_card.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/premium_animations.dart';
import '../../moderation/presentation/report_dialog.dart';
import '../../../widgets/responsive_center.dart';
import '../../auth/auth_providers.dart';
import '../../auth/domain/entities/user_profile_entity.dart';
import '../../auth/presentation/providers/auth_controller.dart';

User _toLegacyUser(UserProfileEntity profile) {
  return User(
    id: profile.id,
    displayName: profile.displayName,
    photoURL: profile.photoUrl,
    avatarConfig: profile.avatarConfig,
    isPrivate: profile.isPrivate,
    workoutPreference: profile.workoutPreference,
    beginnerFlag: profile.beginnerFlag,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/// Provider to fetch another user's profile by ID.
final otherUserProfileProvider = FutureProvider.family<User?, String>((
  ref,
  userId,
) async {
  final profile = await ref.read(authControllerProvider).getUserProfile(userId);
  if (profile == null) return null;
  return _toLegacyUser(profile);
});

final currentUserProfileProvider = FutureProvider<User?>((ref) async {
  final authState = ref.watch(authSessionProvider);
  final uid = authState.valueOrNull?.id;
  if (uid == null) return null;
  final profile = await ref.read(authControllerProvider).getUserProfile(uid);
  if (profile == null) return null;
  return _toLegacyUser(profile);
});

/// Provider for followers count.
final followersCountProvider = FutureProvider.family<int, String>((
  ref,
  userId,
) async {
  return ref.read(followServiceProvider).getFollowersCount(userId);
});

/// Provider for following count.
final followingCountProvider = FutureProvider.family<int, String>((
  ref,
  userId,
) async {
  return ref.read(followServiceProvider).getFollowingCount(userId);
});

/// Provider for follow status between current user and target user.
final followStatusProvider = FutureProvider.family<FollowStatus?, String>((
  ref,
  targetUserId,
) async {
  final authState = ref.watch(authSessionProvider);
  final currentUserId = authState.valueOrNull?.id;
  if (currentUserId == null || currentUserId == targetUserId) return null;
  return ref
      .read(followServiceProvider)
      .getFollowStatus(currentUserId, targetUserId);
});

/// Profile page showing user stats and settings.
/// Updated to use real Firestore data and support viewing other users.
class ProfilePage extends ConsumerStatefulWidget {
  final String? userId;

  const ProfilePage({super.key, this.userId});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isFollowLoading = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    final firebaseUser = authState.valueOrNull;

    final targetUserId = widget.userId ?? currentUserId;
    final isCurrentUser = targetUserId == currentUserId;

    final AsyncValue<User?> userProfileAsync;
    if (widget.userId != null) {
      userProfileAsync = ref.watch(otherUserProfileProvider(widget.userId!));
    } else {
      userProfileAsync = ref.watch(currentUserProfileProvider);
    }

    return Scaffold(
      // extendBodyBehindAppBar: true,
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        centerTitle: true,
        leading: (!isCurrentUser && widget.userId != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // const Text(
            //   ,
            //   style: TextStyle(
            //     fontSize: 20,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.white,
            //   ),
            // ),
            if (isCurrentUser &&
                firebaseUser != null &&
                !firebaseUser.emailVerified) ...[
              const SizedBox(width: 8),
              ScaleOnTap(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ref
                      .read(authControllerProvider)
                      .sendEmailVerification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Verification email sent!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                child: Tooltip(
                  message: 'Verify your email',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.warning, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.priority_high_rounded,
                      color: AppColors.warning,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  // gradient: LinearGradient(
                  //   colors: [
                  //     AppColors.surfaceSecondaryDark,
                  //     AppColors.surfaceSecondaryDark.withValues(alpha: 0.8),
                  //   ],
                  // ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: ScaleOnTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push(AppRoutes.settings);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.settings_outlined,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
              ),
            )
          else if (targetUserId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceSecondaryDark,
                      AppColors.surfaceSecondaryDark.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                  onSelected: (value) =>
                      _handleAction(context, ref, value, targetUserId),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Report User'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Block User',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
      body: userProfileAsync.when(
        data: (user) {
          if (user == null || targetUserId == null) {
            return const Center(child: Text('User not found'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (isCurrentUser) {
                ref.invalidate(currentUserProfileProvider);
              }
              if (widget.userId != null) {
                ref.invalidate(otherUserProfileProvider(widget.userId!));
              }
              ref.invalidate(userStreakProvider(targetUserId));
              ref.invalidate(userBadgesProvider(targetUserId));
              ref.invalidate(userPostsProvider(targetUserId));
              ref.invalidate(followersCountProvider(targetUserId));
              ref.invalidate(followingCountProvider(targetUserId));
              if (!isCurrentUser) {
                ref.invalidate(followStatusProvider(targetUserId));
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ResponsiveCenter(
                padding: EdgeInsets.only(top: 20),
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    // Profile header with privacy indicator
                    SlideInAnimation.fromBottom(
                      index: 0,
                      child: _buildProfileHeader(user, isCurrentUser),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Follow/Unfollow button (for other users)
                    if (!isCurrentUser)
                      SlideInAnimation.fromBottom(
                        index: 1,
                        child: _buildFollowButton(targetUserId, user.isPrivate),
                      ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Enhanced stats row (streak, followers, following, posts)
                    SlideInAnimation.fromBottom(
                      index: 2,
                      child: _buildEnhancedStats(
                        ref,
                        targetUserId,
                        isCurrentUser,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Badges from userService
                    SlideInAnimation.fromBottom(
                      index: 3,
                      child: _buildBadgesSection(ref, targetUserId),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Posts section
                    SlideInAnimation.fromBottom(
                      index: 4,
                      child: _buildPostsSection(
                        ref,
                        targetUserId,
                        user.isPrivate,
                        isCurrentUser,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => ShimmerLoading(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                // Avatar skeleton
                ShimmerSkeleton.circle(size: 110),
                const SizedBox(height: AppSpacing.lg),
                ShimmerSkeleton.text(width: 150, height: 24),
                const SizedBox(height: AppSpacing.sm),
                ShimmerSkeleton.text(width: 100, height: 16),
                const SizedBox(height: AppSpacing.xxl),
                // Stats skeleton
                const ShimmerSkeleton(height: 100),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    4,
                    (_) => Column(
                      children: [
                        ShimmerSkeleton.text(width: 40, height: 24),
                        const SizedBox(height: 4),
                        ShimmerSkeleton.text(width: 60, height: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Badges skeleton
                const ShimmerSkeleton(height: 80),
              ],
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Error: $e'),
              const SizedBox(height: AppSpacing.md),
              BounceAnimation(
                onTap: () {
                  if (isCurrentUser) {
                    ref.invalidate(currentUserProfileProvider);
                  } else if (targetUserId != null) {
                    ref.invalidate(otherUserProfileProvider(targetUserId));
                  }
                },
                child: ElevatedButton(
                  onPressed: () {
                    if (isCurrentUser) {
                      ref.invalidate(currentUserProfileProvider);
                    } else if (targetUserId != null) {
                      ref.invalidate(otherUserProfileProvider(targetUserId));
                    }
                  },
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user, bool isCurrentUser) {
    return Column(
      children: [
        // Avatar with pulsing glow
        PulsingGlow(
          glowColor: AppColors.primary.withValues(alpha: 0.5),
          minRadius: 20,
          maxRadius: 30,
          child: GlowContainer(
            glowColor: AppColors.primaryGlow,
            blurRadius: 25,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceDark,
                ),
                padding: const EdgeInsets.all(3),
                child: Hero(
                  tag: 'avatar_${user.id}',
                  child: ClipOval(
                    child: user.photoURL != null && user.photoURL!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.photoURL!,
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                          )
                        : (user.avatarConfig != null &&
                              user.avatarConfig!.isNotEmpty)
                        ? AvatarPlus(
                            user.avatarConfig!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 100,
                            height: 100,
                            color: AppColors.surfaceSecondaryDark,
                            child: Center(
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user.displayName,
              style: const TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            if (!isCurrentUser && user.isPrivate) ...[
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: 'Private account',
                child: Icon(
                  Icons.lock,
                  size: 16,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.primaryGradient),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.workoutPreference.value.toUpperCase(),
            style: const TextStyle(
              fontSize: AppFontSize.xs,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(String targetUserId, bool isTargetPrivate) {
    final followStatusAsync = ref.watch(followStatusProvider(targetUserId));

    return followStatusAsync.when(
      data: (status) {
        String buttonText;
        bool isPrimary;
        VoidCallback? onPressed;

        if (status == null) {
          // Not following
          buttonText = 'Follow';
          isPrimary = true;
          onPressed = () => _handleFollow(targetUserId, isTargetPrivate);
        } else if (status == FollowStatus.pending) {
          buttonText = 'Requested';
          isPrimary = false;
          onPressed = null; // Disabled
        } else if (status == FollowStatus.approved) {
          buttonText = 'Following';
          isPrimary = false;
          onPressed = () => _handleUnfollow(targetUserId);
        } else {
          buttonText = 'Follow';
          isPrimary = true;
          onPressed = () => _handleFollow(targetUserId, isTargetPrivate);
        }

        return BounceAnimation(
          onTap: _isFollowLoading ? null : onPressed,
          child: SizedBox(
            width: 150,
            child: ElevatedButton(
              onPressed: _isFollowLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary ? AppColors.primary : null,
                foregroundColor: isPrimary ? Colors.white : null,
                side: isPrimary
                    ? null
                    : const BorderSide(color: AppColors.primary),
              ),
              child: _isFollowLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonText),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 150,
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, stackTrace) => BounceAnimation(
        onTap: () => _handleFollow(targetUserId, isTargetPrivate),
        child: ElevatedButton(
          onPressed: () => _handleFollow(targetUserId, isTargetPrivate),
          child: const Text('Follow'),
        ),
      ),
    );
  }

  Future<void> _handleFollow(String targetUserId, bool isPrivate) async {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    if (currentUserId == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isFollowLoading = true);

    try {
      final userProfile = await ref
          .read(authControllerProvider)
          .getUserProfile(currentUserId);
      await ref
          .read(followServiceProvider)
          .followUser(
            followerId: currentUserId,
            followeeId: targetUserId,
            isPrivate: isPrivate,
            followerName: userProfile?.displayName,
          );
      ref.invalidate(followStatusProvider(targetUserId));
      ref.invalidate(followersCountProvider(targetUserId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPrivate ? 'Follow request sent' : 'Now following'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  Future<void> _handleUnfollow(String targetUserId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfollow'),
        content: const Text('Are you sure you want to unfollow this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    if (currentUserId == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isFollowLoading = true);

    try {
      await ref
          .read(followServiceProvider)
          .unfollowUser(currentUserId, targetUserId);
      ref.invalidate(followStatusProvider(targetUserId));
      ref.invalidate(followersCountProvider(targetUserId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unfollowed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unfollow: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  Widget _buildEnhancedStats(WidgetRef ref, String uid, bool isCurrentUser) {
    final streakAsync = ref.watch(userStreakProvider(uid));
    final followersAsync = ref.watch(followersCountProvider(uid));
    final followingAsync = ref.watch(followingCountProvider(uid));
    final postsAsync = ref.watch(userPostsProvider(uid));

    final authState = ref.watch(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;

    AsyncValue<List<FriendStreakComparison>>? comparisonAsync;
    if (currentUserId != null) {
      comparisonAsync = ref.watch(
        friendsStreakComparisonProvider(currentUserId),
      );
    }

    return Column(
      children: [
        // Streak Card section with glow
        streakAsync.when(
          data: (stats) {
            return comparisonAsync?.when(
                  data: (comparisons) {
                    List<FriendStreakComparison>? displayComparisons;
                    if (!isCurrentUser) {
                      final targetUser = comparisons
                          .where((c) => c.userId == uid)
                          .firstOrNull;
                      final me = comparisons
                          .where((c) => c.userId == currentUserId)
                          .firstOrNull;

                      if (targetUser != null && me != null) {
                        displayComparisons = comparisons;
                      } else if (targetUser != null) {
                        displayComparisons = comparisons;
                      }
                    } else {
                      displayComparisons = comparisons;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: GlowContainer(
                        glowColor: AppColors.warning.withValues(alpha: 0.3),
                        blurRadius: 20,
                        child: StreakCard(
                          days: stats.currentStreak,
                          comparisons: displayComparisons,
                          showComparison: true,
                          onTap: () => context.push('/leaderboard?tab=streak'),
                        ),
                      ),
                    );
                  },
                  loading: () => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: StreakCard(
                      days: stats.currentStreak,
                      showComparison: false,
                    ),
                  ),
                  error: (_, stackTrace) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: StreakCard(
                      days: stats.currentStreak,
                      showComparison: false,
                    ),
                  ),
                ) ??
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: StreakCard(
                    days: stats.currentStreak,
                    showComparison: false,
                  ),
                );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ShimmerSkeleton(height: 100),
          ),
          error: (_, stackTrace) => const SizedBox(),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Stats row with glass container
        GlassContainer(
          blur: 10,
          backgroundColor: AppColors.surfaceSecondaryDark.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Workouts with animated counter
              streakAsync.when(
                data: (stats) =>
                    _buildAnimatedStatColumn(stats.totalWorkouts, 'Workouts'),
                loading: () => _buildStatColumn('-', 'Workouts'),
                error: (_, stackTrace) => _buildStatColumn('0', 'Workouts'),
              ),
              Container(width: 1, height: 40, color: AppColors.borderDark),

              // Followers (tappable with bounce)
              BounceAnimation(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (uid.isNotEmpty) {
                    context.push('/user/$uid/followers');
                  }
                },
                child: followersAsync.when(
                  data: (count) => _buildAnimatedStatColumn(count, 'Followers'),
                  loading: () => _buildStatColumn('-', 'Followers'),
                  error: (_, stackTrace) => _buildStatColumn('0', 'Followers'),
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.borderDark),

              // Following (tappable with bounce)
              BounceAnimation(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (uid.isNotEmpty) {
                    context.push('/user/$uid/following');
                  }
                },
                child: followingAsync.when(
                  data: (count) => _buildAnimatedStatColumn(count, 'Following'),
                  loading: () => _buildStatColumn('-', 'Following'),
                  error: (_, stackTrace) => _buildStatColumn('0', 'Following'),
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.borderDark),

              // Posts
              postsAsync.when(
                data: (posts) =>
                    _buildAnimatedStatColumn(posts.length, 'Posts'),
                loading: () => _buildStatColumn('-', 'Posts'),
                error: (_, stackTrace) => _buildStatColumn('0', 'Posts'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection(
    WidgetRef ref,
    String targetUserId,
    bool isPrivate,
    bool isCurrentUser,
  ) {
    // For private profiles that we're not following, show privacy message
    if (!isCurrentUser && isPrivate) {
      final followStatusAsync = ref.watch(followStatusProvider(targetUserId));
      final isFollowing =
          followStatusAsync.valueOrNull == FollowStatus.approved;

      if (!isFollowing) {
        return _buildSection(
          context,
          title: 'Posts',
          child: GlassContainer(
            blur: 10,
            backgroundColor: AppColors.surfaceSecondaryDark.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'This account is private',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Follow this account to see their posts',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    final postsAsync = ref.watch(userPostsProvider(targetUserId));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return _buildSection(
            context,
            title: 'Posts',
            child: GlassContainer(
              blur: 10,
              backgroundColor: AppColors.surfaceSecondaryDark.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No posts yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        // Show first 6 posts in a grid
        final displayPosts = posts.take(6).toList();

        return _buildSection(
          context,
          title: 'Posts (${posts.length})',
          trailing: posts.length > 6
              ? ScaleOnTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/user/$targetUserId/posts');
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : null,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: displayPosts.length,
            itemBuilder: (context, index) {
              return FadeInAnimation(
                delay: Duration(milliseconds: index * 50),
                child: PostCardWidget(
                  post: displayPosts[index],
                  displayMode: PostCardDisplayMode.minimal,
                ),
              );
            },
          ),
        );
      },
      loading: () => _buildSection(
        context,
        title: 'Posts',
        child: ShimmerLoading(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => const ShimmerSkeleton(height: 150),
          ),
        ),
      ),
      error: (e, _) => _buildSection(
        context,
        title: 'Posts',
        child: Center(
          child: Column(
            children: [
              Text('Error loading posts: $e'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(userPostsProvider(targetUserId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String targetUserId,
  ) async {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    if (currentUserId == null) return;

    final user = await ref
        .read(authControllerProvider)
        .getUserProfile(targetUserId);
    final userName = user?.displayName ?? 'User';

    if (!context.mounted) return;

    switch (action) {
      case 'report':
        await ReportDialog.show(
          context,
          reportedUserId: targetUserId,
          reportedUserName: userName,
        );
        break;

      case 'block':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block User'),
            content: Text(
              'Are you sure you want to block $userName? '
              'You will no longer see their content.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Block'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          try {
            HapticFeedback.heavyImpact();
            await ref
                .read(moderationServiceProvider)
                .blockUser(currentUserId, targetUserId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$userName has been blocked'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to block user: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
        break;
    }
  }

  Widget _buildBadgesSection(WidgetRef ref, String uid) {
    final badgesAsync = ref.watch(userBadgesProvider(uid));

    return badgesAsync.when(
      data: (badges) => _buildSection(
        context,
        title: 'Badges (${badges.length})',
        child: badges.isEmpty
            ? GlassContainer(
                blur: 10,
                backgroundColor: AppColors.surfaceSecondaryDark.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Complete workouts to earn badges!',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            : SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    return SlideInAnimation.fromRight(
                      index: index,
                      child: ScaleOnTap(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // Show badge details
                        },
                        child: GlowContainer(
                          glowColor: AppColors.warning.withValues(alpha: 0.3),
                          blurRadius: 10,
                          child: _buildBadge(badge.icon, badge.name),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      loading: () => ShimmerLoading(
        child: SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (_, _) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: ShimmerSkeleton.circle(size: 50),
            ),
          ),
        ),
      ),
      error: (_, stackTrace) => const SizedBox(),
    );
  }

  Widget _buildAnimatedStatColumn(int value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedCounter(
            value: value,
            style: const TextStyle(
              fontSize: AppFontSize.xl,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: AppFontSize.xl,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GradientText(
                text: title,
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                ),
                colors: [AppColors.textDark, AppColors.textSecondaryDark],
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }

  Widget _buildBadge(String emoji, String name) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: AppColors.primaryMuted,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            name,
            style: const TextStyle(fontSize: AppFontSize.xs),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  //   Widget _buildActionTile(
  //     BuildContext context, {
  //     required IconData icon,
  //     required String title,
  //     required VoidCallback onTap,
  //     required int index,
  //     bool isDestructive = false,
  //   }) {
  //     return SlideInAnimation.fromRight(
  //       index: index,
  //       delay: const Duration(milliseconds: 30),
  //       child: ScaleOnTap(
  //         onTap: () {
  //           HapticFeedback.lightImpact();
  //           onTap();
  //         },
  //         child: ListTile(
  //           leading: Icon(
  //             icon,
  //             color: isDestructive ? AppColors.error : AppColors.primary,
  //           ),
  //           title: Text(
  //             title,
  //             style: TextStyle(color: isDestructive ? AppColors.error : null),
  //           ),
  //           trailing: Icon(
  //             Icons.chevron_right,
  //             color: isDestructive
  //                 ? AppColors.error
  //                 : AppColors.textSecondaryDark,
  //           ),
  //         ),
  //       ),
  //     );
  //   }
}

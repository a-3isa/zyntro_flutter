import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:avatar_plus/avatar_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/constants/constants.dart';
import '../../../app/navigation/app_route_locations.dart';
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

class _ProfilePageState extends ConsumerState<ProfilePage> with TickerProviderStateMixin {
  bool _isFollowLoading = false;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
        duration: const Duration(seconds: 20),
        vsync: this)..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

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
      extendBodyBehindAppBar: true,
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
      body: Stack(
        children: [
          // Background atmospheric breathing blobs
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Stack(
                fit: StackFit.loose,
                children: [
                  Positioned(
                    top: -100 + (50 * math.sin(_bgController.value * 2 * math.pi)),
                    right: -100 + (50 * math.cos(_bgController.value * 2 * math.pi)),
                    child: Container(
                      width: 350 + (50 * math.sin(_bgController.value * 2 * math.pi)),
                      height: 350 + (50 * math.cos(_bgController.value * 2 * math.pi)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 200 + (30 * math.cos(_bgController.value * 2 * math.pi)),
                    left: -150 + (70 * math.sin(_bgController.value * math.pi)),
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceSecondaryDark.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Profile content
          SafeArea(
            child: userProfileAsync.when(
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
                      padding: const EdgeInsets.only(top: 20),
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
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatCard(String label, int? animatedValue, String? textValue, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
      decoration: GlassDecoration.elevated.copyWith(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: AppSpacing.md),
          if (animatedValue != null)
             AnimatedCounter(
               value: animatedValue,
               style: const TextStyle(
                 fontFamily: 'Outfit',
                 fontSize: AppFontSize.xxl,
                 fontWeight: FontWeight.w800,
                 color: AppColors.textDark,
               ),
             )
          else
             Text(
               textValue ?? '-',
               style: const TextStyle(
                 fontFamily: 'Outfit',
                 fontSize: AppFontSize.xxl,
                 fontWeight: FontWeight.w800,
                 color: AppColors.textDark,
               ),
             ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: AppFontSize.xs,
              color: AppColors.textSecondaryDark,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User user, bool isCurrentUser) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      decoration: GlassDecoration.elevated.copyWith(
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
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
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: AppFontSize.xxl,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
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
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.5),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.workoutPreference.value.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: AppFontSize.xs,
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(height: AppSpacing.xl),
            BounceAnimation(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.editProfile);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'EDIT PROFILE',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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
          buttonText = 'FOLLOW';
          isPrimary = true;
          onPressed = () => _handleFollow(targetUserId, isTargetPrivate);
        } else if (status == FollowStatus.pending) {
          buttonText = 'REQUESTED';
          isPrimary = false;
          onPressed = null; // Disabled
        } else if (status == FollowStatus.approved) {
          buttonText = 'FOLLOWING';
          isPrimary = false;
          onPressed = () => _handleUnfollow(targetUserId);
        } else {
          buttonText = 'FOLLOW';
          isPrimary = true;
          onPressed = () => _handleFollow(targetUserId, isTargetPrivate);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: BounceAnimation(
            onTap: _isFollowLoading ? null : onPressed,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isPrimary ? AppColors.primary : AppColors.surfaceSecondaryDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(
                  color: AppColors.primary,
                  width: 1.5,
                ),
                boxShadow: isPrimary
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: _isFollowLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isPrimary ? AppColors.backgroundDark : AppColors.primary,
                        ),
                      )
                    : Text(
                        buttonText,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: isPrimary ? AppColors.backgroundDark : AppColors.primary,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: double.infinity,
        height: 50,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, stackTrace) => BounceAnimation(
        onTap: () => _handleFollow(targetUserId, isTargetPrivate),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: const Center(
            child: Text(
              'FOLLOW',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: AppColors.backgroundDark,
              ),
            ),
          ),
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
                      child: StreakCard(
                          days: stats.currentStreak,
                          comparisons: displayComparisons,
                          showComparison: true,
                          onTap: () => context.go(
                            AppRouteLocations.mainTab(
                              MainShellTab.social,
                              socialTab: SocialTab.leaderboard,
                            ),
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

        // Distinct floating stat blocks
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: streakAsync.when(
                      data: (stats) => _buildGlassStatCard('Workouts', stats.totalWorkouts, null, Icons.fitness_center),
                      loading: () => _buildGlassStatCard('Workouts', null, '-', Icons.fitness_center),
                      error: (error, stackTrace) => _buildGlassStatCard('Workouts', null, '0', Icons.fitness_center),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: postsAsync.when(
                      data: (posts) => _buildGlassStatCard('Posts', posts.length, null, Icons.grid_on),
                      loading: () => _buildGlassStatCard('Posts', null, '-', Icons.grid_on),
                      error: (error, stackTrace) => _buildGlassStatCard('Posts', null, '0', Icons.grid_on),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BounceAnimation(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (uid.isNotEmpty) {
                          context.push(AppRouteLocations.userFollowers(uid));
                        }
                      },
                      child: followersAsync.when(
                        data: (count) => _buildGlassStatCard('Followers', count, null, Icons.group_outlined),
                        loading: () => _buildGlassStatCard('Followers', null, '-', Icons.group_outlined),
                        error: (error, stackTrace) => _buildGlassStatCard('Followers', null, '0', Icons.group_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: BounceAnimation(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (uid.isNotEmpty) {
                          context.push(AppRouteLocations.userFollowing(uid));
                        }
                      },
                      child: followingAsync.when(
                        data: (count) => _buildGlassStatCard('Following', count, null, Icons.person_add_outlined),
                        loading: () => _buildGlassStatCard('Following', null, '-', Icons.person_add_outlined),
                        error: (error, stackTrace) => _buildGlassStatCard('Following', null, '0', Icons.person_add_outlined),
                      ),
                    ),
                  ),
                ],
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
    if (!isCurrentUser && isPrivate) {
      final followStatusAsync = ref.watch(followStatusProvider(targetUserId));
      final isFollowing = followStatusAsync.valueOrNull == FollowStatus.approved;

      if (!isFollowing) {
        return _buildSection(
          context,
          title: 'POSTS',
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: GlassDecoration.elevated.copyWith(
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'THIS ACCOUNT IS PRIVATE',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: AppFontSize.lg,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'FOLLOW TO SEE POSTS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: AppFontSize.xs,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0,
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
            title: 'POSTS',
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: GlassDecoration.elevated.copyWith(
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'NO POSTS YET',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: AppFontSize.lg,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final displayPosts = posts.take(6).toList();

        return _buildSection(
          context,
          title: 'POSTS (${posts.length})',
          trailing: posts.length > 6
              ? ScaleOnTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/user/$targetUserId/posts');
                  },
                  child: const Text(
                    'VIEW ALL',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
              ),
              itemCount: displayPosts.length,
              itemBuilder: (context, index) {
                return FadeInAnimation(
                  delay: Duration(milliseconds: index * 50),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    child: PostCardWidget(
                      post: displayPosts[index],
                      displayMode: PostCardDisplayMode.minimal,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => _buildSection(
        context,
        title: 'POSTS',
        child: ShimmerLoading(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
              ),
              itemCount: 4,
              itemBuilder: (context, index) => const ShimmerSkeleton(height: 150),
            ),
          ),
        ),
      ),
      error: (e, _) => const SizedBox(),
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

    final user = await ref.read(authControllerProvider).getUserProfile(targetUserId);
    final userName = user?.displayName ?? 'User';

    if (!context.mounted) return;

    switch (action) {
      case 'report':
        await ReportDialog.show(context, reportedUserId: targetUserId, reportedUserName: userName);
        break;
      case 'block':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block User'),
            content: Text('Are you sure you want to block $userName?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Block')),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          try {
            HapticFeedback.heavyImpact();
            await ref.read(moderationServiceProvider).blockUser(currentUserId, targetUserId);
            if (context.mounted) Navigator.pop(context);
          } catch (e) {
            // Error handling
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
        title: 'BADGES (${badges.length})',
        child: badges.isEmpty
            ? Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: GlassDecoration.elevated.copyWith(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Center(
                  child: Text(
                    'COMPLETE WORKOUTS TO EARN BADGES',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              )
            : SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    return SlideInAnimation.fromRight(
                      index: index,
                      child: ScaleOnTap(
                        onTap: () {
                          HapticFeedback.lightImpact();
                        },
                        child: _buildBadge(badge.icon, badge.name),
                      ),
                    );
                  },
                ),
              ),
      ),
      loading: () => ShimmerLoading(
        child: SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: 5,
            itemBuilder: (_, _) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: ShimmerSkeleton.circle(size: 80),
            ),
          ),
        ),
      ),
      error: (_, stackTrace) => const SizedBox(),
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: AppColors.textDark,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }

  Widget _buildBadge(String emoji, String name) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      decoration: GlassDecoration.elevated.copyWith(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryDark,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

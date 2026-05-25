import 'dart:math' as math;
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../moderation/presentation/report_dialog.dart';
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Color _buildTypeColor(String type) {
  switch (type.toLowerCase()) {
    case 'gym':
      return const Color(0xFFC8FF00);
    case 'cardio':
      return const Color(0xFF38BDF8);
    case 'hiit':
      return const Color(0xFFFF8C00);
    case 'cycling':
      return const Color(0xFFA78BFA);
    case 'yoga':
      return const Color(0xFF34D399);
    case 'swimming':
      return const Color(0xFF22D3EE);
    default:
      return AppColors.accentLime;
  }
}

IconData _buildTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'gym':
      return Icons.fitness_center;
    case 'cardio':
      return Icons.directions_run;
    case 'hiit':
      return Icons.bolt;
    case 'cycling':
      return Icons.directions_bike;
    case 'yoga':
      return Icons.self_improvement;
    case 'swimming':
      return Icons.pool;
    default:
      return Icons.fitness_center;
  }
}

// ---------------------------------------------------------------------------
// ProfilePage
// ---------------------------------------------------------------------------

/// Profile page showing user stats and settings — v2 design.
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

    final targetUserId = widget.userId ?? currentUserId;
    final isCurrentUser = targetUserId == currentUserId;

    final AsyncValue<User?> userProfileAsync;
    if (widget.userId != null) {
      userProfileAsync = ref.watch(otherUserProfileProvider(widget.userId!));
    } else {
      userProfileAsync = ref.watch(currentUserProfileProvider);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: userProfileAsync.when(
        data: (user) {
          if (user == null || targetUserId == null) {
            return const Center(child: Text('User not found'));
          }
          return _ProfileContent(
            user: user,
            targetUserId: targetUserId,
            isCurrentUser: isCurrentUser,
            isFollowLoading: _isFollowLoading,
            onFollow: (id, isPrivate) => _handleFollow(id, isPrivate),
            onUnfollow: _handleUnfollow,
            onAction: (action, id) =>
                _handleAction(context, ref, action, id),
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
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentLime),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Error: $e'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () {
                  if (isCurrentUser) {
                    ref.invalidate(currentUserProfileProvider);
                  } else if (targetUserId != null) {
                    ref.invalidate(otherUserProfileProvider(targetUserId));
                  }
                },
                child: const Text('Retry'),
              ),
            ],
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
      final userProfile =
          await ref.read(authControllerProvider).getUserProfile(currentUserId);
      await ref.read(followServiceProvider).followUser(
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

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String targetUserId,
  ) async {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    if (currentUserId == null) return;

    final user =
        await ref.read(authControllerProvider).getUserProfile(targetUserId);
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
            content: Text('Are you sure you want to block $userName?'),
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
            if (context.mounted) Navigator.pop(context);
          } catch (_) {}
        }
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// _ProfileContent — NestedScrollView + DefaultTabController
// ---------------------------------------------------------------------------

class _ProfileContent extends ConsumerWidget {
  final User user;
  final String targetUserId;
  final bool isCurrentUser;
  final bool isFollowLoading;
  final void Function(String, bool) onFollow;
  final void Function(String) onUnfollow;
  final void Function(String, String) onAction;
  final Future<void> Function() onRefresh;

  const _ProfileContent({
    required this.user,
    required this.targetUserId,
    required this.isCurrentUser,
    required this.isFollowLoading,
    required this.onFollow,
    required this.onUnfollow,
    required this.onAction,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.accentLime,
        backgroundColor: AppColors.surfaceV2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _HeaderSection(
                  user: user,
                  targetUserId: targetUserId,
                  isCurrentUser: isCurrentUser,
                  isFollowLoading: isFollowLoading,
                  onFollow: onFollow,
                  onUnfollow: onUnfollow,
                  onAction: onAction,
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    labelColor: AppColors.textV2Primary,
                    unselectedLabelColor: AppColors.textV2Secondary,
                    indicatorColor: AppColors.accentLime,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 2,
                    dividerColor: AppColors.surfaceV2Active,
                    tabs: const [
                      Tab(text: 'Posts'),
                      Tab(text: 'History'),
                      Tab(text: 'Awards'),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _PostsTab(
                targetUserId: targetUserId,
                isCurrentUser: isCurrentUser,
                isPrivate: user.isPrivate,
              ),
              const _HistoryTab(),
              _AwardsTab(targetUserId: targetUserId),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SliverPersistentHeaderDelegate for TabBar
// ---------------------------------------------------------------------------

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.backgroundV2,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

// ---------------------------------------------------------------------------
// Header Section (pinned above tabs in sliver header)
// ---------------------------------------------------------------------------

class _HeaderSection extends ConsumerStatefulWidget {
  final User user;
  final String targetUserId;
  final bool isCurrentUser;
  final bool isFollowLoading;
  final void Function(String, bool) onFollow;
  final void Function(String) onUnfollow;
  final void Function(String, String) onAction;

  const _HeaderSection({
    required this.user,
    required this.targetUserId,
    required this.isCurrentUser,
    required this.isFollowLoading,
    required this.onFollow,
    required this.onUnfollow,
    required this.onAction,
  });

  @override
  ConsumerState<_HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends ConsumerState<_HeaderSection> {
  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final targetUserId = widget.targetUserId;
    final isCurrentUser = widget.isCurrentUser;

    final streakAsync = ref.watch(userStreakProvider(targetUserId));
    final followersAsync = ref.watch(followersCountProvider(targetUserId));
    final postsAsync = ref.watch(userPostsProvider(targetUserId));

    final int workouts =
        streakAsync.valueOrNull?.totalWorkouts ?? 0;
    final int streak = streakAsync.valueOrNull?.currentStreak ?? 0;
    final int buddies = followersAsync.valueOrNull ?? 0;
    final int points = workouts * 10;
    final int postCount = postsAsync.valueOrNull?.length ?? 0;

    // Split name for editorial stacked display
    final nameParts = user.displayName.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    return Stack(
      children: [
        // Radial lime tint overlay at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 200,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  AppColors.accentLime.withValues(alpha: 0.028),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Top row: avatar + name block + settings icon ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar 64px
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceV2Elevated,
                      border: Border.all(
                        color: AppColors.accentLime.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child:
                          user.photoURL != null && user.photoURL!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: user.photoURL!,
                                  fit: BoxFit.cover,
                                  width: 64,
                                  height: 64,
                                )
                              : (user.avatarConfig != null &&
                                      user.avatarConfig!.isNotEmpty)
                                  ? AvatarPlus(
                                      user.avatarConfig!,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Text(
                                        user.displayName.isNotEmpty
                                            ? user.displayName[0].toUpperCase()
                                            : 'U',
                                        style: GoogleFonts.syne(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.accentLime,
                                        ),
                                      ),
                                    ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Editorial name block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First name
                        Text(
                          firstName.toUpperCase(),
                          style: GoogleFonts.syne(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            color: AppColors.textV2Primary,
                            height: 0.95,
                          ),
                        ),
                        // Last name (if exists)
                        if (lastName.isNotEmpty)
                          Text(
                            lastName.toUpperCase(),
                            style: GoogleFonts.syne(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              color: AppColors.textV2Primary,
                              height: 0.95,
                            ),
                          ),
                        const SizedBox(height: 6),
                        // @username · Rank #N
                        Row(
                          children: [
                            Text(
                              '@${user.displayName.toLowerCase().replaceAll(' ', '')}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textV2Tertiary,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Text(
                                '·',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textV2Tertiary,
                                ),
                              ),
                            ),
                            Text(
                              'Rank #${(workouts ~/ 5) + 1}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.accentLime,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Settings / back icon
                  if (isCurrentUser)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: AppColors.textV2Tertiary,
                        size: 22,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push(AppRoutes.settings);
                      },
                    )
                  else if (!isCurrentUser)
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textV2Tertiary,
                            size: 22,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: AppColors.textV2Tertiary,
                            size: 22,
                          ),
                          onSelected: (value) =>
                              widget.onAction(value, targetUserId),
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
                                  Icon(
                                    Icons.block,
                                    size: 20,
                                    color: Colors.red,
                                  ),
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
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // ---- Follow button (for other users) ----
              if (!isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _FollowButton(
                    targetUserId: targetUserId,
                    isTargetPrivate: user.isPrivate,
                    isLoading: widget.isFollowLoading,
                    onFollow: widget.onFollow,
                    onUnfollow: widget.onUnfollow,
                  ),
                ),

              // ---- Stats row with dividers ----
              _StatsRow(
                workouts: workouts,
                streak: streak,
                points: points,
                buddies: buddies,
              ),

              const SizedBox(height: 0),

              // ---- Action row ----
              if (isCurrentUser)
                _ActionRow(postCount: postCount),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final int workouts;
  final int streak;
  final int points;
  final int buddies;

  const _StatsRow({
    required this.workouts,
    required this.streak,
    required this.points,
    required this.buddies,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Workouts', workouts.toString(), null),
      ('Streak', streak.toString(), '🔥'),
      ('Points', points.toString(), null),
      ('Buddies', buddies.toString(), null),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: AppColors.surfaceV2,
            width: 1,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: List.generate(stats.length * 2 - 1, (i) {
            if (i.isOdd) {
              return VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.surfaceV2,
              );
            }
            final idx = i ~/ 2;
            final label = stats[idx].$1;
            final value = stats[idx].$2;
            final suffix = stats[idx].$3;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.syne(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textV2Primary,
                            letterSpacing: -0.8,
                          ),
                        ),
                        if (suffix != null)
                          Text(suffix, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: AppColors.textV2Tertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action Row (Edit Profile + Weekly Goal)
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  final int postCount;

  const _ActionRow({required this.postCount});

  @override
  Widget build(BuildContext context) {
    // Weekly goal: mock 3/5 workouts completed this week
    const int weeklyDone = 3;
    const int weeklyGoal = 5;
    const double progress = weeklyDone / weeklyGoal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          // Ghost edit profile button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.editProfile);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceV2Active),
              ),
              child: Text(
                'Edit Profile',
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Secondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Weekly goal bar
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                      Text(
                        '$weeklyDone/$weeklyGoal',
                        style: GoogleFonts.syne(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentLime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2Elevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accentLime,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Follow Button
// ---------------------------------------------------------------------------

class _FollowButton extends ConsumerWidget {
  final String targetUserId;
  final bool isTargetPrivate;
  final bool isLoading;
  final void Function(String, bool) onFollow;
  final void Function(String) onUnfollow;

  const _FollowButton({
    required this.targetUserId,
    required this.isTargetPrivate,
    required this.isLoading,
    required this.onFollow,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followStatusAsync = ref.watch(followStatusProvider(targetUserId));

    return followStatusAsync.when(
      data: (status) {
        String buttonText;
        bool isPrimary;
        VoidCallback? onPressed;

        if (status == null) {
          buttonText = 'FOLLOW';
          isPrimary = true;
          onPressed = () => onFollow(targetUserId, isTargetPrivate);
        } else if (status == FollowStatus.pending) {
          buttonText = 'REQUESTED';
          isPrimary = false;
          onPressed = null;
        } else if (status == FollowStatus.approved) {
          buttonText = 'FOLLOWING';
          isPrimary = false;
          onPressed = () => onUnfollow(targetUserId);
        } else {
          buttonText = 'FOLLOW';
          isPrimary = true;
          onPressed = () => onFollow(targetUserId, isTargetPrivate);
        }

        return GestureDetector(
          onTap: isLoading ? null : onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isPrimary
                  ? AppColors.primary
                  : AppColors.surfaceV2Elevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isPrimary
                            ? AppColors.backgroundV2
                            : AppColors.primary,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: GoogleFonts.syne(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isPrimary
                            ? AppColors.backgroundV2
                            : AppColors.accentLime,
                      ),
                    ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, e2) => GestureDetector(
        onTap: () => onFollow(targetUserId, isTargetPrivate),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.accentLime,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: Center(
            child: Text(
              'FOLLOW',
              style: GoogleFonts.syne(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: AppColors.backgroundV2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Posts Tab
// ---------------------------------------------------------------------------

class _PostsTab extends ConsumerWidget {
  final String targetUserId;
  final bool isCurrentUser;
  final bool isPrivate;

  const _PostsTab({
    required this.targetUserId,
    required this.isCurrentUser,
    required this.isPrivate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Private account check for non-followers
    if (!isCurrentUser && isPrivate) {
      final followStatusAsync = ref.watch(followStatusProvider(targetUserId));
      final isFollowing =
          followStatusAsync.valueOrNull == FollowStatus.approved;
      if (!isFollowing) {
        return _buildLocked(context);
      }
    }

    final postsAsync = ref.watch(userPostsProvider(targetUserId));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) return _buildEmpty(context);

        // Mock workout types for thumbnail grid
        final types = ['gym', 'cardio', 'hiit', 'cycling', 'yoga', 'swimming'];
        final rng = math.Random(1);

        return GridView.builder(
          padding: const EdgeInsets.all(3),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            childAspectRatio: 1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final type = types[rng.nextInt(types.length)];
            final typeColor = _buildTypeColor(type);
            final typeIcon = _buildTypeIcon(type);
            final setsCount = rng.nextInt(10) + 1;

            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Radial gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0,
                        colors: [
                          typeColor.withValues(alpha: 0.094),
                          AppColors.surfaceV2,
                        ],
                      ),
                    ),
                  ),
                  // Large background icon
                  Center(
                    child: Icon(
                      typeIcon,
                      size: MediaQuery.of(context).size.width / 3 * 0.7,
                      color: typeColor.withValues(alpha: 0.12),
                    ),
                  ),
                  // Sets count bottom-left
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Text(
                      '${setsCount}s',
                      style: GoogleFonts.syne(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accentLime,
        ),
      ),
      error: (e, _) => const SizedBox(),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.textV2Tertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No posts yet',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocked(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 48,
            color: AppColors.textV2Tertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'This account is private',
            style: GoogleFonts.syne(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Follow to see posts',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textV2Tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History Tab
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _WeeklyVolumeChart(),
        SizedBox(height: 12),
        _ActivityHeatmap(),
        SizedBox(height: 20),
        _RecentSessionsList(),
        SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly Volume Bar Chart (History tab)
// ---------------------------------------------------------------------------

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart();

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(42);
    // 8 weeks of data
    final values = List.generate(8, (_) => 0.2 + rng.nextDouble() * 0.8);
    final weekLabels = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VOLUME / WEEK',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              Text(
                '↑ 12%',
                style: GoogleFonts.syne(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentLime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(8, (i) {
                final isLast = i == 7;
                final isSecondLast = i == 6;
                Color barColor;
                if (isLast) {
                  barColor = AppColors.accentLime;
                } else if (isSecondLast) {
                  barColor = AppColors.accentLime.withValues(alpha: 0.53);
                } else {
                  barColor = AppColors.surfaceV2Elevated;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: values[i],
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekLabels[i],
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: isLast
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isLast
                                ? AppColors.accentLime
                                : AppColors.textV2Tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity Heatmap (History tab)
// ---------------------------------------------------------------------------

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap();

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    const days = 7;
    final rng = math.Random(7);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVITY — 12 WEEKS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textV2Tertiary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day-of-week labels (every other day)
              Column(
                children: List.generate(days, (d) {
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return SizedBox(
                    height: 13,
                    width: 10,
                    child: Center(
                      child: Text(
                        d.isEven ? labels[d] : '',
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 4),
              // Grid
              Expanded(
                child: Row(
                  children: List.generate(weeks, (w) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Column(
                          children: List.generate(days, (d) {
                            final level = rng.nextDouble();
                            final alpha = level < 0.2
                                ? 0.06
                                : level < 0.5
                                    ? 0.25
                                    : level < 0.75
                                        ? 0.55
                                        : 1.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: alpha <= 0.06
                                      ? AppColors.surfaceV2
                                      : AppColors.accentLime.withValues(alpha: alpha),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '12 weeks ago',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              Text(
                'Today',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              const SizedBox(width: 4),
              ...[0.06, 0.25, 0.55, 1.0].map(
                (a) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'More',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Sessions List (History tab)
// ---------------------------------------------------------------------------

class _RecentSessionsList extends StatelessWidget {
  const _RecentSessionsList();

  static const _sessions = [
    (
      type: 'gym',
      name: 'Upper Body',
      date: 'Today',
      duration: '42 min',
      sets: 14,
    ),
    (
      type: 'cardio',
      name: 'Morning Run',
      date: 'Yesterday',
      duration: '35 min',
      sets: 1,
    ),
    (
      type: 'hiit',
      name: 'HIIT Blast',
      date: '2 days ago',
      duration: '28 min',
      sets: 8,
    ),
    (
      type: 'yoga',
      name: 'Flexibility',
      date: '3 days ago',
      duration: '50 min',
      sets: 6,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textV2Tertiary,
          ),
        ),
        const SizedBox(height: 10),
        ..._sessions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // Icon square
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _buildTypeIcon(s.type),
                    size: 20,
                    color: _buildTypeColor(s.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: GoogleFonts.syne(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                      Text(
                        '${s.date} · ${s.duration}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textV2Secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${s.sets}',
                      style: GoogleFonts.syne(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                    Text(
                      'SETS',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: AppColors.textV2Tertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Awards Tab
// ---------------------------------------------------------------------------

class _AwardsTab extends ConsumerWidget {
  final String targetUserId;

  const _AwardsTab({required this.targetUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesProvider(targetUserId));

    return badgesAsync.when(
      data: (earnedBadges) {
        final earnedIds = earnedBadges.map((b) => b.id).toSet();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: availableBadges.length,
          itemBuilder: (context, index) {
            final badge = availableBadges[index];
            final isEarned = earnedIds.contains(badge.id);
            return _AwardCard(badge: badge, isEarned: isEarned);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accentLime,
        ),
      ),
      error: (e, _) => const SizedBox(),
    );
  }
}

class _AwardCard extends StatelessWidget {
  final Badge badge;
  final bool isEarned;

  const _AwardCard({required this.badge, required this.isEarned});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEarned ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: isEarned ? AppColors.surfaceV2 : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isEarned
                ? AppColors.accentLime.withValues(alpha: 0.08)
                : AppColors.surfaceV2,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              badge.icon,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              badge.name,
              style: GoogleFonts.syne(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isEarned ? AppColors.accentLime : AppColors.textV2Secondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              badge.description,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppColors.textV2Tertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legacy chart widgets kept for backwards compatibility (used nowhere else)
// ---------------------------------------------------------------------------

/// 8-bar weekly volume chart using v2 design tokens.
class WeeklyVolumeChart extends StatelessWidget {
  const WeeklyVolumeChart({super.key});

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(42);
    final values = List.generate(7, (_) => rng.nextDouble());
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceV2Active),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY VOLUME',
            style: GoogleFonts.syne(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.textV2Tertiary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = i == DateTime.now().weekday - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300 + i * 60),
                          curve: Curves.easeOutCubic,
                          height: (values[i] * 64).clamp(4.0, 64.0),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.accentLime
                                : AppColors.accentLime.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isToday
                                ? AppColors.accentLime
                                : AppColors.textV2Tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// 12-week × 7-day activity heatmap using v2 design tokens.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key});

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    const days = 7;
    final rng = math.Random(7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceV2Active),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVITY',
            style: GoogleFonts.syne(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.textV2Tertiary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(weeks, (w) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    children: List.generate(days, (d) {
                      final level = rng.nextDouble();
                      final alpha = level < 0.2
                          ? 0.06
                          : level < 0.5
                              ? 0.25
                              : level < 0.75
                                  ? 0.55
                                  : 1.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  AppColors.accentLime.withValues(alpha: alpha),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              const SizedBox(width: 4),
              ...[0.06, 0.25, 0.55, 1.0].map(
                (a) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'More',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textV2Tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

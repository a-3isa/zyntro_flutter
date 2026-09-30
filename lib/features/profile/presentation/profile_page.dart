import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';


import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/workout_type_visuals.dart';
import '../../../core/models/models.dart';
import '../../../core/constants/constants.dart';
import '../../../app/navigation/app_router.dart';
import '../../../services/user_service.dart';
import '../../../services/moderation_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/post_service.dart';
import '../../../widgets/widgets.dart';
import '../../moderation/presentation/report_dialog.dart';
import '../../auth/auth_providers.dart';
import 'profile_providers.dart';
import 'widgets/profile_posts_tab.dart';
import 'widgets/profile_tabs.dart';
import 'widgets/profile_header_widgets.dart';
import 'widgets/profile_follow_button.dart';
import 'widgets/profile_action_row.dart';
import '../../../services/leaderboard_service.dart';
import '../../../services/profile_cache_service.dart';
import '../../../utils/offline_manager.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parses the avatar color picked during onboarding (stored as an ARGB or RGB
/// hex string in `avatarConfig`) into a [Color]. Returns null when absent or
/// unparseable so callers can fall back to a neutral surface color.
Color? avatarColorFromConfig(String? config) {
  if (config == null || config.isEmpty) return null;
  final hex = config.replaceFirst('#', '').trim();
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  // If only RRGGBB was provided, force full opacity.
  return Color(hex.length <= 6 ? (0xFF000000 | value) : value);
}

/// Delegates to the shared palette and icon map. Both used to be local
/// switches here, and both had drifted from their counterparts elsewhere: the
/// colours disagreed with two session screens, and hiit rendered a different
/// icon in the feed.
Color _buildTypeColor(String type) => AppColors.typeColor(type.toLowerCase());

IconData _buildTypeIcon(String type) => workoutTypeIcon(type);

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
  // T035: cache seed loaded in initState for instant offline display.
  User? _cachedUser;

  String? get _targetUserId =>
      widget.userId ?? ref.read(authSessionProvider).value?.id;

  bool get _isCurrentUser {
    final currentId = ref.read(authSessionProvider).value?.id;
    return widget.userId == null || widget.userId == currentId;
  }

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
  }

  void _loadCachedProfile() {
    final uid = _targetUserId;
    if (uid == null) return;
    final cached = ref.read(profileCacheServiceProvider).readProfile(uid);
    if (cached != null) setState(() => _cachedUser = cached);
  }

  @override
  Widget build(BuildContext context) {
    final targetUserId = _targetUserId;
    if (targetUserId == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.signal),
        ),
      );
    }

    final userAsync = _isCurrentUser
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(otherUserProfileProvider(targetUserId));

    final isOnline = ref.watch(connectivityProvider).value ?? true;

    // T035: helper to render profile content (used from data, loading, error).
    Widget profileContent(User user, {bool fromCache = false}) {
      // T036: write to cache when fresh Firestore data arrives.
      if (!fromCache) {
        ref.read(profileCacheServiceProvider).writeProfile(targetUserId, user);
      }
      final showCacheChip = fromCache || (!isOnline);
      return Column(
        children: [
          if (showCacheChip)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.surfaceV2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      size: 14, color: AppColors.textV2Secondary),
                  const SizedBox(width: 6),
                  Text(
                    'Viewing cached data',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textV2Secondary,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _ProfileContent(
              user: user,
              targetUserId: targetUserId,
              isCurrentUser: _isCurrentUser,
              isFollowLoading: _isFollowLoading,
              onFollow: _handleFollow,
              onUnfollow: _handleUnfollow,
              onAction: (action, uid) => _handleAction(
                context,
                ref,
                action,
                uid,
                targetUserName: user.displayName,
              ),
              onRefresh: () async {
                ref.invalidate(currentUserProfileProvider);
                ref.invalidate(otherUserProfileProvider(targetUserId));
                ref.invalidate(userSessionsProvider(targetUserId));
                ref.invalidate(userPostsProvider(targetUserId));
                ref.invalidate(userStreakProvider(targetUserId));
                ref.invalidate(followersCountProvider(targetUserId));
              },
            ),
          ),
        ],
      );
    }

    return userAsync.when(
      data: (user) {
        if (user == null) {
          if (_cachedUser != null) {
            return Scaffold(
              backgroundColor: AppColors.backgroundV2,
              body: profileContent(_cachedUser!, fromCache: true),
            );
          }
          return Scaffold(
            backgroundColor: AppColors.backgroundV2,
            appBar: AppBar(backgroundColor: AppColors.backgroundV2),
            body: Center(
              child: Text(
                'User not found',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Secondary,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundV2,
          body: profileContent(user),
        );
      },
      loading: () {
        // T035: show cached profile immediately while Firestore loads.
        if (_cachedUser != null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundV2,
            body: profileContent(_cachedUser!, fromCache: true),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.backgroundV2,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.signal),
          ),
        );
      },
      error: (e, _) {
        if (_cachedUser != null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundV2,
            body: profileContent(_cachedUser!, fromCache: true),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.backgroundV2,
          body: Center(
            child: Text(
              'Failed to load profile',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textV2Secondary,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleFollow(String targetUserId, bool isPrivate) async {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.value?.id;
    if (currentUserId == null) return;
    final followerName = authState.value?.displayName ?? 'Someone';

    HapticFeedback.mediumImpact();
    setState(() => _isFollowLoading = true);

    try {
      await ref
          .read(followServiceProvider)
          .followUser(
            followerId: currentUserId,
            followeeId: targetUserId,
            isPrivate: isPrivate,
            followerName: followerName,
          );
      ref.invalidate(followStatusProvider(targetUserId));
      ref.invalidate(followersCountProvider(targetUserId));
      ref.invalidate(followingCountProvider(currentUserId));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _handleUnfollow(String targetUserId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceV2,
        title: Text(
          'Unfollow?',
          style: AppTextStyles.h5.copyWith(color: AppColors.textV2Primary),
        ),
        content: Text(
          'Are you sure you want to unfollow this user?',
          style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textV2Secondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Unfollow',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.value?.id;
    if (currentUserId == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isFollowLoading = true);

    try {
      await ref
          .read(followServiceProvider)
          .unfollowUser(currentUserId, targetUserId);
      ref.invalidate(followStatusProvider(targetUserId));
      ref.invalidate(followersCountProvider(targetUserId));
      ref.invalidate(followingCountProvider(currentUserId));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String targetUserId, {
    String targetUserName = '',
  }) async {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.value?.id;
    if (currentUserId == null) return;

    switch (action) {
      case 'report':
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => ReportDialog(
            reportedUserId: targetUserId,
            reportedUserName: targetUserName,
          ),
        );
      case 'block':
        await ref
            .read(moderationServiceProvider)
            .blockUser(currentUserId, targetUserId);
        if (context.mounted) context.go(AppRoutes.main);
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
    // Private profile gate: non-followers only see avatar + locked message.
    if (!isCurrentUser && user.isPrivate) {
      final followStatusAsync = ref.watch(followStatusProvider(targetUserId));
      final isFollowing =
          followStatusAsync.value == FollowStatus.approved;
      if (!isFollowing) {
        return _PrivateProfileView(
          user: user,
          targetUserId: targetUserId,
          followStatus: followStatusAsync.value,
          isFollowLoading: isFollowLoading,
          onFollow: onFollow,
        );
      }
    }

    return DefaultTabController(
      length: 3,
      child: RefreshIndicator(
        color: AppColors.signal,
        backgroundColor: AppColors.surfaceV2,
        onRefresh: onRefresh,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                  labelColor: AppColors.textV2Primary,
                  unselectedLabelColor: AppColors.textV2Tertiary,
                  indicatorColor: AppColors.signal,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: AppTextStyles.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  tabs: const [
                    Tab(text: 'POSTS'),
                    Tab(text: 'HISTORY'),
                    Tab(text: 'AWARDS'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              ProfilePostsTab(
                targetUserId: targetUserId,
                isCurrentUser: isCurrentUser,
                isPrivate: user.isPrivate,
              ),
              ProfileHistoryTab(targetUserId: targetUserId),
              ProfileAwardsTab(targetUserId: targetUserId),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private Profile View
// ---------------------------------------------------------------------------

class _PrivateProfileView extends ConsumerWidget {
  final User user;
  final String targetUserId;
  final FollowStatus? followStatus;
  final bool isFollowLoading;
  final void Function(String, bool) onFollow;

  const _PrivateProfileView({
    required this.user,
    required this.targetUserId,
    required this.followStatus,
    required this.isFollowLoading,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = followStatus == FollowStatus.pending;
    final currentUserId = ref.read(authSessionProvider).value?.id;

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button — icon only, consistent with regular visitor header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: ZyntroBackButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar
                    _buildAvatar(),
                    const SizedBox(height: 16),
                    // Display name
                    Text(
                      user.displayName,
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                    if (user.username != null && user.username!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Lock icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 28,
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Private Account',
                      style: AppTextStyles.h5.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow this account to see their\nworkouts, posts and activity.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textV2Tertiary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Follow / Requested button
                    SizedBox(
                      width: 160,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: isFollowLoading
                            ? null
                            : isPending
                            ? currentUserId == null
                                  ? null
                                  : () async {
                                      await ref
                                          .read(followServiceProvider)
                                          .withdrawFollowRequest(
                                            currentUserId,
                                            targetUserId,
                                          );
                                      ref.invalidate(
                                        followStatusProvider(targetUserId),
                                      );
                                    }
                            : () => onFollow(targetUserId, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPending
                              ? AppColors.surfaceV2
                              : AppColors.signal,
                          foregroundColor: isPending
                              ? AppColors.textV2Secondary
                              : AppColors.backgroundV2,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: isFollowLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isPending
                                      ? AppColors.textV2Secondary
                                      : AppColors.backgroundV2,
                                ),
                              )
                            : Text(
                                isPending ? 'Requested' : 'Follow',
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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
      ),
    );
  }

  Widget _buildAvatar() {
    const double size = 80;

    Widget inner;
    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      inner = ClipOval(
        child: CachedNetworkImage(
          imageUrl: user.photoURL!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) =>
              Container(width: size, height: size, color: AppColors.surfaceV2),
          errorWidget: (_, _, _) => _fallback(size),
        ),
      );
    } else {
      inner = _fallback(size);
    }

    final ringColor =
        avatarColorFromConfig(user.avatarConfig) ?? AppColors.signal;

    return Container(
      width: size + 6,
      height: size + 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2.5),
      ),
      child: ClipOval(child: inner),
    );
  }

  Widget _fallback(double size) {
    final c = avatarColorFromConfig(user.avatarConfig);
    return Container(
      width: size,
      height: size,
      color: c != null ? c.withValues(alpha: 0.20) : AppColors.surfaceV2,
      alignment: Alignment.center,
      child: Text(
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
        style: AppTextStyles.h3.copyWith(color: c ?? AppColors.textV2Primary),
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
    return Container(color: AppColors.backgroundV2, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

// ---------------------------------------------------------------------------
// Header Section
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
    final sessionsAsync = ref.watch(userSessionsProvider(targetUserId));
    final followersAsync = ref.watch(followersCountProvider(targetUserId));
    final followingAsync = ref.watch(followingCountProvider(targetUserId));
    final postsAsync = ref.watch(userPostsProvider(targetUserId));

    ref.listen(userSessionsProvider(targetUserId), (previous, next) {
      final previousCount = previous?.value?.length;
      final nextCount = next.value?.length;
      if (previousCount != null &&
          nextCount != null &&
          previousCount != nextCount) {
        ref.read(userServiceProvider).invalidateStreakCache(targetUserId);
        ref.invalidate(userStreakProvider(targetUserId));
        ref.invalidate(currentUserRankProvider(targetUserId));
      }
    });

    final int workouts =
        sessionsAsync.value?.length ??
        streakAsync.value?.totalWorkouts ??
        0;
    final int streak = streakAsync.value?.currentStreak ?? 0;
    final int followers = followersAsync.value ?? 0;
    final int following = followingAsync.value ?? 0;
    final int points = workouts * 10;
    final int postCount = postsAsync.value?.length ?? 0;

    final rankAsync = ref.watch(currentUserRankProvider(targetUserId));
    final rankInfo = rankAsync.whenOrNull(
      data: (r) =>
          r.rank != null ? (rank: r.rank!, isGlobal: r.isGlobal) : null,
    );

    final followsMe =
        !isCurrentUser &&
        (ref.watch(targetFollowsCurrentProvider(targetUserId)).value ??
            false);
    // Buddy = mutual approved follow (I follow them AND they follow me).
    final iFollowThem =
        !isCurrentUser &&
        (ref.watch(followStatusProvider(targetUserId)).value ==
            FollowStatus.approved);
    final bool isBuddy = followsMe && iFollowThem;

    final nameParts = user.displayName.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    return SafeArea(
      bottom: false,
      child: isCurrentUser
          ? _buildOwnerHeader(
              context,
              user: user,
              targetUserId: targetUserId,
              firstName: firstName,
              lastName: lastName,
              workouts: workouts,
              streak: streak,
              followers: followers,
              following: following,
              points: points,
              postCount: postCount,
              rankInfo: rankInfo,
            )
          : _buildVisitorHeader(
              context,
              user: user,
              targetUserId: targetUserId,
              firstName: firstName,
              lastName: lastName,
              followsMe: followsMe,
              isBuddy: isBuddy,
              workouts: workouts,
              streak: streak,
              followers: followers,
              following: following,
              points: points,
              rankInfo: rankInfo,
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Owner layout — existing inline avatar + name side-by-side
  // ---------------------------------------------------------------------------

  Widget _buildOwnerHeader(
    BuildContext context, {
    required User user,
    required String targetUserId,
    required String firstName,
    required String lastName,
    required int workouts,
    required int streak,
    required int followers,
    required int following,
    required int points,
    required int postCount,
    ({int rank, bool isGlobal})? rankInfo,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: rankInfo != null ? 10.0 : 0),
                child: _buildAvatar(user, rankInfo: rankInfo),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: firstName,
                            style: AppTextStyles.h2.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textV2Primary,
                              height: 1.1,
                              letterSpacing: -1,
                            ),
                          ),
                          if (lastName.isNotEmpty) ...[
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: lastName,
                              style: AppTextStyles.h2.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.signal,
                                height: 1.1,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (user.username != null && user.username!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _buildTypeIcon(user.workoutPreference.name),
                          size: 11,
                          color: _buildTypeColor(user.workoutPreference.name),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.workoutPreference.displayName.toUpperCase(),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textV2Tertiary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push(AppRoutes.settings),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ProfileStatsRow(
            workouts: workouts,
            streak: streak,
            followers: followers,
            following: following,
            onFollowersTap: () => context.push('/user/$targetUserId/followers'),
            onFollowingTap: () => context.push('/user/$targetUserId/following'),
          ),
          const SizedBox(height: 12),
          ProfileActionRow(postCount: postCount, targetUserId: targetUserId),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Visitor layout — centered avatar + name, prominent follow button
  // ---------------------------------------------------------------------------

  Widget _buildVisitorHeader(
    BuildContext context, {
    required User user,
    required String targetUserId,
    required String firstName,
    required String lastName,
    required bool followsMe,
    required bool isBuddy,
    required int workouts,
    required int streak,
    required int followers,
    required int following,
    required int points,
    ({int rank, bool isGlobal})? rankInfo,
  }) {
    final typeColor = _buildTypeColor(user.workoutPreference.name);
    final typeIcon = _buildTypeIcon(user.workoutPreference.name);
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              ZyntroBackButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              IconButton.filled(
                onPressed: () => _showActionMenu(context, targetUserId),
                icon: const Icon(Icons.more_horiz),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceV2,
                  foregroundColor: AppColors.textV2Secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildAvatar(user, size: 82, rankInfo: rankInfo),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textV2Primary,
                        letterSpacing: -0.7,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (user.username != null && user.username!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 13,
                          color: AppColors.textV2Secondary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (isBuddy)
                          const ProfileVisitorChip(
                            icon: Icons.people_alt_rounded,
                            label: 'BUDDY',
                            color: AppColors.accentLime,
                          ),
                        ProfileVisitorChip(
                          icon: typeIcon,
                          label: user.workoutPreference.displayName
                              .toUpperCase(),
                          color: typeColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (followsMe) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(width: 2),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accentLime,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$fullName follows you',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textV2Secondary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          ProfileFollowButton(
            targetUserId: targetUserId,
            isTargetPrivate: user.isPrivate,
            followsMe: followsMe,
            isLoading: widget.isFollowLoading,
            onFollow: widget.onFollow,
            onUnfollow: widget.onUnfollow,
          ),
          const SizedBox(height: 14),
          ProfileStatsRow(
            workouts: workouts,
            streak: streak,
            followers: followers,
            following: following,
            onFollowersTap: () => context.push('/user/$targetUserId/followers'),
            onFollowingTap: () => context.push('/user/$targetUserId/following'),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildVisitorHeaderLegacy(
    BuildContext context, {
    required User user,
    required String targetUserId,
    required String firstName,
    required String lastName,
    required bool followsMe,
    required bool isBuddy,
    required int workouts,
    required int streak,
    required int followers,
    required int following,
    required int points,
    ({int rank, bool isGlobal})? rankInfo,
  }) {
    final typeColor = _buildTypeColor(user.workoutPreference.name);
    final typeIcon = _buildTypeIcon(user.workoutPreference.name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nav row: ‹ back  ·············  ⋮ menu
          const SizedBox(height: 8),
          Row(
            children: [
              ZyntroBackButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => context.pop(),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showActionMenu(context, targetUserId);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Centered avatar + identity
          Center(
            child: Column(
              children: [
                // Avatar — larger for visitor context
                _buildAvatar(user, size: 80, rankInfo: rankInfo),
                const SizedBox(height: 14),

                // Full name — centered, lime last name
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: firstName,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textV2Primary,
                          height: 1.1,
                          letterSpacing: -0.8,
                        ),
                      ),
                      if (lastName.isNotEmpty) ...[
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: lastName,
                          style: AppTextStyles.h2.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.signal,
                            height: 1.1,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Username
                if (user.username != null && user.username!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '@${user.username}',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      color: AppColors.textV2Secondary,
                    ),
                  ),
                ],

                // Buddy label — shown when you and this person follow each other
                if (isBuddy) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.signal.withValues(alpha: 0.22),
                          AppColors.signal.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.signal.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 13,
                          color: AppColors.signal,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Buddy',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.signal,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // "Follows you" + workout type chips
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (followsMe) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceV2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.surfaceV2Active,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Follows you',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textV2Secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 11, color: typeColor),
                          const SizedBox(width: 5),
                          Text(
                            user.workoutPreference.displayName.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats row
          ProfileStatsRow(
            workouts: workouts,
            streak: streak,
            followers: followers,
            following: following,
            onFollowersTap: () => context.push('/user/$targetUserId/followers'),
            onFollowingTap: () => context.push('/user/$targetUserId/following'),
          ),
          const SizedBox(height: 12),

          // Follow button
          ProfileFollowButton(
            targetUserId: targetUserId,
            isTargetPrivate: user.isPrivate,
            isLoading: widget.isFollowLoading,
            onFollow: widget.onFollow,
            onUnfollow: widget.onUnfollow,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    User user, {
    double size = 64,
    ({int rank, bool isGlobal})? rankInfo,
  }) {
    // Ring color comes from the profile owner's chosen color, not the viewer's.
    final ringColor =
        avatarColorFromConfig(user.avatarConfig) ?? AppColors.signal;

    Widget innerAvatar;
    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      innerAvatar = ClipOval(
        child: CachedNetworkImage(
          imageUrl: user.photoURL!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) =>
              Container(width: size, height: size, color: AppColors.surfaceV2),
          errorWidget: (_, _, _) => _avatarFallback(user, size),
        ),
      );
    } else {
      innerAvatar = ClipOval(child: _avatarFallback(user, size));
    }

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 3),
      ),
      child: ClipOval(child: innerAvatar),
    );

    if (rankInfo == null) return circle;

    // Gold for global leaderboard, owner accent for friends rank.
    final badgeColor = rankInfo.isGlobal ? AppColors.accentGold : ringColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          bottom: -8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.backgroundV2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor, width: 1.5),
              ),
              child: Text(
                rankInfo.isGlobal
                    ? '#${rankInfo.rank}'
                    : '#${rankInfo.rank}',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 0.2,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(User user, double size) {
    final c = avatarColorFromConfig(user.avatarConfig);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c != null ? c.withValues(alpha: 0.20) : AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
          style: AppTextStyles.h2.copyWith(
            color: c ?? AppColors.textV2Secondary,
            fontSize: 28,
          ),
        ),
      ),
    );
  }

  void _showActionMenu(BuildContext context, String targetUserId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceV2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textV2Tertiary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.error),
              title: Text(
                'Report',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Primary,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onAction('report', targetUserId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.error),
              title: Text(
                'Block',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onAction('block', targetUserId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

}

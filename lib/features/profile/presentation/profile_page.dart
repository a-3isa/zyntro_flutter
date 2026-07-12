import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:intl/intl.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../core/constants/constants.dart';
import '../../../app/navigation/app_router.dart';
import '../../../services/user_service.dart';
import '../../../services/moderation_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/post_service.dart';
import '../../../services/session_service.dart';
import '../../moderation/presentation/report_dialog.dart';
import '../../auth/auth_providers.dart';
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
      return AppColors.userAccent;
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
// Providers
// ---------------------------------------------------------------------------

/// Provider to fetch another user's profile by ID.
final otherUserProfileProvider = StreamProvider.family<User?, String>((
  ref,
  userId,
) {
  return ref
      .watch(authFirestoreProvider)
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => doc.exists ? User.fromFirestore(doc) : null);
});

final currentUserProfileProvider = StreamProvider<User?>((ref) {
  final uid = ref.watch(authSessionProvider).value?.id;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(authFirestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? User.fromFirestore(doc) : null);
});

/// Provider for followers count.
final followersCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  return ref.watch(followServiceProvider).watchFollowersCount(userId);
});

/// Provider for following count.
final followingCountProvider = StreamProvider.family<int, String>((
  ref,
  userId,
) {
  return ref.watch(followServiceProvider).watchFollowingCount(userId);
});

/// Provider for follow status between current user and target user.
final followStatusProvider = StreamProvider.family<FollowStatus?, String>((
  ref,
  targetUserId,
) {
  final authState = ref.watch(authSessionProvider);
  final currentUserId = authState.value?.id;
  if (currentUserId == null || currentUserId == targetUserId) {
    return Stream.value(null);
  }
  return ref
      .watch(followServiceProvider)
      .watchFollowStatus(currentUserId, targetUserId);
});

/// Whether the target user follows the currently signed-in user back.
final targetFollowsCurrentProvider = StreamProvider.family<bool, String>((
  ref,
  targetUserId,
) {
  final currentUserId = ref.watch(authSessionProvider).value?.id;
  if (currentUserId == null || currentUserId == targetUserId) {
    return Stream.value(false);
  }
  return ref
      .watch(followServiceProvider)
      .watchFollowStatus(targetUserId, currentUserId)
      .map((status) => status == FollowStatus.approved);
});

/// Provider for a user's recent sessions (up to 100).
final userSessionsProvider = StreamProvider.family<List<Session>, String>((
  ref,
  userId,
) {
  return ref
      .watch(sessionServiceProvider)
      .watchUserSessions(userId, limit: 100);
});

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
          child: CircularProgressIndicator(color: AppColors.userAccent),
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
            child: CircularProgressIndicator(color: AppColors.userAccent),
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
        color: AppColors.userAccent,
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
                  indicatorColor: AppColors.userAccent,
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
              _PostsTab(
                targetUserId: targetUserId,
                isCurrentUser: isCurrentUser,
                isPrivate: user.isPrivate,
              ),
              _HistoryTab(targetUserId: targetUserId),
              _AwardsTab(targetUserId: targetUserId),
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
              child: GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppColors.textV2Secondary,
                ),
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
                              : AppColors.userAccent,
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
        avatarColorFromConfig(user.avatarConfig) ?? AppColors.userAccent;

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
                                color: AppColors.userAccent,
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
          _StatsRow(
            workouts: workouts,
            streak: streak,
            followers: followers,
            following: following,
            onFollowersTap: () => context.push('/user/$targetUserId/followers'),
            onFollowingTap: () => context.push('/user/$targetUserId/following'),
          ),
          const SizedBox(height: 12),
          _ActionRow(postCount: postCount, targetUserId: targetUserId),
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
              IconButton(
                onPressed: context.pop,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppColors.textV2Secondary,
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
                          const _VisitorChip(
                            icon: Icons.people_alt_rounded,
                            label: 'BUDDY',
                            color: AppColors.accentLime,
                          ),
                        _VisitorChip(
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
          _FollowButton(
            targetUserId: targetUserId,
            isTargetPrivate: user.isPrivate,
            followsMe: followsMe,
            isLoading: widget.isFollowLoading,
            onFollow: widget.onFollow,
            onUnfollow: widget.onUnfollow,
          ),
          const SizedBox(height: 14),
          _StatsRow(
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
              GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(right: 16, top: 4, bottom: 4),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.textV2Secondary,
                  ),
                ),
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
                            color: AppColors.userAccent,
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
                          AppColors.userAccent.withValues(alpha: 0.22),
                          AppColors.userAccent.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.userAccent.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 13,
                          color: AppColors.userAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Buddy',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.userAccent,
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
          _StatsRow(
            workouts: workouts,
            streak: streak,
            followers: followers,
            following: following,
            onFollowersTap: () => context.push('/user/$targetUserId/followers'),
            onFollowingTap: () => context.push('/user/$targetUserId/following'),
          ),
          const SizedBox(height: 12),

          // Follow button
          _FollowButton(
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
        avatarColorFromConfig(user.avatarConfig) ?? AppColors.userAccent;

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
    final badgeColor = rankInfo.isGlobal ? const Color(0xFFFFD700) : ringColor;

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

// ---------------------------------------------------------------------------
// Stats Row
// ---------------------------------------------------------------------------

class _VisitorChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _VisitorChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.7,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int workouts;
  final int streak;
  final int followers;
  final int following;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const _StatsRow({
    required this.workouts,
    required this.streak,
    required this.followers,
    required this.following,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats =
        <({String label, String value, String? emoji, VoidCallback? onTap})>[
          (
            label: 'Workouts',
            value: workouts.toString(),
            emoji: null,
            onTap: null,
          ),
          (label: 'Streak', value: streak.toString(), emoji: '🔥', onTap: null),
          (
            label: 'Followers',
            value: followers.toString(),
            emoji: null,
            onTap: onFollowersTap,
          ),
          (
            label: 'Following',
            value: following.toString(),
            emoji: null,
            onTap: onFollowingTap,
          ),
        ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceV2Active),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: List.generate(stats.length * 2 - 1, (i) {
            if (i.isOdd) {
              return VerticalDivider(
                color: AppColors.surfaceV2,
                width: 1,
                thickness: 1,
              );
            }
            final s = stats[i ~/ 2];
            final tappable = s.onTap != null;
            final cellContent = Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.value,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textV2Primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (s.emoji != null) ...[
                        const SizedBox(width: 2),
                        Text(s.emoji!, style: const TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textV2Tertiary,
                    ),
                  ),
                ],
              ),
            );
            return Expanded(
              child: tappable
                  ? GestureDetector(
                      onTap: s.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: cellContent,
                    )
                  : cellContent,
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buddies Sheet
// ---------------------------------------------------------------------------

class _BuddiesSheet extends ConsumerStatefulWidget {
  final String targetUserId;

  const _BuddiesSheet({required this.targetUserId});

  @override
  ConsumerState<_BuddiesSheet> createState() => _BuddiesSheetState();
}

class _BuddiesSheetState extends ConsumerState<_BuddiesSheet> {
  late Future<List<User>> _followersFuture;

  @override
  void initState() {
    super.initState();
    _followersFuture = ref
        .read(followServiceProvider)
        .getFollowersList(widget.targetUserId);
  }

  @override
  Widget build(BuildContext context) {
    final followersAsync = _followersFuture;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textV2Tertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Buddies',
            style: AppTextStyles.h5.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Primary,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: followersAsync,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.userAccent,
                    ),
                  );
                }
                final users = snap.data ?? [];
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No buddies yet',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: users.length,
                  itemBuilder: (_, index) {
                    final u = users[index];
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/user/${u.id}');
                      },
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceV2Elevated,
                        backgroundImage:
                            u.photoURL != null && u.photoURL!.isNotEmpty
                            ? CachedNetworkImageProvider(u.photoURL!)
                            : null,
                        child: u.photoURL == null || u.photoURL!.isEmpty
                            ? Text(
                                u.displayName.isNotEmpty
                                    ? u.displayName[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.textV2Primary,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        u.displayName,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                      subtitle: u.username != null && u.username!.isNotEmpty
                          ? Text(
                              '@${u.username}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textV2Tertiary,
                              ),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action Row (Edit Profile + Weekly Goal) — own profile only
// ---------------------------------------------------------------------------

class _ActionRow extends ConsumerWidget {
  final int postCount;
  final String targetUserId;

  const _ActionRow({required this.postCount, required this.targetUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider(targetUserId));
    final userAsync = ref.watch(currentUserProfileProvider);
    final trainingDaysGoal = (userAsync.value == null ? null : null) ?? 4;

    // Count sessions started this week
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final weeklyDone =
        sessionsAsync.value
            ?.where((s) => s.startedAt.isAfter(weekStart))
            .length ??
        0;
    final weeklyGoal = trainingDaysGoal;
    final progress = (weeklyDone / weeklyGoal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _PressableRow(
            onTap: () => context.push(AppRoutes.editProfile),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppColors.textV2Secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Edit Profile',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 13,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'THIS WEEK',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                      Text(
                        '$weeklyDone / $weeklyGoal',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: weeklyDone >= weeklyGoal
                              ? AppColors.userAccent
                              : AppColors.textV2Secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceV2Elevated,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.userAccent,
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
  final bool followsMe;
  final void Function(String, bool) onFollow;
  final void Function(String) onUnfollow;

  const _FollowButton({
    required this.targetUserId,
    required this.isTargetPrivate,
    required this.isLoading,
    this.followsMe = false,
    required this.onFollow,
    required this.onUnfollow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followStatusAsync = ref.watch(followStatusProvider(targetUserId));
    final authState = ref.watch(authSessionProvider);
    final currentUserId = authState.value?.id;

    return followStatusAsync.when(
      data: (status) {
        final bool isPrimary =
            status == null || status == FollowStatus.declined;
        final String buttonText = switch (status) {
          FollowStatus.pending => 'REQUESTED',
          FollowStatus.approved => 'FOLLOWING',
          _ => followsMe ? 'Follow back' : 'FOLLOW',
        };
        final VoidCallback? onPressed = switch (status) {
          FollowStatus.pending =>
            currentUserId == null
                ? null
                : () async {
                    await ref
                        .read(followServiceProvider)
                        .withdrawFollowRequest(currentUserId, targetUserId);
                    ref.invalidate(followStatusProvider(targetUserId));
                  },
          FollowStatus.approved => () => onUnfollow(targetUserId),
          _ => () => onFollow(targetUserId, isTargetPrivate),
        };

        return GestureDetector(
          onTap: isLoading ? null : onPressed,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isPrimary ? AppColors.userAccent : AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: isPrimary
                  ? null
                  : Border.all(color: AppColors.surfaceV2Active),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isPrimary
                            ? AppColors.backgroundV2
                            : AppColors.userAccent,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPrimary
                            ? AppColors.backgroundV2
                            : AppColors.textV2Primary,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
            ),
          ),
        );
      },
      loading: () => SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.userAccent,
          ),
        ),
      ),
      error: (_, _) => GestureDetector(
        onTap: () => onFollow(targetUserId, isTargetPrivate),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.userAccent,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: Center(
            child: Text(
              'FOLLOW',
              style: AppTextStyles.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
    if (!isCurrentUser && isPrivate) {
      final followStatusAsync = ref.watch(followStatusProvider(targetUserId));
      final isFollowing =
          followStatusAsync.value == FollowStatus.approved;
      if (!isFollowing) return _buildLocked(context);
    }

    final postsAsync = ref.watch(userPostsProvider(targetUserId));

    return postsAsync.when(
      data: (allPosts) {
        // Private (unshared) workouts are visible only to their owner.
        final posts = isCurrentUser
            ? allPosts
            : allPosts.where((p) => p.visibility != 'private').toList();
        if (posts.isEmpty) return _buildEmpty(context);

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
            final post = posts[index];
            final firstMedia = post.mediaURLs?.isNotEmpty == true
                ? post.mediaURLs!.first
                : null;

            if (firstMedia != null && firstMedia.isNotEmpty) {
              return GestureDetector(
                onTap: () => context.push('/post/${post.id}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: firstMedia,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: AppColors.surfaceV2),
                    errorWidget: (_, _, _) => Container(
                      color: AppColors.surfaceV2,
                      child: const Icon(
                        Icons.broken_image,
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  ),
                ),
              );
            }

            final type = post.type;
            final typeColor = _buildTypeColor(type);
            final typeIcon = _buildTypeIcon(type);
            final setsCount = post.summary.totalSets ?? 0;

            return GestureDetector(
              onTap: () => context.push('/post/${post.id}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
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
                    Center(
                      child: Icon(
                        typeIcon,
                        size: MediaQuery.of(context).size.width / 3 * 0.7,
                        color: typeColor.withValues(alpha: 0.12),
                      ),
                    ),
                    if (setsCount > 0)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Text(
                          '${setsCount}s',
                          style: AppTextStyles.h5.copyWith(
                            fontSize: 9,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                      ),
                    if (post.visibility == 'private')
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundV2.withValues(
                              alpha: 0.6,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 11,
                            color: AppColors.textV2Secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.userAccent,
        ),
      ),
      error: (_, _) => const SizedBox(),
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
            style: AppTextStyles.h5.copyWith(
              fontSize: 16,
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
            style: AppTextStyles.h5.copyWith(
              fontSize: 16,
              color: AppColors.textV2Secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Follow to see posts',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textV2Tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History Tab — real data
// ---------------------------------------------------------------------------

class _HistoryTab extends ConsumerWidget {
  final String targetUserId;

  const _HistoryTab({required this.targetUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider(targetUserId));

    return sessionsAsync.when(
      data: (sessions) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _WeeklyVolumeChart(sessions: sessions),
          const SizedBox(height: AppSpacing.xl),
          _ActivityHeatmap(sessions: sessions),
          const SizedBox(height: AppSpacing.xl),
          _RecentSessionsList(sessions: sessions),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
      loading: () => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.userAccent,
        ),
      ),
      error: (_, _) => Center(
        child: Text(
          'Failed to load history',
          style: AppTextStyles.body.copyWith(color: AppColors.textV2Tertiary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly Volume Bar Chart — real data
// ---------------------------------------------------------------------------

class _WeeklyVolumeChart extends StatelessWidget {
  final List<Session> sessions;

  const _WeeklyVolumeChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Build last 8 weeks: index 0 = oldest, index 7 = current week
    final List<int> weeklySets = List.filled(8, 0);
    final List<String> weekLabels = [];

    for (int w = 7; w >= 0; w--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + w * 7));
      final ws = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final we = ws.add(const Duration(days: 7));
      final idx = 7 - w;
      weeklySets[idx] = sessions
          .where((s) => s.startedAt.isAfter(ws) && s.startedAt.isBefore(we))
          .fold(0, (sum, s) => sum + (s.summary?.totalSets ?? 0));
      if (w == 0) {
        weekLabels.add('Now');
      } else if (w == 1) {
        weekLabels.add('W-1');
      } else {
        weekLabels.add('W-$w');
      }
    }
    // Reverse labels to match index order (oldest first)
    weekLabels.insertAll(0, List.generate(8, (i) => 'W-${7 - i}'));
    weekLabels.removeRange(8, weekLabels.length);
    weekLabels[7] = 'Now';

    final maxSets = weeklySets.fold(0, (m, v) => v > m ? v : m);

    // Week-over-week trend (last 2 weeks)
    final prevWeek = weeklySets[6];
    final currWeek = weeklySets[7];
    final trendStr = prevWeek == 0
        ? null
        : currWeek >= prevWeek
        ? '↑ ${(((currWeek - prevWeek) / prevWeek) * 100).round()}%'
        : '↓ ${(((prevWeek - currWeek) / prevWeek) * 100).round()}%';
    final trendColor = (currWeek >= prevWeek && prevWeek > 0)
        ? AppColors.userAccent
        : AppColors.error;

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
                'SETS / WEEK',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              if (trendStr != null)
                Text(
                  trendStr,
                  style: AppTextStyles.h5.copyWith(
                    fontSize: 13,
                    color: trendColor,
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
                final heightFactor = maxSets == 0
                    ? 0.05
                    : weeklySets[i] / maxSets;
                Color barColor;
                if (isLast) {
                  barColor = AppColors.userAccent;
                } else if (isSecondLast) {
                  barColor = AppColors.userAccent.withValues(alpha: 0.53);
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
                            heightFactor: heightFactor.clamp(0.04, 1.0),
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
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9,
                            fontWeight: isLast
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isLast
                                ? AppColors.userAccent
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
// Activity Heatmap — real data
// ---------------------------------------------------------------------------

class _ActivityHeatmap extends StatelessWidget {
  final List<Session> sessions;

  const _ActivityHeatmap({required this.sessions});

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    const days = 7;
    final now = DateTime.now();

    // Build a set of dates that had at least one session
    final activeDates = <String>{};
    for (final s in sessions) {
      activeDates.add(DateFormat('yyyy-MM-dd').format(s.startedAt));
    }

    // Count sessions per day to determine intensity
    final Map<String, int> dayCounts = {};
    for (final s in sessions) {
      final key = DateFormat('yyyy-MM-dd').format(s.startedAt);
      dayCounts[key] = (dayCounts[key] ?? 0) + 1;
    }

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
            style: AppTextStyles.caption.copyWith(
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
              // Day-of-week labels
              Column(
                children: List.generate(days, (d) {
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return SizedBox(
                    height: 13,
                    width: 10,
                    child: Center(
                      child: Text(
                        d.isEven ? labels[d] : '',
                        style: AppTextStyles.caption.copyWith(
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
                    // w=0 is oldest week, w=11 is current
                    final weeksAgo = weeks - 1 - w;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Column(
                          children: List.generate(days, (d) {
                            // Day 0 = Monday
                            final cellDate = now.subtract(
                              Duration(
                                days: now.weekday - 1 + weeksAgo * 7 - d,
                              ),
                            );
                            final dateKey = DateFormat(
                              'yyyy-MM-dd',
                            ).format(cellDate);
                            final count = dayCounts[dateKey] ?? 0;
                            final double alpha;
                            if (count == 0) {
                              alpha = 0.0;
                            } else if (count == 1) {
                              alpha = 0.4;
                            } else if (count == 2) {
                              alpha = 0.7;
                            } else {
                              alpha = 1.0;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 1.5,
                              ),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: alpha == 0.0
                                      ? AppColors.surfaceV2Elevated
                                      : AppColors.userAccent.withValues(
                                          alpha: alpha,
                                        ),
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
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              Text(
                'Today',
                style: AppTextStyles.caption.copyWith(
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
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              const SizedBox(width: 4),
              ...[0.0, 0.4, 0.7, 1.0].map(
                (a) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: a == 0.0
                        ? AppColors.surfaceV2Elevated
                        : AppColors.userAccent.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'More',
                style: AppTextStyles.caption.copyWith(
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
// Recent Sessions List — real data
// ---------------------------------------------------------------------------

class _RecentSessionsList extends StatelessWidget {
  final List<Session> sessions;

  const _RecentSessionsList({required this.sessions});

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(dt);
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return '';
    final d = end.difference(start);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          'No sessions yet',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textV2Tertiary,
          ),
        ),
      );
    }

    final recent = sessions.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT',
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textV2Tertiary,
          ),
        ),
        const SizedBox(height: 10),
        ...recent.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PressableRow(
              onTap: () => HapticFeedback.selectionClick(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundV2,
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
                            s.title.isNotEmpty ? s.title : s.type,
                            style: AppTextStyles.h5.copyWith(
                              fontSize: 14,
                              color: AppColors.textV2Primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              _formatRelativeDate(s.startedAt),
                              if (s.endedAt != null)
                                _formatDuration(s.startedAt, s.endedAt),
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: AppTextStyles.caption.copyWith(
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
                          '${s.summary?.totalSets ?? 0}',
                          style: AppTextStyles.h5.copyWith(
                            fontSize: 14,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                        Text(
                          'SETS',
                          style: AppTextStyles.caption.copyWith(
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
      loading: () => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.userAccent,
        ),
      ),
      error: (_, _) => const SizedBox(),
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
                ? AppColors.userAccent.withValues(alpha: 0.08)
                : AppColors.surfaceV2,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(badge.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              badge.name,
              style: AppTextStyles.h5.copyWith(
                fontSize: 13,
                color: isEarned
                    ? AppColors.userAccent
                    : AppColors.textV2Secondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              badge.description,
              style: AppTextStyles.caption.copyWith(
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
// Pressable Row — press-scale animation
// ---------------------------------------------------------------------------

class _PressableRow extends StatefulWidget {
  const _PressableRow({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? AppAnimations.cardPressScale : 1.0,
        duration: AppDurations.fast,
        curve: AppCurves.press,
        child: widget.child,
      ),
    );
  }
}

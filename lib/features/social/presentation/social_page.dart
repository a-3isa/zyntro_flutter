import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/premium_effects.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../services/auth_service.dart';
import '../../../services/leaderboard_service.dart';
import '../../../services/user_service.dart';
import '../../../services/workout_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/streak_widgets.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../widgets/recent_activity_card.dart';
import '../../../widgets/shimmer_widgets.dart'; // Handled in previous step
import '../../../services/user_cache_service.dart';
import '../../../utils/image_cache_manager.dart';

/// Social page with buddies, challenges, and leaderboard tabs.
/// Matches React Native SocialScreen behavior.
class SocialPage extends ConsumerStatefulWidget {
  const SocialPage({super.key});

  @override
  ConsumerState<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends ConsumerState<SocialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _activityController;
  int _currentActivityIndex = 0;

  // Buddies pagination
  final ScrollController _buddiesScrollController = ScrollController();
  List<BuddyWithPresence> _buddies = [];
  List<String> _allBuddyIds = [];
  bool _isLoadingMoreBuddies = false;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _activityController = PageController(viewportFraction: 0.9);

    _buddiesScrollController.addListener(_onBuddiesScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBuddies(refresh: true);
    });
  }

  void _onBuddiesScroll() {
    if (_buddiesScrollController.position.pixels >=
            _buddiesScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMoreBuddies &&
        _buddies.length < _allBuddyIds.length) {
      _loadBuddies();
    }
  }

  Future<void> _loadBuddies({bool refresh = false}) async {
    if (_isLoadingMoreBuddies && !refresh) return;
    if (!mounted) return;

    setState(() => _isLoadingMoreBuddies = true);

    try {
      final authState = ref.read(authStateProvider).value;
      if (authState == null) {
        if (mounted) {
          setState(() {
            _isLoadingMoreBuddies = false;
            _isInitialLoad = false;
            _buddies = [];
          });
        }
        return;
      }

      if (refresh) {
        // Fetch all IDs
        final userService = ref.read(userServiceProvider);
        _allBuddyIds = await userService.computeAndCacheBuddies(authState.uid);
        setState(() => _buddies.clear());
      }

      if (_buddies.length >= _allBuddyIds.length) {
        setState(() {
          _isLoadingMoreBuddies = false;
          _isInitialLoad = false;
        });
        return;
      }

      // Slice next chunk
      final startIndex = _buddies.length;
      final endIndex = (startIndex + 10 < _allBuddyIds.length)
          ? startIndex + 10
          : _allBuddyIds.length;
      final chunkIds = _allBuddyIds.sublist(startIndex, endIndex);

      // Fetch users using Cache Service
      final cacheService = ref.read(userCacheServiceProvider);
      final usersMap = await cacheService.fetchUsers(chunkIds);

      final newBuddies = chunkIds
          .map((id) {
            final user = usersMap[id];
            if (user == null) return null;

            // Calculate presence
            final lastActive = user.lastActive;
            // 5 minutes threshold
            final isOnline =
                lastActive != null &&
                DateTime.now().difference(lastActive).inMinutes < 5;

            return BuddyWithPresence(
              id: user.id,
              displayName: user.displayName,
              photoURL: user.photoURL,
              isOnline: isOnline,
              lastActive: lastActive,
            );
          })
          .whereType<BuddyWithPresence>()
          .toList();

      if (mounted) {
        setState(() {
          _buddies.addAll(newBuddies);
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading buddies: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMoreBuddies = false);
    }
  }

  @override
  @override
  @override
  void dispose() {
    _tabController.dispose();
    _activityController.dispose();
    _buddiesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Custom Header with TabBar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 0,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Padding(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 16,
                //     vertical: 8,
                //   ),
                //   child: const GradientText(
                //     text: 'Social',
                //     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                //     colors: [AppColors.textDark, AppColors.textSecondaryDark],
                //   ),
                // ),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondaryDark,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Buddies'),
                    Tab(text: 'Challenges'),
                    Tab(text: 'Leaderboard'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBuddiesTab(),
                _buildChallengesTab(),
                _buildLeaderboardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuddiesTab() {
    final authState = ref.watch(authStateProvider).value;
    final userId = authState?.uid ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        HapticManager.medium();
        // Invalidate the recent activity provider to refresh data
        ref.invalidate(friendsRecentActivityProvider(userId));
        await _loadBuddies(refresh: true);
      },
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      child: ListView(
        controller: _buddiesScrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryDark,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: TextField(
              style: const TextStyle(color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: AppColors.textTertiaryDark),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondaryDark,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Recent Activity Section
          if (userId.isNotEmpty) ...[
            _buildRecentActivitySection(userId),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Mutual follows section
          Text(
            'Your Buddies',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Placeholder buddies list
          // Buddies list
          if (_isInitialLoad)
            // Initial Shimmer
            ...List.generate(5, (index) => const BuddyListItemSkeleton())
          else if (_buddies.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text('No buddies yet. Search users to follow them!'),
              ),
            )
          else
            ..._buddies.map(
              (buddy) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  onTap: () => context.push('/user/${buddy.id}'),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundImage: buddy.photoURL != null
                            ? CachedNetworkImageProvider(
                                buddy.photoURL!,
                                cacheManager: ZyntroImageCacheManager(),
                              )
                            : null,
                        backgroundColor: AppColors.primaryMuted,
                        child: buddy.photoURL == null
                            ? Text(buddy.displayName[0].toUpperCase())
                            : null,
                      ),
                      if (buddy.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surfaceDark,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(buddy.displayName),
                  subtitle: Text(
                    buddy.isOnline
                        ? 'Online now'
                        : buddy.lastActive != null
                        ? 'Active ${timeago.format(buddy.lastActive!)}'
                        : 'Offline',
                    style: TextStyle(
                      color: buddy.isOnline ? AppColors.success : null,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ),
              ),
            ),

          // Loading indicator at bottom
          if (_isLoadingMoreBuddies && !_isInitialLoad)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.xl),

          // Suggestions
          const Text(
            'Suggested',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          ...List.generate(
            2,
            (index) => Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceSecondaryLight,
                  child: Text('S${index + 1}'),
                ),
                title: Text('Suggested User ${index + 1}'),
                subtitle: const Text('2 mutual friends'),
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('Follow'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the Recent Activity section with horizontal carousel.
  Widget _buildRecentActivitySection(String userId) {
    final activityAsync = ref.watch(friendsRecentActivityProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: AppFontSize.lg)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Content based on async state
        AnimatedSwitcher(
          duration: AppDurations.normal,
          switchInCurve: AppCurves.premium,
          switchOutCurve: AppCurves.premium,
          child: activityAsync.when(
            data: (activities) {
              if (activities.isEmpty) {
                return _buildEmptyActivityState();
              }
              return _buildActivityCarousel(activities);
            },
            loading: () => _buildLoadingActivityState(),
            error: (error, stack) => _buildErrorActivityState(
              () => ref.invalidate(friendsRecentActivityProvider(userId)),
            ),
          ),
        ),
      ],
    );
  }

  /// Build the horizontal activity carousel.
  /// Build the horizontal activity carousel.
  Widget _buildActivityCarousel(List<ActivityItem> activities) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _activityController,
            itemCount: activities.length,
            onPageChanged: (index) {
              setState(() => _currentActivityIndex = index);
            },
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: RecentActivityCard(
                  activity: activity,
                  heroTag: activity.isPost
                      ? 'post-card-${activity.id}'
                      : 'activity_${activity.id}',
                  onTap: () => _handleActivityTap(activity),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildActivityIndicator(activities.length),
      ],
    );
  }

  Widget _buildActivityIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _currentActivityIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.textTertiaryDark,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  /// Build loading shimmer state.
  Widget _buildLoadingActivityState() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) => const RecentActivityCardShimmer(),
      ),
    );
  }

  /// Build empty state when no recent activity.
  Widget _buildEmptyActivityState() {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 32,
            color: AppColors.textTertiaryDark,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No recent activity from your buddies',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: AppFontSize.sm,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Be the first to complete a workout today! 💪',
            style: TextStyle(
              color: AppColors.textTertiaryDark,
              fontSize: AppFontSize.xs,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build error state with retry button.
  Widget _buildErrorActivityState(VoidCallback onRetry) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 32, color: AppColors.error),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Failed to load recent activity',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: AppFontSize.sm,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  /// Handle tap on activity card with haptic feedback.
  void _handleActivityTap(ActivityItem activity) {
    HapticManager.light();
    if (activity.isPost) {
      // Navigate to post detail
      context.push('/post/${activity.id}');
    } else {
      // Navigate to user profile
      context.push('/user/${activity.userId}');
    }
  }

  Widget _buildChallengesTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text(
          'Active Challenges',
          style: TextStyle(
            fontSize: AppFontSize.lg,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Challenge cards
        ...List.generate(
          2,
          (index) => Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.md,
                          ),
                        ),
                        child: Icon(
                          index == 0
                              ? Icons.fitness_center
                              : Icons.directions_run,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              index == 0 ? '100 Push-ups' : '5K Run',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${3 - index} days left',
                              style: TextStyle(
                                fontSize: AppFontSize.sm,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LinearProgressIndicator(
                    value: 0.6 + index * 0.2,
                    backgroundColor: AppColors.primaryMuted,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${60 + index * 20}% complete',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTab() {
    final authState = ref.watch(authStateProvider).value;
    final userId = authState?.uid ?? '';

    // We'll use a local state for the toggle here since it's UI specific
    // Or we could move it to a provider. For now, let's use a ValueNotifier
    // or just a hook if we were using hooks, but we are in a StatefulWidget.
    // Actually, let's create a separate widget for the leaderboard content
    // to keep the state clean.
    return _LeaderboardContent(userId: userId);
  }
}

class _LeaderboardContent extends StatefulWidget {
  final String userId;
  const _LeaderboardContent({required this.userId});

  @override
  State<_LeaderboardContent> createState() => _LeaderboardContentState();
}

class _LeaderboardContentState extends State<_LeaderboardContent> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Type Selector - Premium styled
        Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondaryDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticManager.selection();
                    setState(() => _selectedIndex = 0);
                  },
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      gradient: _selectedIndex == 0
                          ? const LinearGradient(
                              colors: AppColors.primaryGradient,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Points',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _selectedIndex == 0
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticManager.selection();
                    setState(() => _selectedIndex = 1);
                  },
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      gradient: _selectedIndex == 1
                          ? const LinearGradient(
                              colors: AppColors.secondaryGradient,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Streak',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _selectedIndex == 1
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedIndex == 0
                    ? Icons.people
                    : Icons.local_fire_department,
                size: 20,
                color: _selectedIndex == 0
                    ? AppColors.primary
                    : AppColors.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _selectedIndex == 0
                    ? 'Friends Leaderboard'
                    : 'Streak Leaderboard',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSize.lg,
                  color: _selectedIndex == 0
                      ? AppColors.primary
                      : AppColors.secondary,
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: widget.userId.isEmpty
              ? Center(
                  child: Text(
                    'Please sign in to view leaderboard',
                    style: TextStyle(color: AppColors.textSecondaryDark),
                  ),
                )
              : _selectedIndex == 0
              ? const _PointsLeaderboard()
              : const _StreakLeaderboard(),
        ),
      ],
    );
  }
}

class _PointsLeaderboard extends ConsumerWidget {
  const _PointsLeaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).value?.uid ?? '';
    final leaderboardAsync = ref.watch(friendsLeaderboardProvider(userId));

    return leaderboardAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildList(context, entries);
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loading leaderboard...',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load leaderboard',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No friends yet',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Follow some users to see your friends leaderboard',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<LeaderboardEntry> entries) {
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        if (top3.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (top3.length > 1) _buildPodiumSpot(context, top3[1], 2, 80),
              if (top3.isNotEmpty) _buildPodiumSpot(context, top3[0], 1, 100),
              if (top3.length > 2) _buildPodiumSpot(context, top3[2], 3, 60),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        ...rest.map((entry) => _buildItem(entry)),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildPodiumSpot(
    BuildContext context,
    LeaderboardEntry entry,
    int rank,
    double height,
  ) {
    final colors = {
      1: AppColors.accent,
      2: AppColors.textSecondaryDark,
      3: AppColors.secondaryDark,
    };
    final isCurrentUser = entry.isCurrentUser;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: isCurrentUser
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 3),
                      )
                    : null,
                child: CircleAvatar(
                  radius: rank == 1 ? 32 : 26,
                  backgroundColor: colors[rank],
                  backgroundImage: entry.photoURL != null
                      ? CachedNetworkImageProvider(entry.photoURL!)
                      : null,
                  child: entry.photoURL == null
                      ? Text(
                          entry.displayName.isNotEmpty
                              ? entry.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: rank == 1 ? 24 : 18,
                          ),
                        )
                      : null,
                ),
              ),
              if (rank == 1)
                const Positioned(
                  top: -12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('👑', style: TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: 80,
            child: Text(
              entry.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: AppFontSize.sm,
                color: isCurrentUser ? AppColors.primary : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry.score} pts',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (entry.streak > 0) ...[
            const SizedBox(height: 2),
            Text(
              '🔥 ${entry.streak}',
              style: TextStyle(
                fontSize: AppFontSize.xs,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              color: colors[rank]!.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.md),
              ),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors[rank],
                  fontSize: AppFontSize.lg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(LeaderboardEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: entry.isCurrentUser
          ? AppColors.primary.withValues(alpha: 0.1)
          : null,
      shape: entry.isCurrentUser
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              side: const BorderSide(color: AppColors.primary, width: 2),
            )
          : null,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: entry.isCurrentUser ? AppColors.primary : null,
                ),
              ),
            ),
            CircleAvatar(
              backgroundColor: AppColors.surfaceSecondaryLight,
              backgroundImage: entry.photoURL != null
                  ? CachedNetworkImageProvider(entry.photoURL!)
                  : null,
              child: entry.photoURL == null
                  ? Text(
                      entry.displayName.isNotEmpty
                          ? entry.displayName[0].toUpperCase()
                          : '?',
                    )
                  : null,
            ),
          ],
        ),
        title: Text(
          entry.displayName,
          style: TextStyle(
            fontWeight: entry.isCurrentUser ? FontWeight.bold : FontWeight.w500,
            color: entry.isCurrentUser ? AppColors.primary : null,
          ),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                '${entry.score} points',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entry.streak > 0) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '🔥 ${entry.streak}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                    fontSize: AppFontSize.sm,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        trailing: entry.isCurrentUser
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _StreakLeaderboard extends ConsumerWidget {
  const _StreakLeaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value;
    final userId = authState?.uid;

    if (userId == null) {
      return const Center(child: Text('Please sign in to view leaderboard'));
    }

    final streakLeaderboardAsync = ref.watch(
      friendsStreakComparisonProvider(userId),
    );

    return streakLeaderboardAsync.when(
      data: (comparisons) {
        if (comparisons.isEmpty) {
          return Center(
            child: Text(
              'No streak data available',
              style: TextStyle(color: AppColors.textSecondaryLight),
            ),
          );
        }
        return _buildStreakList(context, comparisons);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildStreakList(
    BuildContext context,
    List<FriendStreakComparison> entries,
  ) {
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        if (top3.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (top3.length > 1)
                StreakPodiumSpot(entry: top3[1], rank: 2, height: 80),
              if (top3.isNotEmpty)
                StreakPodiumSpot(entry: top3[0], rank: 1, height: 100),
              if (top3.length > 2)
                StreakPodiumSpot(entry: top3[2], rank: 3, height: 60),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        ...rest.map((entry) => StreakListItem(entry: entry)),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../app/navigation/app_router.dart';
import '../../../core/models/models.dart';
import '../../auth/auth_providers.dart';
import '../../../services/post_service.dart';
import '../../../services/moderation_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/user_cache_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../utils/image_cache_manager.dart';
import '../../../widgets/widgets.dart';
import '../../../widgets/reaction_buttons.dart';
import '../../moderation/presentation/report_dialog.dart';

/// Feed page showing posts with Public and Following tabs.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key, this.onSessionTap});

  final VoidCallback? onSessionTap;

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: Column(
          children: [
            _V2FeedHeader(
              onNotificationsTap: () => context.push(AppRoutes.notifications),
              onSessionTap: widget.onSessionTap,
              tabController: _tabController,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FeedTab(
                    fetchPosts: (cursor) async {
                      final authState = ref.read(authSessionProvider);
                      final uid = authState.valueOrNull?.id;
                      if (uid == null) {
                        return FeedResult(
                          posts: [],
                          cursor: FeedCursor(hasMore: false),
                        );
                      }
                      final followingIds = await ref
                          .read(followServiceProvider)
                          .getFollowingIds(uid);
                      return ref.read(postServiceProvider).getFollowingPosts(
                        currentUserId: uid,
                        followingIds: followingIds,
                        limit: 10,
                        startAfterDoc: cursor?.lastDoc,
                      );
                    },
                    feedKey: 'following',
                    requiresAuth: true,
                    showHeaderWidgets: true,
                  ),
                  _FeedTab(
                    fetchPosts: (cursor) => ref
                        .read(postServiceProvider)
                        .getPublicPosts(
                          limit: 10,
                          startAfterDoc: cursor?.lastDoc,
                        ),
                    feedKey: 'public',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// v2 Feed header: ZYNTRO wordmark + theme toggle + tab pill
class _V2FeedHeader extends StatelessWidget {
  final VoidCallback onNotificationsTap;
  final VoidCallback? onSessionTap;
  final TabController tabController;

  const _V2FeedHeader({
    required this.onNotificationsTap,
    this.onSessionTap,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'zyntro',
                style: GoogleFonts.syne(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textV2Primary,
                  letterSpacing: -0.8,
                ),
              ),
              const Spacer(),
              
              GestureDetector(
                onTap: onNotificationsTap,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.notifications_outlined,
                          color: AppColors.textV2Secondary,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.accentLime,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.backgroundV2,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),if (onSessionTap != null) ...[
                GestureDetector(
                  onTap: onSessionTap,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.people_outline,
                      color: AppColors.textV2Secondary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Tab pill
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: tabController,
              indicator: BoxDecoration(
                color: AppColors.surfaceV2Active,
                borderRadius: BorderRadius.circular(9),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.textV2Primary,
              unselectedLabelColor: AppColors.textV2Secondary,
              labelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Following'),
                Tab(text: 'Discover'),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _FeedTab extends ConsumerStatefulWidget {
  final Future<FeedResult> Function(FeedCursor?) fetchPosts;
  final String feedKey;
  final bool requiresAuth;
  final bool showHeaderWidgets;

  const _FeedTab({
    required this.fetchPosts,
    required this.feedKey,
    this.requiresAuth = false,
    this.showHeaderWidgets = false,
  });

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab>
    with AutomaticKeepAliveClientMixin {
  final List<Post> _posts = [];
  bool _isLoading = true;
  bool _hasMore = true;
  FeedCursor? _lastCursor;
  bool _isLoadingMore = false;
  String? _error;

  // Scroll controller for infinite scroll
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  Timer? _loadMoreDebounce;

  // Cache for reactions
  final Map<String, ReactionType?> _userReactions = {};
  final Map<String, Map<ReactionType, int>> _reactionCounts = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  void _onScroll() {
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Show/hide scroll-to-top FAB
    if (currentScroll > 500 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (currentScroll <= 500 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }

    // Infinite scroll trigger at 80% threshold with debounce
    if (currentScroll >= maxScroll * 0.8 && !_isLoadingMore && _hasMore) {
      _loadMoreDebounce?.cancel();
      _loadMoreDebounce = Timer(const Duration(milliseconds: 200), _loadMore);
    }
  }

  void _scrollToTop() {
    HapticManager.light();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _loadMoreDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (widget.requiresAuth) {
      final authState = ref.read(authSessionProvider);
      if (authState.valueOrNull?.id == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = "Please sign in";
          });
        }
        return;
      }
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final result = await widget.fetchPosts(null);

      // Batch fetch authors
      final authorIds = result.posts.map((p) => p.authorId).toList();
      await ref.read(userCacheServiceProvider).fetchUsers(authorIds);

      // Fetch reaction data for all posts
      await _fetchReactionData(result.posts);

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(result.posts);
          _lastCursor = result.cursor;
          _hasMore = result.cursor.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      setState(() => _isLoadingMore = true);
      final result = await widget.fetchPosts(_lastCursor);

      // Batch fetch authors
      final authorIds = result.posts.map((p) => p.authorId).toList();
      await ref.read(userCacheServiceProvider).fetchUsers(authorIds);

      // Fetch reaction data for new posts
      await _fetchReactionData(result.posts);

      if (mounted) {
        setState(() {
          _posts.addAll(result.posts);
          _lastCursor = result.cursor;
          _hasMore = result.cursor.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    _lastCursor = null;
    _hasMore = true;
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for KeepAlive

    // Watch blocked user IDs for filtering
    final blockedUserIdsAsync = ref.watch(blockedUserIdsProvider);
    final blockedUserIds = blockedUserIdsAsync.valueOrNull ?? [];

    if (_isLoading) {
      // Shimmer loading state
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 3,
        itemBuilder: (context, index) =>
            const PostCardSkeleton(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textV2Primary,
                fontSize: AppFontSize.lg,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: AppColors.textV2Secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                HapticManager.light();
                _loadInitial();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Filter out posts from blocked users
    final filteredPosts = _posts
        .where((post) => !blockedUserIds.contains(post.authorId))
        .toList();

    if (filteredPosts.isEmpty) {
      // Empty state - dark themed with animation
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Elevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center,
                size: 48,
                color: AppColors.textV2Secondary,
              ),
            ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No posts yet',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textV2Primary,
                  fontSize: AppFontSize.lg,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Follow some users to see their workouts',
                style: TextStyle(color: AppColors.textV2Secondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () {
                  HapticManager.light();
                  _refresh();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text('Refresh'),
              ),
            ],
          ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            HapticManager.medium();
            await _refresh();
          },
          color: AppColors.accentLime,
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: 500,
            padding: EdgeInsets.zero,
            itemCount: filteredPosts.length + 1 + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                return widget.showHeaderWidgets
                    ? _buildHeaderWidgets()
                    : const SizedBox.shrink();
              }

              if (index == filteredPosts.length + 1) {
                // Shimmer loading indicator at bottom
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Loading more...',
                        style: TextStyle(
                          color: AppColors.textV2Secondary,
                          fontSize: AppFontSize.sm,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final postIndex = index - 1;
              return _buildPostCard(filteredPosts[postIndex]);
            },
          ),
        ),
        // Scroll-to-top FAB
        if (_showScrollToTop)
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderWidgets() {
    return const SizedBox.shrink();
  }

  /// Fetch reaction data (counts and user's reaction) for a list of posts.
  Future<void> _fetchReactionData(List<Post> posts) async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    final postService = ref.read(postServiceProvider);

    // Fetch reaction counts and user reactions in parallel
    await Future.wait(
      posts.map((post) async {
        try {
          final counts = await postService.getReactionCounts(post.id);
          _reactionCounts[post.id] = counts;

          if (uid != null) {
            final reaction = await postService.getUserReaction(post.id, uid);
            _userReactions[post.id] = reaction;
          }
        } catch (e) {
          // Silently fail for individual posts
        }
      }),
    );
  }

  Widget _buildPostCard(Post post) {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    final isOwnPost = currentUserId == post.authorId;

    final author = ref.watch(userCacheServiceProvider).getUserSync(post.authorId);
    final authorName = author?.displayName ?? 'User';
    final hasImage = post.mediaURLs != null && post.mediaURLs!.isNotEmpty;
    final typeColor = AppColors.typeColor(post.type);
    const t2 = AppColors.textV2Secondary;
    const s1 = AppColors.surfaceV2;

    return GestureDetector(
      onTap: () {
        HapticManager.light();
        context.push('/post/${post.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo / placeholder area — 280px tall
            SizedBox(
              height: 280,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or radial gradient placeholder
                  if (hasImage)
                    Hero(
                      tag: 'post-card-${post.id}',
                      child: CachedNetworkImage(
                        cacheManager: ZyntroImageCacheManager(),
                        imageUrl: post.mediaURLs!.first,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: [
                            typeColor.withValues(alpha: 0.22),
                            AppColors.backgroundV2,
                          ],
                        ),
                      ),
                    ),
                  // Type icon watermark
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: 0.05,
                        child: _workoutTypeIcon(post.type, size: 120),
                      ),
                    ),
                  ),
                  // Bottom gradient fade
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    height: 120,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Author overlay at bottom
                  Positioned(
                    left: 16, right: 16, bottom: 14,
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            color: AppColors.surfaceV2Elevated,
                          ),
                          child: ClipOval(
                            child: author?.photoURL != null
                                ? CachedNetworkImage(
                                    imageUrl: author!.photoURL!,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      authorName.isNotEmpty
                                          ? authorName[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.syne(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.title,
                            style: GoogleFonts.syne(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // More menu (own-post check)
                  if (!isOwnPost)
                    Positioned(
                      top: 12, right: 8,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 20),
                        onSelected: (value) => _handlePostAction(
                          action: value,
                          post: post,
                          authorName: authorName,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'report_post', child: Text('Report Post')),
                          const PopupMenuItem(value: 'report_user', child: Text('Report User')),
                          const PopupMenuItem(
                            value: 'block_user',
                            child: Text('Block User', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Action row below photo
            Container(
              color: s1,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Reactions
                  ReactionButtons(
                    postId: post.id,
                    currentReaction: _userReactions[post.id],
                    reactionCounts: _reactionCounts[post.id] ?? {},
                    onReactionTap: (type) => _handleReaction(post, type),
                  ),
                  const Spacer(),
                  // Comments
                  if (FeatureFlags.isCommentsEnabled) ...[
                    Icon(Icons.mode_comment_outlined, size: 17, color: t2),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t2,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Workout type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      post.type.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Divider between cards
            Container(
              height: 8,
              color: AppColors.backgroundV2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _workoutTypeIcon(String type, {double size = 24}) {
    final icons = {
      'gym': Icons.fitness_center,
      'cardio': Icons.directions_run,
      'hiit': Icons.flash_on,
      'cycling': Icons.directions_bike,
      'yoga': Icons.self_improvement,
      'swimming': Icons.pool,
    };
    final color = AppColors.typeColor(type);
    return Icon(icons[type] ?? Icons.fitness_center, size: size, color: color);
  }

  /// Handle reaction tap - toggle or change reaction type with haptic feedback.
  Future<void> _handleReaction(Post post, ReactionType type) async {
    // Haptic feedback on reaction
    HapticManager.medium();

    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid == null) return;

    final currentReaction = _userReactions[post.id];
    final oldCounts = Map<ReactionType, int>.from(
      _reactionCounts[post.id] ?? {},
    );

    // Optimistic update
    setState(() {
      if (currentReaction == type) {
        // Same reaction - remove it
        _userReactions[post.id] = null;
        _reactionCounts[post.id] = {
          ...oldCounts,
          type: (oldCounts[type] ?? 1) - 1,
        };
      } else {
        // New or different reaction
        if (currentReaction != null) {
          // Decrement old reaction count
          _reactionCounts[post.id] = {
            ...oldCounts,
            currentReaction: (oldCounts[currentReaction] ?? 1) - 1,
            type: (oldCounts[type] ?? 0) + 1,
          };
        } else {
          _reactionCounts[post.id] = {
            ...oldCounts,
            type: (oldCounts[type] ?? 0) + 1,
          };
        }
        _userReactions[post.id] = type;
      }
    });

    try {
      final postService = ref.read(postServiceProvider);
      if (currentReaction == type) {
        // Remove reaction
        await postService.removeReaction(post.id, uid);
      } else {
        // Add or update reaction
        await postService.reactToPost(post.id, uid, type: type);
      }
    } catch (e) {
      // Revert on error with error haptic
      HapticManager.error();
      setState(() {
        _userReactions[post.id] = currentReaction;
        _reactionCounts[post.id] = oldCounts;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to react: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle post action menu selection (report/block)
  Future<void> _handlePostAction({
    required String action,
    required Post post,
    required String authorName,
  }) async {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    if (currentUserId == null) return;

    switch (action) {
      case 'report_post':
        await ReportDialog.show(
          context,
          reportedPostId: post.id,
          postAuthorId: post.authorId,
          reportedUserName: authorName,
        );
        break;

      case 'report_user':
        await ReportDialog.show(
          context,
          reportedUserId: post.authorId,
          reportedUserName: authorName,
        );
        break;

      case 'block_user':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block User'),
            content: Text(
              'Are you sure you want to block $authorName? '
              'You will no longer see their posts or comments.',
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

        if (confirmed == true && mounted) {
          try {
            await ref
                .read(moderationServiceProvider)
                .blockUser(currentUserId, post.authorId);
            // Invalidate blocked users provider to refresh the list
            ref.invalidate(blockedUserIdsProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$authorName has been blocked'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
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
}

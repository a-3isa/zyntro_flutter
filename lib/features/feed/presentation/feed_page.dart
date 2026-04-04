import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

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
import '../../../widgets/photo_viewer_page.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/reaction_buttons.dart';
import '../../moderation/presentation/report_dialog.dart';

/// Feed page showing posts with Public and Following tabs.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

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
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Compact navigation bar indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.borderDark.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Tab indicator pills
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondaryDark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondaryDark,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                        ),
                        tabs: const [
                          Tab(text: 'Following'),
                          Tab(text: 'Discover'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Notification button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.borderDark.withValues(alpha: 0.5),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.textDark,
                        size: 20,
                      ),
                      onPressed: () => context.push(AppRoutes.notifications),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            // Tab content
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

                      return ref
                          .read(postServiceProvider)
                          .getFollowingPosts(
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
            SlideInAnimation(index: index, child: const PostCardSkeleton()),
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
                color: AppColors.textDark,
                fontSize: AppFontSize.lg,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: AppColors.textSecondaryDark),
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
        child: FadeInAnimation(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PulseAnimation(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No posts yet',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontSize: AppFontSize.lg,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Follow some users to see their workouts',
                style: TextStyle(color: AppColors.textSecondaryDark),
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
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceDark,
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: 500,
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                          color: AppColors.textSecondaryDark,
                          fontSize: AppFontSize.sm,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final postIndex = index - 1;
              return SlideInAnimation(
                index: postIndex,
                delay: const Duration(milliseconds: 30),
                child: _buildPostCard(filteredPosts[postIndex]),
              );
            },
          ),
        ),
        // Scroll-to-top FAB
        if (_showScrollToTop)
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: FadeInAnimation(
              child: FloatingActionButton.small(
                onPressed: _scrollToTop,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderWidgets() {
    return Column(
      children: const [
        BuddiesActivityCarousel(),
        StreakCard(days: 3),
        DailyQuote(),
      ],
    );
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

    final author = ref
        .watch(userCacheServiceProvider)
        .getUserSync(post.authorId);
    final authorName = author?.displayName ?? 'User';
    final hasImage = post.mediaURLs != null && post.mediaURLs!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      decoration: GlassDecoration.card.copyWith(
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // If hasImage, put the image FIRST, edge to edge at the top
          if (hasImage)
            GestureDetector(
              onTap: () {
                HapticManager.light();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhotoViewerPage(
                      imageUrl: post.mediaURLs!.first,
                      heroTag: 'post-card-${post.id}',
                    ),
                  ),
                );
              },
              child: Hero(
                tag: 'post-card-${post.id}',
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 400, minHeight: 250),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        cacheManager: ZyntroImageCacheManager(),
                        imageUrl: post.mediaURLs!.first,
                        fit: BoxFit.cover,
                      ),
                      // Gradient overlay for author row contrast
                      Positioned(
                        top: 0, left: 0, right: 0,
                        height: 120,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Author Row overlaid on top of image
                      Positioned(
                        top: AppSpacing.lg,
                        left: AppSpacing.lg,
                        right: AppSpacing.md,
                        child: _buildAuthorRow(post, author, authorName, isOwnPost, true),
                      ),
                      if (post.mediaURLs!.length > 1)
                        Positioned(
                          bottom: AppSpacing.md,
                          right: AppSpacing.md,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: GlassDecoration.card.copyWith(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library, color: Colors.white, size: 16),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '${post.mediaURLs!.length}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasImage)
                  _buildAuthorRow(post, author, authorName, isOwnPost, false),
                  
                if (!hasImage) const SizedBox(height: AppSpacing.md),
                
                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: AppFontSize.xl,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Stats area with glass effect
                if (post.summary.totalExercises != null ||
                    post.summary.totalSets != null ||
                    post.summary.duration != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: GlassDecoration.elevated.copyWith(
                      color: AppColors.surfaceSecondaryDark.withValues(alpha: 0.3),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStat('Exercises', '${post.summary.totalExercises ?? 0}'),
                            _buildStat('Sets', '${post.summary.totalSets ?? 0}'),
                            if (post.summary.duration != null)
                              _buildStat('Duration', post.summary.duration!)
                            else
                              _buildStat('Type', post.type.toUpperCase()),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),

                // Actions area below everything
                Row(
                  children: [
                    Expanded(
                      child: ReactionButtons(
                        postId: post.id,
                        currentReaction: _userReactions[post.id],
                        reactionCounts: _reactionCounts[post.id] ?? {},
                        onReactionTap: (type) => _handleReaction(post, type),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    if (FeatureFlags.isCommentsEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondaryDark,
                          borderRadius: BorderRadius.circular(AppBorderRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                               onTap: () => context.push('/post/${post.id}'),
                               child: const Icon(Icons.mode_comment_outlined, size: 20, color: AppColors.textSecondaryDark)),
                            const SizedBox(width: AppSpacing.xs),
                            Text('${post.commentsCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondaryDark)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorRow(Post post, dynamic author, String authorName, bool isOwnPost, bool overlaid) {
    final textColor = overlaid ? Colors.white : AppColors.textDark;
    final secondaryTextColor = overlaid ? Colors.white70 : AppColors.textSecondaryDark;
    
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (author != null) context.push('/user/${author.id}');
          },
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: FluttermojiAvatar(
                  avatarConfig: author?.avatarConfig,
                  photoUrl: author?.photoURL,
                  displayName: authorName,
                  size: 40,
                  showGradientBorder: false,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: AppFontSize.md),
                  ),
                  Text(
                    timeago.format(post.createdAt),
                    style: TextStyle(fontSize: AppFontSize.sm, color: secondaryTextColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        if (!isOwnPost)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: textColor),
            onSelected: (value) => _handlePostAction(action: value, post: post, authorName: authorName),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'report_post', child: Text('Report Post')),
              const PopupMenuItem(value: 'report_user', child: Text('Report User')),
              const PopupMenuItem(value: 'block_user', child: Text('Block User', style: TextStyle(color: Colors.red))),
            ],
          ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: AppFontSize.lg,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.sm,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
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

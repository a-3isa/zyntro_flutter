import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/theme/app_theme.dart';
import '../core/constants/feature_flags.dart';

import '../core/models/models.dart';
import '../features/auth/auth_providers.dart';
import '../services/post_service.dart';
import '../services/moderation_service.dart';
import '../services/user_cache_service.dart';
import '../features/moderation/presentation/report_dialog.dart';
import '../utils/responsive_utils.dart';
import 'photo_viewer_page.dart';
import 'reaction_buttons.dart';
import '../utils/image_cache_manager.dart';
import 'fluttermoji_avatar.dart';

/// Display mode for the post card.
enum PostCardDisplayMode {
  /// Full display with all details, reactions, comments.
  full,

  /// Compact display for grid views - shows thumbnail and basic info.
  compact,

  /// Minimal display - just image/icon with overlay title.
  minimal,
}

/// Reusable post card widget that can be used in feed, profile, and other pages.
class PostCardWidget extends ConsumerStatefulWidget {
  final Post post;
  final PostCardDisplayMode displayMode;
  final VoidCallback? onTap;
  final bool showAuthorHeader;
  final bool showReactions;
  final bool showOverflowMenu;

  const PostCardWidget({
    super.key,
    required this.post,
    this.displayMode = PostCardDisplayMode.full,
    this.onTap,
    this.showAuthorHeader = true,
    this.showReactions = true,
    this.showOverflowMenu = true,
  });

  @override
  ConsumerState<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends ConsumerState<PostCardWidget> {
  ReactionType? _userReaction;
  Map<ReactionType, int> _reactionCounts = {};
  bool _isLoadingReactions = true;

  @override
  void initState() {
    super.initState();
    if (widget.displayMode == PostCardDisplayMode.full) {
      _fetchReactionData();
    }
  }

  Future<void> _fetchReactionData() async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;
    final postService = ref.read(postServiceProvider);

    try {
      final counts = await postService.getReactionCounts(widget.post.id);
      if (uid != null) {
        final reaction = await postService.getUserReaction(widget.post.id, uid);
        if (mounted) {
          setState(() {
            _userReaction = reaction;
          });
        }
      }
      if (mounted) {
        setState(() {
          _reactionCounts = counts;
          _isLoadingReactions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReactions = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.displayMode) {
      case PostCardDisplayMode.full:
        return _buildFullCard(context);
      case PostCardDisplayMode.compact:
        return _buildCompactCard(context);
      case PostCardDisplayMode.minimal:
        return _buildMinimalCard(context);
    }
  }

  Widget _buildFullCard(BuildContext context) {
    if (widget.post.coAuthored) {
      return _buildJointFullCard(context);
    }

    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.value?.id;
    final isOwnPost = currentUserId == widget.post.authorId;

    final author = ref
        .watch(userCacheServiceProvider)
        .getUserSync(widget.post.authorId);
    final authorName = author?.displayName ?? 'User';

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: InkWell(
          onTap: widget.onTap ?? () => context.push('/post/${widget.post.id}'),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row with overflow menu
                if (widget.showAuthorHeader)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            context.push('/user/${widget.post.authorId}'),
                        child: Hero(
                          tag: 'avatar-${widget.post.authorId}',
                          child: FluttermojiAvatar(
                            photoUrl: author?.photoURL,
                            displayName: authorName,
                            size: 40,
                            showGradientBorder: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              context.push('/user/${widget.post.authorId}'),
                          child: Semantics(
                            button: true,
                            label: 'View profile of $authorName',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  timeago.format(widget.post.createdAt),
                                  style: TextStyle(
                                    fontSize: AppFontSize.sm,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Overflow menu for Report/Block
                      if (widget.showOverflowMenu && !isOwnPost)
                        Semantics(
                          label: 'Post Options',
                          button: true,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) => _handlePostAction(
                              action: value,
                              authorName: authorName,
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'report_post',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined, size: 20),
                                    SizedBox(width: 8),
                                    Text('Report Post'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'report_user',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_off_outlined, size: 20),
                                    SizedBox(width: 8),
                                    Text('Report User'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'block_user',
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
                        ),
                    ],
                  ),

                if (widget.showAuthorHeader)
                  const SizedBox(height: AppSpacing.md),

                // Title
                Text(
                  widget.post.title,
                  style: const TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Post Image (tappable for full-screen view) with CachedNetworkImage
                if (widget.post.mediaURLs != null &&
                    widget.post.mediaURLs!.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoViewerPage(
                          imageUrl: widget.post.mediaURLs!.first,
                          heroTag: 'post-image-${widget.post.id}',
                        ),
                      ),
                    ),
                    child: Semantics(
                      button: true,
                      label: 'View full image',
                      hint: 'Double tap to zoom',
                      child: Hero(
                        tag: 'post-image-${widget.post.id}',
                        child: Container(
                          height: context.responsive(
                            mobile: 180.0,
                            desktop: 220.0,
                          ),
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.md,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.md,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  cacheManager: ZyntroImageCacheManager(),
                                  imageUrl: widget.post.mediaURLs!.first,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceV2,
                                      borderRadius: BorderRadius.circular(
                                        AppBorderRadius.md,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: Colors.grey[200],
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image_outlined,
                                              size: 40,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.sm,
                                            ),
                                            Text(
                                              'Failed to load image',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: AppFontSize.sm,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.sm,
                                            ),
                                            TextButton.icon(
                                              onPressed: () {
                                                // Force rebuild to retry
                                                (context as Element)
                                                    .markNeedsBuild();
                                              },
                                              icon: const Icon(
                                                Icons.refresh,
                                                size: 16,
                                              ),
                                              label: const Text('Retry'),
                                            ),
                                          ],
                                        ),
                                      ),
                                ),
                                // Gradient overlay at bottom for text readability
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.5),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Fullscreen icon overlay
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Stats section
                if (widget.post.summary.totalExercises != null ||
                    widget.post.summary.totalSets != null ||
                    widget.post.summary.duration != null)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2Elevated,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat(
                                'Exercises',
                                '${widget.post.summary.totalExercises ?? 0}',
                              ),
                              _buildStat(
                                'Sets',
                                '${widget.post.summary.totalSets ?? 0}',
                              ),
                              if (widget.post.summary.duration != null)
                                _buildStat(
                                  'Duration',
                                  widget.post.summary.duration!,
                                )
                              else
                                _buildStat(
                                  'Type',
                                  widget.post.type.toUpperCase(),
                                ),
                            ],
                          ),
                          // Exercise list (top 3)
                          if (widget.post.summary.exercises != null &&
                              widget.post.summary.exercises!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.sm),
                            ...widget.post.summary.exercises!
                                .take(3)
                                .map(
                                  (exercise) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.xs,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.fitness_center,
                                          size: 14,
                                          color: AppColors.userAccent,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            exercise.name,
                                            style: const TextStyle(
                                              fontSize: AppFontSize.sm,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${exercise.sets} sets',
                                          style: TextStyle(
                                            fontSize: AppFontSize.sm,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            if (widget.post.summary.exercises!.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Text(
                                  '+${widget.post.summary.exercises!.length - 3} more',
                                  style: TextStyle(
                                    fontSize: AppFontSize.xs,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),

                // Actions - Reaction buttons
                if (widget.showReactions)
                  Row(
                    children: [
                      Expanded(
                        child: _isLoadingReactions
                            ? const SizedBox(height: 40)
                            : ReactionButtons(
                                postId: widget.post.id,
                                currentReaction: _userReaction,
                                reactionCounts: _reactionCounts,
                                onReactionTap: _handleReaction,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (FeatureFlags.isCommentsEnabled)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.comment_outlined),
                              onPressed: () =>
                                  context.push('/post/${widget.post.id}'),
                            ),
                            Text('${widget.post.commentsCount}'),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Renders a co-authored ("joint") post: a "{A} with {B}" header with
  /// stacked avatars, both authors' photos side by side, both captions
  /// attributed to their author, and an expandable "Session activity"
  /// section with both authors' summaries. Authors marked `removed` on
  /// their slot are skipped entirely.
  Widget _buildJointFullCard(BuildContext context) {
    final userCache = ref.watch(userCacheServiceProvider);

    final allAuthorIds = widget.post.authorIds.isNotEmpty
        ? widget.post.authorIds
        : widget.post.authors.keys.toList();
    final activeAuthorIds = allAuthorIds
        .where((uid) => widget.post.authors[uid]?.removed != true)
        .toList();

    String nameFor(String uid) =>
        userCache.getUserSync(uid)?.displayName ?? 'User';

    final headerTitle = activeAuthorIds.isEmpty
        ? widget.post.title
        : activeAuthorIds.length == 1
            ? nameFor(activeAuthorIds.first)
            : '${nameFor(activeAuthorIds.first)} with '
                '${activeAuthorIds.skip(1).map(nameFor).join(', ')}';

    return RepaintBoundary(
      child: Card(
        key: const ValueKey('joint_post_card'),
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: InkWell(
          onTap:
              widget.onTap ?? () => context.push('/post/${widget.post.id}'),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showAuthorHeader)
                  Row(
                    children: [
                      SizedBox(
                        width: 40 + 24.0 * (activeAuthorIds.length - 1),
                        height: 40,
                        child: Stack(
                          children: [
                            for (var i = 0; i < activeAuthorIds.length; i++)
                              Positioned(
                                left: 24.0 * i,
                                child: FluttermojiAvatar(
                                  photoUrl: userCache
                                      .getUserSync(activeAuthorIds[i])
                                      ?.photoURL,
                                  displayName: nameFor(activeAuthorIds[i]),
                                  size: 40,
                                  showGradientBorder: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headerTitle,
                              key: const ValueKey('joint_post_card_header'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              timeago.format(widget.post.createdAt),
                              style: TextStyle(
                                fontSize: AppFontSize.sm,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                if (widget.showAuthorHeader)
                  const SizedBox(height: AppSpacing.md),

                // Title
                Text(
                  widget.post.title,
                  style: const TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Both authors' photos, side by side.
                Row(
                  children: [
                    for (final uid in activeAuthorIds)
                      _buildJointPhotoTile(context, uid),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Both authors' captions, attributed.
                for (final uid in activeAuthorIds) _buildJointCaption(uid),
                if (activeAuthorIds.isNotEmpty)
                  const SizedBox(height: AppSpacing.sm),

                // Expandable "Session activity" showing both summaries.
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    key: const ValueKey('joint_post_card_activity'),
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Session activity'),
                    children: [
                      for (final uid in activeAuthorIds)
                        ListTile(
                          key: ValueKey('joint_post_card_activity_$uid'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(nameFor(uid)),
                          subtitle: Text(
                            _jointSummaryLine(
                              widget.post.authors[uid]?.summary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Actions - Reaction buttons
                if (widget.showReactions)
                  Row(
                    children: [
                      Expanded(
                        child: _isLoadingReactions
                            ? const SizedBox(height: 40)
                            : ReactionButtons(
                                postId: widget.post.id,
                                currentReaction: _userReaction,
                                reactionCounts: _reactionCounts,
                                onReactionTap: _handleReaction,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (FeatureFlags.isCommentsEnabled)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.comment_outlined),
                              onPressed: () =>
                                  context.push('/post/${widget.post.id}'),
                            ),
                            Text('${widget.post.commentsCount}'),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A single author's photo tile in the joint card's side-by-side media
  /// row: their `authors[uid].photoUrl` when set, otherwise their profile
  /// picture (via [FluttermojiAvatar], same fallback used for the solo
  /// header avatar) so the tile is never left blank.
  Widget _buildJointPhotoTile(BuildContext context, String uid) {
    final userCache = ref.watch(userCacheServiceProvider);
    final user = userCache.getUserSync(uid);
    final displayName = user?.displayName ?? 'User';
    final photoUrl = widget.post.authors[uid]?.photoUrl;
    final height = context.responsive(mobile: 180.0, desktop: 220.0);
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Expanded(
      child: Container(
        key: ValueKey('joint_post_card_photo_$uid'),
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceV2Elevated,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          child: hasPhoto
              ? CachedNetworkImage(
                  cacheManager: ZyntroImageCacheManager(),
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.surfaceV2,
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: FluttermojiAvatar(
                      photoUrl: user?.photoURL,
                      displayName: displayName,
                      size: 56,
                      showGradientBorder: false,
                    ),
                  ),
                )
              : Center(
                  child: FluttermojiAvatar(
                    photoUrl: user?.photoURL,
                    displayName: displayName,
                    size: 56,
                    showGradientBorder: false,
                  ),
                ),
        ),
      ),
    );
  }

  /// One author's attributed caption line in the joint card. Renders
  /// nothing when that author left no caption.
  Widget _buildJointCaption(String uid) {
    final userCache = ref.watch(userCacheServiceProvider);
    final name = userCache.getUserSync(uid)?.displayName ?? 'User';
    final caption = widget.post.authors[uid]?.caption;
    if (caption == null || caption.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: ValueKey('joint_post_card_caption_$uid'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$name: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: caption),
          ],
        ),
      ),
    );
  }

  /// Short human-readable summary of one author's session slot, for the
  /// "Session activity" expandable section.
  String _jointSummaryLine(SessionSummary? summary) {
    if (summary == null) return 'No activity recorded';
    final parts = <String>[];
    if (summary.totalExercises != null) {
      parts.add('${summary.totalExercises} exercises');
    }
    if (summary.totalSets != null) {
      parts.add('${summary.totalSets} sets');
    }
    if (summary.duration != null) {
      parts.add(summary.duration!);
    }
    if (summary.distance != null) {
      parts.add('${summary.distance} km');
    }
    return parts.isEmpty ? 'No activity recorded' : parts.join(' • ');
  }

  Widget _buildCompactCard(BuildContext context) {
    final hasImage =
        widget.post.mediaURLs != null && widget.post.mediaURLs!.isNotEmpty;
    final typeIcon = widget.post.type == 'strength'
        ? Icons.fitness_center
        : Icons.directions_run;
    final typeColor = widget.post.type == 'strength'
        ? AppColors.userAccent
        : AppColors.secondary;

    return RepaintBoundary(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap ?? () => context.push('/post/${widget.post.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image or icon placeholder
              AspectRatio(
                aspectRatio: 1,
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: widget.post.mediaURLs!.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: typeColor.withValues(alpha: 0.1),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: typeColor.withValues(alpha: 0.1),
                          child: Icon(typeIcon, size: 32, color: typeColor),
                        ),
                      )
                    : Container(
                        color: typeColor.withValues(alpha: 0.1),
                        child: Center(
                          child: Icon(typeIcon, size: 32, color: typeColor),
                        ),
                      ),
              ),
              // Title and stats
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppFontSize.sm,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.post.summary.totalSets ?? 0} sets',
                          style: TextStyle(
                            fontSize: AppFontSize.xs,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalCard(BuildContext context) {
    final hasImage =
        widget.post.mediaURLs != null && widget.post.mediaURLs!.isNotEmpty;
    final typeIcon = widget.post.type == 'strength'
        ? Icons.fitness_center
        : Icons.directions_run;
    final typeColor = widget.post.type == 'strength'
        ? AppColors.userAccent
        : AppColors.secondary;

    return AspectRatio(
      aspectRatio: 1,
      child: RepaintBoundary(
        child: Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap:
                widget.onTap ?? () => context.push('/post/${widget.post.id}'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background - image or icon with CachedNetworkImage
                if (hasImage)
                  CachedNetworkImage(
                    imageUrl: widget.post.mediaURLs!.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: typeColor.withValues(alpha: 0.1),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: typeColor.withValues(alpha: 0.1),
                      child: Icon(typeIcon, size: 32, color: typeColor),
                    ),
                  )
                else
                  Container(
                    color: typeColor.withValues(alpha: 0.1),
                    child: Center(
                      child: Icon(typeIcon, size: 32, color: typeColor),
                    ),
                  ),
                // Gradient overlay with title
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      widget.post.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: AppFontSize.xs,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Private (unshared) workout indicator - visible only to owner.
                if (widget.post.visibility == 'private')
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _handleReaction(ReactionType type) async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.value?.id;
    if (uid == null) return;

    final currentReaction = _userReaction;
    final oldCounts = Map<ReactionType, int>.from(_reactionCounts);

    // Optimistic update
    setState(() {
      if (currentReaction == type) {
        _userReaction = null;
        _reactionCounts = {...oldCounts, type: (oldCounts[type] ?? 1) - 1};
      } else {
        if (currentReaction != null) {
          _reactionCounts = {
            ...oldCounts,
            currentReaction: (oldCounts[currentReaction] ?? 1) - 1,
            type: (oldCounts[type] ?? 0) + 1,
          };
        } else {
          _reactionCounts = {...oldCounts, type: (oldCounts[type] ?? 0) + 1};
        }
        _userReaction = type;
      }
    });

    try {
      final postService = ref.read(postServiceProvider);
      if (currentReaction == type) {
        await postService.removeReaction(widget.post.id, uid);
      } else {
        await postService.reactToPost(widget.post.id, uid, type: type);
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _userReaction = currentReaction;
        _reactionCounts = oldCounts;
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

  Future<void> _handlePostAction({
    required String action,
    required String authorName,
  }) async {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.value?.id;
    if (currentUserId == null) return;

    switch (action) {
      case 'report_post':
        await ReportDialog.show(
          context,
          reportedPostId: widget.post.id,
          postAuthorId: widget.post.authorId,
          reportedUserName: authorName,
        );
        break;

      case 'report_user':
        await ReportDialog.show(
          context,
          reportedUserId: widget.post.authorId,
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
                .blockUser(currentUserId, widget.post.authorId);
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

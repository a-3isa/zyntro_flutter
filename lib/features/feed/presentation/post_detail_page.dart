// ignore_for_file: deprecated_member_use_from_same_package
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/widgets.dart';
import '../../../widgets/premium_animations.dart';
import '../../../core/models/models.dart';
import '../../../services/post_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/moderation_service.dart';
import '../../../widgets/reaction_buttons.dart';
import '../../../widgets/photo_viewer_page.dart';
import '../../moderation/presentation/report_dialog.dart';

/// Post detail page showing full post with comments.
class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  Post? _post;
  User? _author;
  ReactionType? _currentReaction;
  Map<ReactionType, int> _reactionCounts = {};

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    try {
      final postService = ref.read(postServiceProvider);
      final post = await postService.getPost(widget.postId);
      if (post != null && mounted) {
        final author = await ref
            .read(authServiceProvider)
            .getUserProfile(post.authorId);
        final authState = ref.read(authStateProvider);
        final uid = authState.valueOrNull?.uid;

        // Fetch reaction data
        final counts = await postService.getReactionCounts(widget.postId);
        ReactionType? userReaction;
        if (uid != null) {
          userReaction = await postService.getUserReaction(widget.postId, uid);
        }

        if (mounted) {
          setState(() {
            _post = post;
            _author = author;
            _reactionCounts = counts;
            _currentReaction = userReaction;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handle reaction tap - toggle or change reaction type with haptic feedback.
  Future<void> _handleReaction(ReactionType type) async {
    // Haptic feedback on reaction
    HapticManager.medium();

    final authState = ref.read(authStateProvider);
    final uid = authState.valueOrNull?.uid;
    if (uid == null || _post == null) return;

    final previousReaction = _currentReaction;
    final previousCounts = Map<ReactionType, int>.from(_reactionCounts);

    // Optimistic update
    setState(() {
      if (_currentReaction == type) {
        // Same reaction - remove it
        _currentReaction = null;
        _reactionCounts = {
          ...previousCounts,
          type: (previousCounts[type] ?? 1) - 1,
        };
      } else {
        // New or different reaction
        if (_currentReaction != null) {
          _reactionCounts = {
            ...previousCounts,
            _currentReaction!: (previousCounts[_currentReaction!] ?? 1) - 1,
            type: (previousCounts[type] ?? 0) + 1,
          };
        } else {
          _reactionCounts = {
            ...previousCounts,
            type: (previousCounts[type] ?? 0) + 1,
          };
        }
        _currentReaction = type;
      }
    });

    try {
      final postService = ref.read(postServiceProvider);
      if (previousReaction == type) {
        await postService.removeReaction(_post!.id, uid);
      } else {
        await postService.reactToPost(_post!.id, uid, type: type);
      }
    } catch (e) {
      // Revert on error with error haptic
      HapticManager.error();
      setState(() {
        _currentReaction = previousReaction;
        _reactionCounts = previousCounts;
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

  Future<void> _handleSubmitComment() async {
    if (!FeatureFlags.isCommentsEnabled) {
      if (mounted) {
        // Optionally show the dialog or just return, since the UI is wrapped it shouldn't be reachable.
        // But for safety:
        // ComingSoonDialog.show(context, ...); // Or just return
      }
      return;
    }
    if (_commentController.text.trim().isEmpty || _post == null) return;

    final authState = ref.read(authStateProvider);
    final uid = authState.valueOrNull?.uid;
    if (uid == null) return;

    final user = await ref.read(authServiceProvider).getUserProfile(uid);
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(postServiceProvider)
          .addComment(
            postId: _post!.id,
            userId: uid,
            userName: user.displayName,
            userPhotoURL: user.photoURL,
            text: _commentController.text.trim(),
          );
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Shimmer loading state
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Column(
          children: [
            // Custom Header
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 8,
                bottom: 8,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  BounceAnimation(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondaryDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textDark,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ShimmerLoading(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShimmerSkeleton.circle(size: 40),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerSkeleton.text(width: 120),
                              const SizedBox(height: 4),
                              ShimmerSkeleton.text(width: 60, height: 10),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ShimmerSkeleton.text(width: 200, height: 20),
                      const SizedBox(height: AppSpacing.md),
                      const ShimmerSkeleton(height: 250),
                      const SizedBox(height: AppSpacing.md),
                      const ShimmerSkeleton(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Post not found')),
      );
    }

    final commentsAsync = ref.watch(commentsProvider(widget.postId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                BounceAnimation(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Post',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row with overflow menu
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primaryMuted,
                        backgroundImage: _author?.photoURL != null
                            ? NetworkImage(_author!.photoURL!)
                            : null,
                        child: _author?.photoURL == null
                            ? Text(
                                _author?.displayName.isNotEmpty == true
                                    ? _author!.displayName[0].toUpperCase()
                                    : 'U',
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _author?.displayName ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              timeago.format(_post!.createdAt),
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
                      // Overflow menu for Report/Block
                      if (!_isOwnPost())
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) => _handlePostAction(value),
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Title
                  Text(
                    _post!.title,
                    style: const TextStyle(
                      fontSize: AppFontSize.xl,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Image (tappable for full-screen view) with Hero animation
                  if (_post!.mediaURLs != null && _post!.mediaURLs!.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        HapticManager.light();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PhotoViewerPage(
                              imageUrl: _post!.mediaURLs!.first,
                              heroTag: 'post-card-${_post!.id}',
                            ),
                          ),
                        );
                      },
                      child: Hero(
                        tag: 'post-card-${_post!.id}',
                        createRectTween: (begin, end) {
                          return MaterialRectCenterArcTween(
                            begin: begin,
                            end: end,
                          );
                        },
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            height: 250,
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.md,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: _post!.mediaURLs!.first,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.surfaceSecondaryDark,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: AppColors.surfaceSecondaryDark,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: AppColors.textSecondaryDark,
                                        ),
                                      ),
                                ),
                                // Gradient overlay
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 80,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.6),
                                          Colors.transparent,
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
                                      size: 18,
                                    ),
                                  ),
                                ),
                                // Multiple photos indicator
                                if (_post!.mediaURLs!.length > 1)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.photo_library,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_post!.mediaURLs!.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
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
                    ),

                  // Stats
                  if (_post!.summary.totalExercises != null ||
                      _post!.summary.totalSets != null ||
                      _post!.summary.duration != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat(
                                'Exercises',
                                '${_post!.summary.totalExercises ?? 0}',
                              ),
                              _buildStat(
                                'Sets',
                                '${_post!.summary.totalSets ?? 0}',
                              ),
                              if (_post!.summary.duration != null)
                                _buildStat('Duration', _post!.summary.duration!)
                              else
                                _buildStat('Type', _post!.type.toUpperCase()),
                            ],
                          ),
                          // Exercise list (top 3)
                          if (_post!.summary.exercises != null &&
                              _post!.summary.exercises!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.sm),
                            ..._post!.summary.exercises!
                                .take(3)
                                .map(
                                  (exercise) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.xs,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.fitness_center,
                                          size: 14,
                                          color: AppColors.primary,
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
                            if (_post!.summary.exercises!.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Text(
                                  '+${_post!.summary.exercises!.length - 3} more',
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
                  const SizedBox(height: AppSpacing.md),

                  // Actions - Reaction buttons
                  Row(
                    children: [
                      Expanded(
                        child: ReactionButtons(
                          postId: _post!.id,
                          currentReaction: _currentReaction,
                          reactionCounts: _reactionCounts,
                          onReactionTap: _handleReaction,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // MVP: Comments disabled - wrapped with feature flag
                      MVPFeatureWrapper(
                        feature: FeatureFlag.comments,
                        featureName: 'Comments',
                        description:
                            'Comment on posts to engage with the community. Coming soon!',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.comment_outlined),
                            const SizedBox(width: AppSpacing.sm),
                            Text('${_post!.commentsCount}'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: AppSpacing.xxl),

                  // Comments section
                  // MVP: Comments disabled - wrapped with feature flag
                  MVPFeatureWrapper(
                    feature: FeatureFlag.comments,
                    featureName: 'Comments',
                    description: 'See what others are saying. Coming soon!',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        commentsAsync.when(
                          data: (comments) {
                            final blockedUserIds =
                                ref.watch(blockedUserIdsProvider).valueOrNull ??
                                [];
                            final filteredComments = comments
                                .where(
                                  (c) => !blockedUserIds.contains(c.authorId),
                                )
                                .toList();

                            return filteredComments.isEmpty
                                ? Text(
                                    'No comments yet. Be the first!',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  )
                                : Column(
                                    children: filteredComments
                                        .map((c) => _buildCommentTile(c))
                                        .toList(),
                                  );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => const Text('Error loading comments'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comment input
          // MVP: Comments disabled - wrapped with feature flag
          MVPFeatureWrapper(
            feature: FeatureFlag.comments,
            featureName: 'Comments',
            description:
                'Share your thoughts and encourage others. Coming soon!',
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSubmitComment(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _isSubmitting ? null : _handleSubmitComment,
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

  Widget _buildCommentTile(Comment comment) {
    final authState = ref.read(authStateProvider);
    final currentUserId = authState.valueOrNull?.uid;
    final isOwnComment = currentUserId == comment.authorId;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryMuted,
            backgroundImage: comment.authorPhotoURL != null
                ? NetworkImage(comment.authorPhotoURL!)
                : null,
            child: comment.authorPhotoURL == null
                ? Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      timeago.format(comment.createdAt),
                      style: TextStyle(
                        fontSize: AppFontSize.xs,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    if (!isOwnComment)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 16),
                        padding: EdgeInsets.zero,
                        onSelected: (value) => _handleCommentAction(
                          action: value,
                          comment: comment,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'report_comment',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Report Comment'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'block_user',
                            child: Row(
                              children: [
                                Icon(Icons.block, size: 16, color: Colors.red),
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
                Text(comment.text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isOwnPost() {
    final authState = ref.read(authStateProvider);
    final currentUserId = authState.valueOrNull?.uid;
    return _post != null && currentUserId == _post!.authorId;
  }

  Future<void> _handlePostAction(String action) async {
    if (_post == null) return;
    final authState = ref.read(authStateProvider);
    final currentUserId = authState.valueOrNull?.uid;
    if (currentUserId == null) return;

    final authorName = _author?.displayName ?? 'User';

    switch (action) {
      case 'report_post':
        await ReportDialog.show(
          context,
          reportedPostId: _post!.id,
          postAuthorId: _post!.authorId,
          reportedUserName: authorName,
        );
        break;

      case 'report_user':
        await ReportDialog.show(
          context,
          reportedUserId: _post!.authorId,
          reportedUserName: authorName,
        );
        break;

      case 'block_user':
        await _blockUser(_post!.authorId, authorName);
        break;
    }
  }

  Future<void> _handleCommentAction({
    required String action,
    required Comment comment,
  }) async {
    final authState = ref.read(authStateProvider);
    final currentUserId = authState.valueOrNull?.uid;
    if (currentUserId == null) return;

    switch (action) {
      case 'report_comment':
        await ReportDialog.show(
          context,
          reportedCommentId: comment.id,
          commentAuthorId: comment.authorId,
          reportedUserName: comment.authorName,
        );
        break;

      case 'block_user':
        await _blockUser(comment.authorId, comment.authorName);
        break;
    }
  }

  Future<void> _blockUser(String userId, String userName) async {
    final authState = ref.read(authStateProvider);
    final currentUserId = authState.valueOrNull?.uid;
    if (currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Are you sure you want to block $userName? '
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
            .blockUser(currentUserId, userId);
        ref.invalidate(blockedUserIdsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName has been blocked'),
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
  }
}

// ignore_for_file: deprecated_member_use_from_same_package
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/widgets.dart';
import '../../../core/models/models.dart';
import '../../auth/auth_providers.dart';
import '../../auth/domain/entities/user_profile_entity.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../../services/post_service.dart';
import '../../../services/moderation_service.dart';
import '../../../utils/offline_manager.dart';
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
  // T031: optimistic pending comments shown while offline.
  final List<Comment> _pendingComments = [];
  UserProfileEntity? _author;
  ReactionType? _currentReaction;
  Map<ReactionType, int> _reactionCounts = {};
  String _selectedTab = 'Workout';

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
            .read(authControllerProvider)
            .getUserProfile(post.authorId);
        final authState = ref.read(authSessionProvider);
        final uid = authState.valueOrNull?.id;

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

    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
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

    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid == null) return;

    final user = await ref.read(authControllerProvider).getUserProfile(uid);
    if (user == null) return;

    // T031: if offline, queue and show pending optimistically.
    final offlineManager = ref.read(offlineManagerProvider);
    if (!offlineManager.isOnline) {
      final text = _commentController.text.trim();
      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();
      final pending = Comment(
        id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        authorId: uid,
        authorName: user.displayName,
        authorPhotoURL: user.photoUrl,
        text: text,
        createdAt: DateTime.now(),
        isPending: true,
      );
      await offlineManager.queueOperation('add_comment', {
        'postId': _post!.id,
        'userId': uid,
        'userName': user.displayName,
        'userPhotoURL': user.photoUrl,
        'text': text,
      });
      if (mounted) setState(() => _pendingComments.add(pending));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(postServiceProvider)
          .addComment(
            postId: _post!.id,
            userId: uid,
            userName: user.displayName,
            userPhotoURL: user.photoUrl,
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
        backgroundColor: AppColors.backgroundV2,
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
                color: AppColors.surfaceV2,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2Elevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textV2Primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Post',
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
      backgroundColor: AppColors.backgroundV2,
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
              color: AppColors.surfaceV2,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2Elevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textV2Primary,
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
                    color: AppColors.textV2Primary,
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
                        backgroundColor: AppColors.surfaceV2Elevated,
                        backgroundImage: _author?.photoUrl != null
                            ? NetworkImage(_author!.photoUrl!)
                            : null,
                        child: _author?.photoUrl == null
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
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textV2Primary,
                              ),
                            ),
                            Text(
                              timeago.format(_post!.createdAt),
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textV2Secondary,
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
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                      letterSpacing: -0.5,
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
                                    color: AppColors.surfaceV2Elevated,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.userAccent,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: AppColors.surfaceV2Elevated,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: AppColors.textV2Secondary,
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
                        color: AppColors.surfaceV2,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        border: Border.all(
                          color: AppColors.surfaceV2Elevated,
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
                                            color: AppColors.textV2Secondary,
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
                                    color: AppColors.textV2Tertiary,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),

                  // v2: 3-tab row
                  _buildTabRow(),
                  const SizedBox(height: AppSpacing.lg),

                  // Tab content
                  if (_selectedTab == 'Workout')
                    WorkoutDetailSection(post: _post!)
                  else if (_selectedTab == 'Reactions')
                    _buildReactionsTab()
                  else if (_selectedTab == 'Comments')
                    _buildCommentsTab(commentsAsync),
                ],
              ),
            ),
          ),

          // Sticky comment input — only shown on Comments tab
          if (_selectedTab == 'Comments')
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.surfaceV2,
                border: Border(
                  top: BorderSide(color: AppColors.surfaceV2Elevated),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(color: AppColors.textV2Primary),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: const TextStyle(color: AppColors.textV2Tertiary),
                          filled: true,
                          fillColor: AppColors.surfaceV2Elevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
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
        ],
      ),
    );
  }

  Widget _buildTabRow() {
    const tabs = ['Workout', 'Reactions', 'Comments'];

    return Row(
      children: tabs.map((tab) {
        final isActive = _selectedTab == tab;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? AppColors.userAccent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tab,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AppColors.textV2Primary : AppColors.textV2Secondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReactionsTab() {
    return ReactionButtons(
      postId: _post!.id,
      currentReaction: _currentReaction,
      reactionCounts: _reactionCounts,
      onReactionTap: _handleReaction,
    );
  }

  Widget _buildCommentsTab(AsyncValue<List<Comment>> commentsAsync) {
    return MVPFeatureWrapper(
      feature: FeatureFlag.comments,
      featureName: 'Comments',
      description: 'See what others are saying. Coming soon!',
      child: commentsAsync.when(
        data: (comments) {
          final blockedUserIds =
              ref.watch(blockedUserIdsProvider).valueOrNull ?? [];
          final filtered = comments
              .where((c) => !blockedUserIds.contains(c.authorId))
              .toList();
          // T031/T032: append pending (offline) comments at the bottom.
          final all = [...filtered, ..._pendingComments];
          if (all.isEmpty) {
            return const Text(
              'No comments yet. Be the first!',
              style: TextStyle(color: AppColors.textV2Secondary),
            );
          }
          return Column(
            children: all.map((c) => _buildCommentTile(c)).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Text('Error loading comments'),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textV2Primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textV2Secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentTile(Comment comment) {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    final isOwnComment = currentUserId == comment.authorId;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceV2Elevated,
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
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      timeago.format(comment.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textV2Tertiary,
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
                // T032: pending badge for offline-queued comments.
                if (comment.isPending)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload_outlined,
                            size: 12, color: AppColors.textV2Tertiary),
                        const SizedBox(width: 4),
                        Text(
                          'Pending sync',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textV2Tertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isOwnPost() {
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
    return _post != null && currentUserId == _post!.authorId;
  }

  Future<void> _handlePostAction(String action) async {
    if (_post == null) return;
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
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
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
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
    final authState = ref.read(authSessionProvider);
    final currentUserId = authState.valueOrNull?.id;
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

/// v2 Workout tab content — shows exercises from post summary.
class WorkoutDetailSection extends StatelessWidget {
  final Post post;

  const WorkoutDetailSection({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final exercises = post.summary.exercises;
    final totalSets = post.summary.totalSets ?? 0;

    if (exercises == null || exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No exercise details',
            style: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textV2Tertiary),
          ),
        ),
      );
    }

    // Total volume strip
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total sets strip
        Row(
          children: [
            Text(
              '$totalSets',
              style: AppTextStyles.h2.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.userAccent,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'total sets',
              style: AppTextStyles.caption.copyWith(color: AppColors.textV2Tertiary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Exercise rows
        ...exercises.map((exercise) {
          final hasDetail = exercise.setDetails.isNotEmpty;
          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.surfaceV2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.typeColor(post.type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                    ),
                    Text(
                      '${exercise.sets} ${exercise.sets == 1 ? 'set' : 'sets'}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Secondary,
                      ),
                    ),
                  ],
                ),
                if (hasDetail) ...[
                  const SizedBox(height: 6),
                  ...exercise.setDetails.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    final weightStr = s.weight > 0
                        ? '${s.weight == s.weight.truncateToDouble() ? s.weight.toInt() : s.weight} kg × ${s.reps} reps'
                        : '${s.reps} reps';
                    final durStr = s.durationSeconds > 0
                        ? () {
                            final m = s.durationSeconds ~/ 60;
                            final sec = s.durationSeconds % 60;
                            return m > 0
                                ? '${m}m ${sec.toString().padLeft(2, '0')}s'
                                : '${sec}s';
                          }()
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(left: 18, bottom: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            child: Text(
                              '${i + 1}.',
                              style: TextStyle(
                                fontSize: AppFontSize.xs,
                                color: AppColors.textV2Tertiary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              weightStr,
                              style: TextStyle(
                                fontSize: AppFontSize.sm,
                                color: AppColors.textV2Secondary,
                              ),
                            ),
                          ),
                          if (durStr.isNotEmpty)
                            Text(
                              durStr,
                              style: TextStyle(
                                fontSize: AppFontSize.xs,
                                color: AppColors.textV2Tertiary,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

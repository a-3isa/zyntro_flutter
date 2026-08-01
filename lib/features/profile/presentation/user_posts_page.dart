import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/post_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/widgets.dart';
import '../../auth/auth_providers.dart';

/// Page for viewing all posts from a specific user.
class UserPostsPage extends ConsumerStatefulWidget {
  final String userId;

  const UserPostsPage({super.key, required this.userId});

  @override
  ConsumerState<UserPostsPage> createState() => _UserPostsPageState();
}

class _UserPostsPageState extends ConsumerState<UserPostsPage> {
  String _filter = 'all'; // 'all', 'strength', 'cardio'

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(userPostsProvider(widget.userId));
    final currentUid = ref.watch(authSessionProvider).value?.id;
    final isOwner = currentUid == widget.userId;

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Posts',
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.filter_list,
                    color: AppColors.textV2Primary,
                  ),
                  onSelected: (value) {
                    HapticManager.medium();
                    setState(() => _filter = value);
                  },
                  color: AppColors.surfaceV2Elevated,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          if (_filter == 'all')
                            Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.userAccent,
                            ),
                          if (_filter != 'all') const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'All',
                            style: TextStyle(color: AppColors.textV2Primary),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'strength',
                      child: Row(
                        children: [
                          if (_filter == 'strength')
                            Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.userAccent,
                            ),
                          if (_filter != 'strength') const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Strength',
                            style: TextStyle(color: AppColors.textV2Primary),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'cardio',
                      child: Row(
                        children: [
                          if (_filter == 'cardio')
                            Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.userAccent,
                            ),
                          if (_filter != 'cardio') const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Cardio',
                            style: TextStyle(color: AppColors.textV2Primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: postsAsync.when(
              data: (posts) {
                // Private (unshared) workouts are visible only to their owner.
                final visible = isOwner
                    ? posts
                    : posts.where((p) => p.visibility != 'private').toList();
                // Filter by workout type
                final filteredPosts = _filter == 'all'
                    ? visible
                    : visible.where((p) => p.type == _filter).toList();

                if (filteredPosts.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userPostsProvider(widget.userId));
                  },
                  color: AppColors.userAccent,
                  backgroundColor: AppColors.surfaceV2,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm,
                        ),
                    itemCount: filteredPosts.length,
                    itemBuilder: (context, index) {
                      return PostCardWidget(
                        post: filteredPosts[index],
                        displayMode: PostCardDisplayMode.compact,
                        // Co-authored posts render the profile owner's own
                        // slot photo/stats, not the viewer's.
                        slotUserId: widget.userId,
                        onTap: () =>
                            context.push('/post/${filteredPosts[index].id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Error loading posts: $error'),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(userPostsProvider(widget.userId)),
                      child: const Text('Retry'),
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

  Widget _buildEmptyState() {
    final isFiltered = _filter != 'all';
    final title = isFiltered ? 'No $_filter posts yet' : 'No posts yet';

    return AppEmptyState(
      icon: Icons.photo_library_outlined,
      title: title,
      message: isFiltered
          ? 'Try a different filter to see more.'
          : 'Posts you share will show up here.',
      actionLabel: isFiltered ? 'Show all posts' : null,
      onAction: isFiltered ? () => setState(() => _filter = 'all') : null,
    );
  }
}

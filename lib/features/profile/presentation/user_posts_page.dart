import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/post_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';

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

    return Scaffold(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BounceAnimation(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: const GradientText(
                      text: 'Posts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      colors: [AppColors.textDark, AppColors.textSecondaryDark],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.filter_list,
                    color: AppColors.textDark,
                  ),
                  onSelected: (value) {
                    HapticManager.medium();
                    setState(() => _filter = value);
                  },
                  color: AppColors.surfaceSecondaryDark,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          if (_filter == 'all')
                            const Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          if (_filter != 'all') const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'All',
                            style: TextStyle(color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'strength',
                      child: Row(
                        children: [
                          if (_filter == 'strength')
                            const Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          if (_filter != 'strength') const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Strength',
                            style: TextStyle(color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'cardio',
                      child: Row(
                        children: [
                          if (_filter == 'cardio')
                            const Icon(
                              Icons.check,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          if (_filter != 'cardio') const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Cardio',
                            style: TextStyle(color: AppColors.textDark),
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
                // Filter posts
                final filteredPosts = _filter == 'all'
                    ? posts
                    : posts.where((p) => p.type == _filter).toList();

                if (filteredPosts.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userPostsProvider(widget.userId));
                  },
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceDark,
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
    final message = _filter == 'all' ? 'No posts yet' : 'No $_filter posts yet';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: TextStyle(
              fontSize: AppFontSize.lg,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (_filter != 'all') ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => setState(() => _filter = 'all'),
              child: const Text('Show all posts'),
            ),
          ],
        ],
      ),
    );
  }
}

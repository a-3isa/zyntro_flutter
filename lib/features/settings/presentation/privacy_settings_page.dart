import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import 'package:flutter/services.dart';
import '../../../services/follow_service.dart';
import '../../auth/auth_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';

/// Privacy settings page for managing account privacy.
/// Migrated from React Native PrivacySettingsScreen.
class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  bool _isUpdating = false;
  bool _isExplanationExpanded = false;

  Future<void> _togglePrivacy(bool value, String uid) async {
    setState(() => _isUpdating = true);

    try {
      await ref
          .read(authControllerProvider)
          .updateUserProfile(userId: uid, data: {'isPrivate': value});
      ref.invalidate(authUserProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update privacy: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProfileProvider);
    final authState = ref.watch(authSessionProvider);
    final uid = authState.value?.id;

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
                Text(
                  'Privacy',
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: userAsync.when(
              data: (user) {
                if (user == null || uid == null) {
                  return const Center(child: Text('User not found'));
                }

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Privacy status indicator
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: user.isPrivate
                            ? AppColors.userAccent.withValues(alpha: 0.1)
                            : AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        border: Border.all(
                          color: user.isPrivate
                              ? AppColors.userAccent
                              : AppColors.secondary,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            user.isPrivate ? Icons.lock : Icons.public,
                            color: user.isPrivate
                                ? AppColors.userAccent
                                : AppColors.secondary,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.isPrivate
                                      ? 'Private Account'
                                      : 'Public Account',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: AppFontSize.md,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.isPrivate
                                      ? 'Only approved followers can see your posts'
                                      : 'Anyone can see your posts and activity',
                                  style: TextStyle(
                                    fontSize: AppFontSize.sm,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Private account toggle
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Private Account',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'When enabled, only approved followers can see your posts and activity',
                        ),
                        value: user.isPrivate,
                        onChanged: _isUpdating
                            ? null
                            : (value) => _togglePrivacy(value, uid),
                        secondary: _isUpdating
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                user.isPrivate ? Icons.lock : Icons.lock_open,
                                color: AppColors.userAccent,
                              ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // "What does this mean?" expandable section
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: ExpansionTile(
                        leading: Icon(
                          Icons.help_outline,
                          color: AppColors.userAccent,
                        ),
                        title: const Text(
                          'What does this mean?',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        initiallyExpanded: _isExplanationExpanded,
                        onExpansionChanged: (expanded) {
                          setState(() => _isExplanationExpanded = expanded);
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildExplanationItem(
                                  icon: Icons.visibility_off,
                                  title: 'Hidden Posts',
                                  description:
                                      'Your workout posts will only be visible to approved followers.',
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _buildExplanationItem(
                                  icon: Icons.person_add,
                                  title: 'Follow Requests',
                                  description:
                                      'People must request to follow you, and you can approve or decline.',
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _buildExplanationItem(
                                  icon: Icons.public,
                                  title: 'Profile Visibility',
                                  description:
                                      'Your profile info (name, photo) is still visible, but posts are hidden.',
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _buildExplanationItem(
                                  icon: Icons.swap_horiz,
                                  title: 'Switching Back',
                                  description:
                                      'If you make your account public again, all your posts become visible.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Follower/Following counts
                    _buildFollowerStats(uid),

                    // Follow requests section (only show when private)
                    if (user.isPrivate) ...[
                      const SizedBox(height: AppSpacing.xxl),

                      const Text(
                        'Follow Requests',
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _buildFollowRequestsTile(uid),
                    ],

                    const SizedBox(height: AppSpacing.xxl),

                    // Blocked users tile
                    const Text(
                      'Safety',
                      style: TextStyle(
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2,
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.block,
                          color: AppColors.error,
                        ),
                        title: const Text('Blocked Users'),
                        subtitle: const Text('Manage blocked accounts'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.blockedUsers),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading privacy settings')),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.userAccent),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: AppFontSize.sm,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowerStats(String uid) {
    final followersAsync = ref.watch(followersCountProvider(uid));
    final followingAsync = ref.watch(followingCountProvider(uid));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            label: 'Followers',
            asyncValue: followersAsync,
            onTap: () {
              // TODO: Navigate to followers list
            },
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem(
            label: 'Following',
            asyncValue: followingAsync,
            onTap: () {
              // TODO: Navigate to following list
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required AsyncValue<int> asyncValue,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          asyncValue.when(
            data: (count) => Text(
              '$count',
              style: const TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.bold,
              ),
            ),
            loading: () => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, stackTrace) => const Text(
              '-',
              style: TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowRequestsTile(String uid) {
    final pendingCountAsync = ref.watch(pendingFollowRequestsCountProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: pendingCountAsync.when(
        data: (count) => ListTile(
          leading: Stack(
            children: [
              Icon(Icons.person_add, color: AppColors.userAccent),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          title: const Text('Pending Requests'),
          subtitle: Text(
            count == 0
                ? 'No pending requests'
                : '$count ${count == 1 ? 'person wants' : 'people want'} to follow you',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.userAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => context.push(AppRoutes.followRequests),
        ),
        loading: () => const ListTile(
          leading: Icon(Icons.person_add),
          title: Text('Pending Requests'),
          trailing: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, s) => ListTile(
          leading: const Icon(Icons.person_add),
          title: const Text('Pending Requests'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.followRequests),
        ),
      ),
    );
  }
}

/// Provider for followers count - reused from profile_page.dart
final followersCountProvider = FutureProvider.family<int, String>((
  ref,
  userId,
) async {
  return ref.read(followServiceProvider).getFollowersCount(userId);
});

/// Provider for following count - reused from profile_page.dart
final followingCountProvider = FutureProvider.family<int, String>((
  ref,
  userId,
) async {
  return ref.read(followServiceProvider).getFollowingCount(userId);
});

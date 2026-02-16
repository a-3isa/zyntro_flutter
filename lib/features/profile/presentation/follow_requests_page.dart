import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/models.dart';
import '../../../services/auth_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/user_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';

/// Follow requests page for managing pending follow requests.
/// Migrated from React Native FollowRequestsScreen.
class FollowRequestsPage extends ConsumerStatefulWidget {
  const FollowRequestsPage({super.key});

  @override
  ConsumerState<FollowRequestsPage> createState() => _FollowRequestsPageState();
}

class _FollowRequestsPageState extends ConsumerState<FollowRequestsPage> {
  final Set<String> _processingIds = {};

  Future<void> _handleAccept(User requester, String currentUserId) async {
    if (_processingIds.contains(requester.id)) return;

    setState(() => _processingIds.add(requester.id));

    try {
      final currentUser = ref.read(userProfileProvider).valueOrNull;
      await ref
          .read(followServiceProvider)
          .acceptFollowRequest(
            requester.id,
            currentUserId,
            acceptorName: currentUser?.displayName,
          );

      // Recompute buddies after accept
      await ref.read(userServiceProvider).computeAndCacheBuddies(currentUserId);

      // Refresh the requests list
      ref.invalidate(pendingFollowRequestsProvider);
      ref.invalidate(pendingFollowRequestsCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${requester.displayName} can now follow you'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept request: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(requester.id));
      }
    }
  }

  Future<void> _handleDecline(User requester, String currentUserId) async {
    if (_processingIds.contains(requester.id)) return;

    setState(() => _processingIds.add(requester.id));

    try {
      await ref
          .read(followServiceProvider)
          .declineFollowRequest(requester.id, currentUserId);

      // Refresh the requests list
      ref.invalidate(pendingFollowRequestsProvider);
      ref.invalidate(pendingFollowRequestsCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request declined')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(requester.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.valueOrNull?.uid;
    final requestsAsync = ref.watch(pendingFollowRequestsProvider);

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
                const SizedBox(width: 16),
                const Expanded(
                  child: GradientText(
                    text: 'Follow Requests',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    colors: [AppColors.textDark, AppColors.textSecondaryDark],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Not authenticated'))
                : requestsAsync.when(
                    data: (requests) {
                      if (requests.isEmpty) {
                        return _buildEmptyState();
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(pendingFollowRequestsProvider);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final user = requests[index];
                            return _buildRequestCard(user, uid);
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error: $e'),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(pendingFollowRequestsProvider),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_disabled,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No pending requests',
              style: TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'When someone requests to follow you, they\'ll appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: AppFontSize.md,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(User user, String currentUserId) {
    final isProcessing = _processingIds.contains(user.id);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primaryMuted,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),

            // Name and text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.md,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'wants to follow you',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            if (isProcessing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              // Decline button
              IconButton(
                onPressed: () => _handleDecline(user, currentUserId),
                icon: const Icon(Icons.close),
                color: AppColors.error,
                tooltip: 'Decline',
              ),
              const SizedBox(width: AppSpacing.xs),
              // Accept button
              IconButton(
                onPressed: () => _handleAccept(user, currentUserId),
                icon: const Icon(Icons.check),
                color: AppColors.success,
                tooltip: 'Accept',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Provider for pending follow requests list.
final pendingFollowRequestsProvider = FutureProvider<List<User>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return [];

  return ref.watch(followServiceProvider).getPendingFollowRequests(uid);
});

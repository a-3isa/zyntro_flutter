import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../services/notification_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';

/// Notifications page showing all user notifications.
/// Matches React Native NotificationsScreen behavior.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.valueOrNull?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(uid));

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
                      text: 'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      colors: [AppColors.textDark, AppColors.textSecondaryDark],
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: AppColors.textDark,
                      ),
                      tooltip: 'Notification Settings',
                      onPressed: () {
                        HapticManager.light();
                        context.push('/notifications/preferences');
                      },
                    ),
                    BounceAnimation(
                      onTap: () async {
                        HapticManager.medium();
                        await ref
                            .read(notificationServiceProvider)
                            .markAllNotificationsAsRead(uid);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          'Read All',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticManager.medium();
                ref.invalidate(userNotificationsProvider(uid));
              },
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceDark,
              child: notificationsAsync.when(
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return _buildEmptyState();
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      return SlideInAnimation(
                        index: index,
                        delay: const Duration(milliseconds: 40),
                        child: _buildNotificationTile(notifications[index]),
                      );
                    },
                  );
                },
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: 5,
                  itemBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: NotificationTileSkeleton(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Failed to load notifications',
                        style: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticManager.light();
                          ref.invalidate(userNotificationsProvider(uid));
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
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
      child: FadeInAnimation(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulseAnimation(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none,
                  size: 48,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You\'ll see updates here',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification notification) {
    final icon = _getIconForType(notification.type);
    final color = _getColorForType(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AppColors.error.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        HapticManager.medium();
        return true;
      },
      onDismissed: (_) async {
        // Store notification for undo
        final deletedNotification = notification;

        // Remove from UI optimistically (Riverpod stream will update, but we want to be responsive)
        // actually accessing the provider to delete happens below.

        await ref
            .read(notificationServiceProvider)
            .deleteNotification(notification.id);

        // Show undo snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notification deleted'),
              backgroundColor: AppColors.surfaceDark,
              action: SnackBarAction(
                label: 'Undo',
                textColor: AppColors.primary,
                onPressed: () async {
                  HapticManager.medium();
                  // Check if mounted before restoring
                  if (!mounted) return;

                  // Restore notification
                  await ref
                      .read(notificationServiceProvider)
                      .createNotification(
                        userId: deletedNotification.userId,
                        type: deletedNotification.type,
                        title: deletedNotification.title,
                        message: deletedNotification.message,
                        data: deletedNotification.data,
                      );
                },
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
            ),
          );
        }
      },
      child: BounceAnimation(
        scaleDown: 0.98,
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: notification.read
                ? AppColors.surfaceDark
                : AppColors.surfaceSecondaryDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: notification.read
                ? Border.all(color: AppColors.borderDark)
                : Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: notification.read
                    ? null
                    : LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: notification.read ? color.withValues(alpha: 0.1) : null,
                shape: BoxShape.circle,
              ),
              child: notification.read
                  ? Icon(icon, color: color.withValues(alpha: 0.7), size: 22)
                  : PulseAnimation(
                      minScale: 0.95,
                      maxScale: 1.0,
                      duration: const Duration(milliseconds: 1500),
                      child: Icon(icon, color: color, size: 22),
                    ),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight: notification.read
                    ? FontWeight.normal
                    : FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(notification.createdAt),
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    color: AppColors.textTertiaryDark,
                  ),
                ),
              ],
            ),
            trailing: !notification.read
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  /// Handle notification tap - mark as read and navigate based on type.
  Future<void> _handleNotificationTap(AppNotification notification) async {
    // Haptic feedback on tap
    HapticManager.light();

    // Mark as read first
    if (!notification.read) {
      await ref
          .read(notificationServiceProvider)
          .markNotificationAsRead(notification.id);
    }

    if (!mounted) return;

    // Navigate based on notification type and data
    final data = notification.data;

    switch (notification.type) {
      case NotificationType.sessionInvite:
      case NotificationType.buddySession:
        // Navigate to session room
        final sessionId = data?['sessionId'] as String?;
        final sessionType = data?['sessionType'] as String? ?? 'strength';
        if (sessionId != null) {
          context.push('/session/room/$sessionId?type=$sessionType');
        }
        break;

      case NotificationType.voiceNote:
        // Navigate to session room where voice note was sent
        final sessionId = data?['sessionId'] as String?;
        if (sessionId != null) {
          context.push('/session/room/$sessionId?type=strength');
        }
        break;

      case NotificationType.followRequest:
        // Navigate to follow requests screen
        context.push('/follow-requests');
        break;

      case NotificationType.followAccepted:
        // Navigate to user's profile
        final userId = data?['byUserId'] as String?;
        if (userId != null) {
          context.push('/user/$userId');
        }
        break;

      case NotificationType.buddyInvite:
      case NotificationType.buddyAccepted:
        // Navigate to buddy section
        context.push('/buddies');
        break;

      case NotificationType.postLike:
      case NotificationType.postComment:
        // Navigate to post detail
        final postId = data?['postId'] as String?;
        if (postId != null) {
          context.push('/post/$postId');
        }
        break;
      case NotificationType.sessionMilestone:
        // Navigate to session recap or milestones page
        // For now, maybe just open app or specific milestone page if exists
        break;
      case NotificationType.streakMilestone:
        // Navigate to profile or leaderboard
        context.push('/profile');
        break;
      case NotificationType.friendStreakBroken:
      case NotificationType.friendStreakExtended:
        // Navigate to user profile or leaderboard
        final friendId = data?['friendId'] as String?;
        if (friendId != null) {
          context.push('/user/$friendId');
        } else {
          context.push('/leaderboard?tab=friends');
        }
        break;
      case NotificationType.turnChange:
        // Navigate to session room
        final sessionId = data?['sessionId'] as String?;
        final sessionType = data?['sessionType'] as String? ?? 'strength';
        if (sessionId != null) {
          context.push('/session/room/$sessionId?type=$sessionType');
        }
        break;
    }
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.sessionInvite:
        return Icons.fitness_center;
      case NotificationType.voiceNote:
        return Icons.mic;
      case NotificationType.followRequest:
        return Icons.person_add;
      case NotificationType.followAccepted:
        return Icons.check_circle;
      case NotificationType.buddyInvite:
      case NotificationType.buddyAccepted:
      case NotificationType.buddySession:
        return Icons.people;
      case NotificationType.postLike:
        return Icons.favorite;
      case NotificationType.postComment:
        return Icons.comment;
      case NotificationType.sessionMilestone:
        return Icons.emoji_events;
      case NotificationType.streakMilestone:
      case NotificationType.friendStreakExtended:
        return Icons.local_fire_department;
      case NotificationType.friendStreakBroken:
        return Icons.heart_broken;
      case NotificationType.turnChange:
        return Icons.swap_horiz;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.sessionInvite:
      case NotificationType.buddySession:
        return AppColors.primary;
      case NotificationType.voiceNote:
        return AppColors.secondary;
      case NotificationType.followRequest:
      case NotificationType.buddyInvite:
        return Colors.blue;
      case NotificationType.followAccepted:
      case NotificationType.buddyAccepted:
        return AppColors.success;
      case NotificationType.postLike:
        return Colors.red;
      case NotificationType.postComment:
        return Colors.orange;
      case NotificationType.sessionMilestone:
      case NotificationType.streakMilestone:
      case NotificationType.friendStreakExtended:
        return Colors.amber;
      case NotificationType.friendStreakBroken:
        return Colors.grey;
      case NotificationType.turnChange:
        return AppColors.primary;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_providers.dart';
import '../../../services/notification_service.dart';
import '../../../services/session_service.dart';
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
  Future<void> _openSessionNotification(
    String sessionId, {
    required String fallbackType,
  }) async {
    final session = await ref.read(sessionServiceProvider).getSession(sessionId);
    if (!mounted) return;

    final location = session == null
        ? AppRouteLocations.sessionRoom(sessionId, type: fallbackType)
        : AppRouteLocations.sessionEntry(
            sessionId: session.id,
            type: session.type,
            phase: session.phase,
          );

    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionProvider);
    final uid = authState.valueOrNull?.id;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Text(
            'Not logged in',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
      );
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Custom Header with Premium Styling
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: GradientText(
                      text: 'Notifications',
                      style: TextStyle(
                        fontSize: 22,
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
                        size: 22,
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
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
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
                      const Text(
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 56,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'You\'ll see updates here when they arrive',
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
          color: AppColors.error.withValues(alpha: 0.1),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      confirmDismiss: (_) async {
        HapticManager.medium();
        return true;
      },
      onDismissed: (_) async {
        final deletedNotification = notification;
        await ref
            .read(notificationServiceProvider)
            .deleteNotification(notification);

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
                  if (!mounted) return;
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
                borderRadius: BorderRadius.circular(12),
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
            horizontal: 16,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: notification.read
                ? AppColors.surfaceDark
                : AppColors.surfaceSecondaryDark.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.read
                  ? AppColors.borderDark.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: notification.read
                ? []
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: notification.read
                  ? Icon(icon, color: color.withValues(alpha: 0.6), size: 22)
                  : PulseAnimation(
                      minScale: 0.9,
                      maxScale: 1.0,
                      child: Icon(icon, color: color, size: 22),
                    ),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight: notification.read ? FontWeight.w500 : FontWeight.w700,
                fontSize: 15,
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
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeago.format(notification.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: !notification.read
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
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
    HapticManager.light();

    if (!notification.read) {
      await ref
          .read(notificationServiceProvider)
          .markNotificationAsRead(notification);
    }

    if (!mounted) return;

    final data = notification.data;

    switch (notification.type) {
      case NotificationType.unknown:
        break;
      case NotificationType.sessionInvite:
      case NotificationType.buddySession:
        final sessionId = data?['sessionId'] as String?;
        final sessionType =
            data?['sessionType'] as String? ?? WorkoutType.gym.value;
        if (sessionId != null) {
          await _openSessionNotification(
            sessionId,
            fallbackType: sessionType,
          );
        }
        break;

      case NotificationType.voiceNote:
        final sessionId = data?['sessionId'] as String?;
        final sessionType =
            data?['sessionType'] as String? ?? WorkoutType.gym.value;
        if (sessionId != null) {
          await _openSessionNotification(
            sessionId,
            fallbackType: sessionType,
          );
        }
        break;

      case NotificationType.followRequest:
        context.push('/profile/follow-requests');
        break;

      case NotificationType.followAccepted:
        final userId = data?['byUserId'] as String?;
        if (userId != null) {
          context.push('/user/$userId');
        }
        break;

      case NotificationType.buddyInvite:
      case NotificationType.buddyAccepted:
        context.go(
          AppRouteLocations.mainTab(
            MainShellTab.social,
            socialTab: SocialTab.buddies,
          ),
        );
        break;

      case NotificationType.postLike:
      case NotificationType.postComment:
        final postId = data?['postId'] as String?;
        if (postId != null) {
          context.push('/post/$postId');
        }
        break;
      case NotificationType.sessionMilestone:
        break;
      case NotificationType.streakMilestone:
        context.go(AppRouteLocations.mainTab(MainShellTab.profile));
        break;
      case NotificationType.friendStreakBroken:
      case NotificationType.friendStreakExtended:
        final friendId = data?['friendId'] as String?;
        if (friendId != null) {
          context.push('/user/$friendId');
        } else {
          context.go(
            AppRouteLocations.mainTab(
              MainShellTab.social,
              socialTab: SocialTab.leaderboard,
            ),
          );
        }
        break;
      case NotificationType.turnChange:
        final sessionId = data?['sessionId'] as String?;
        final sessionType =
            data?['sessionType'] as String? ?? WorkoutType.gym.value;
        if (sessionId != null) {
          await _openSessionNotification(
            sessionId,
            fallbackType: sessionType,
          );
        }
        break;
    }
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.unknown:
        return Icons.notifications_none_rounded;
      case NotificationType.sessionInvite:
        return Icons.fitness_center_rounded;
      case NotificationType.voiceNote:
        return Icons.mic_rounded;
      case NotificationType.followRequest:
        return Icons.person_add_rounded;
      case NotificationType.followAccepted:
        return Icons.check_circle_rounded;
      case NotificationType.buddyInvite:
      case NotificationType.buddyAccepted:
      case NotificationType.buddySession:
        return Icons.people_rounded;
      case NotificationType.postLike:
        return Icons.favorite_rounded;
      case NotificationType.postComment:
        return Icons.comment_rounded;
      case NotificationType.sessionMilestone:
        return Icons.emoji_events_rounded;
      case NotificationType.streakMilestone:
      case NotificationType.friendStreakExtended:
        return Icons.local_fire_department_rounded;
      case NotificationType.friendStreakBroken:
        return Icons.heart_broken_rounded;
      case NotificationType.turnChange:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.unknown:
        return AppColors.textSecondaryDark;
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/navigation/app_route_locations.dart';
import '../../../core/constants/constants.dart';
import '../../../core/l10n/locale_format.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/widgets.dart';
import '../../auth/auth_providers.dart';
import '../../../services/follow_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/session_service.dart';
import '../../../utils/haptic_manager.dart';

final _notifFollowStatusProvider =
    FutureProvider.family<FollowStatus?, (String, String)>((ref, ids) async {
      return ref.read(followServiceProvider).getFollowStatus(ids.$1, ids.$2);
    });

/// Notifications page showing all user notifications grouped by date.
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
    final session = await ref
        .read(sessionServiceProvider)
        .getSession(sessionId);
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
    final uid = authState.value?.id;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: Center(
          child: Text(
            'Not logged in',
            style: TextStyle(color: AppColors.textV2Secondary),
          ),
        ),
      );
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(uid));
    final unreadCount =
        notificationsAsync.value?.where((n) => !n.read).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.signal.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                ZyntroBackButton(onPressed: () => context.pop()),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Notifications',
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (unreadCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.signal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                GestureDetector(
                  onTap: () async {
                    HapticManager.medium();
                    await ref
                        .read(notificationServiceProvider)
                        .markAllNotificationsAsRead(uid);
                  },
                  child: Text(
                    'Read All',
                    style: TextStyle(
                      color: AppColors.signal,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
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
              color: AppColors.signal,
              backgroundColor: AppColors.surfaceV2,
              child: notificationsAsync.when(
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildGroupedList(notifications);
                },
                loading: () => ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: 5,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      height: 72,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Failed to load notifications',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textV2Secondary,
                        ),
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
                          backgroundColor: AppColors.signal,
                          foregroundColor: Colors.black,
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

  Widget _buildGroupedList(List<AppNotification> notifications) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final today = notifications
        .where((n) => !n.createdAt.isBefore(todayStart))
        .toList();
    final yesterday = notifications
        .where(
          (n) =>
              !n.createdAt.isBefore(yesterdayStart) &&
              n.createdAt.isBefore(todayStart),
        )
        .toList();
    final older = notifications
        .where((n) => n.createdAt.isBefore(yesterdayStart))
        .toList();

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        if (today.isNotEmpty) ...[
          _buildSectionLabel('TODAY'),
          ...today.map(_buildNotificationTile),
        ],
        if (yesterday.isNotEmpty) ...[
          _buildSectionLabel('YESTERDAY'),
          ...yesterday.map(_buildNotificationTile),
        ],
        if (older.isNotEmpty) ...[
          _buildSectionLabel('EARLIER'),
          ...older.map(_buildNotificationTile),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textV2Tertiary,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.notifications_none_rounded,
      title: 'All clear',
      message: "You'll see updates here when they arrive",
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
              backgroundColor: AppColors.surfaceV2,
              action: SnackBarAction(
                label: 'Undo',
                textColor: AppColors.signal,
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
      child: Opacity(
        opacity: notification.read ? 0.6 : 1.0,
        child: GestureDetector(
          onTap: () => _handleNotificationTap(notification),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: notification.read
                  ? AppColors.surfaceV2
                  : AppColors.surfaceV2Elevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: notification.read
                    ? AppColors.surfaceV2Active
                    : AppColors.signal.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: notification.read
                      ? AppColors.surfaceV2
                      : AppColors.surfaceV2Elevated,
                  shape: BoxShape.circle,
                  border: notification.read
                      ? null
                      : Border.all(
                          color: AppColors.signal.withValues(alpha: 0.18),
                        ),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              title: Text(
                notification.title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: notification.read
                      ? FontWeight.w500
                      : FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textV2Primary,
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
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textV2Secondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LocaleFormat.relative(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textV2Tertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (notification.type == NotificationType.followRequest) ...[
                    Builder(
                      builder: (_) {
                        final uid = ref
                            .read(authSessionProvider)
                            .value
                            ?.id;
                        if (uid == null) return const SizedBox.shrink();
                        return _buildFollowRequestActions(notification, uid);
                      },
                    ),
                  ],
                ],
              ),
              trailing: !notification.read
                  ? Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.signal,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowRequestActions(
    AppNotification notification,
    String currentUserId,
  ) {
    final fromUserId = notification.data?['fromUserId'] as String?;
    if (fromUserId == null) return const SizedBox.shrink();

    final actionTaken = notification.data?['actionTaken'] as String?;
    if (actionTaken != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Request handled',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textV2Tertiary,
            fontSize: 11,
          ),
        ),
      );
    }

    final followStatusAsync = ref.watch(
      _notifFollowStatusProvider((currentUserId, fromUserId)),
    );
    final isAlreadyFollowing =
        followStatusAsync.value == FollowStatus.approved;

    final isPrivate = ref
        .watch(authUserProfileProvider)
        .when(
          data: (p) => p?.isPrivate ?? false,
          loading: () => false,
          error: (_, _) => false,
        );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        children: [
          if (!isAlreadyFollowing)
            _notifActionButton(
              label: 'Follow back',
              filled: true,
              onPressed: () async {
                await ref
                    .read(followServiceProvider)
                    .followUser(
                      followerId: currentUserId,
                      followeeId: fromUserId,
                      isPrivate: false,
                    );
                await ref
                    .read(notificationServiceProvider)
                    .updateNotificationData(notification.id, currentUserId, {
                      'actionTaken': 'followedBack',
                    });
                ref.invalidate(
                  _notifFollowStatusProvider((currentUserId, fromUserId)),
                );
              },
            ),
          if (isPrivate) ...[
            _notifActionButton(
              label: 'Accept',
              filled: false,
              onPressed: () async {
                await ref
                    .read(followServiceProvider)
                    .acceptFollowRequest(fromUserId, currentUserId);
                await ref
                    .read(notificationServiceProvider)
                    .updateNotificationData(notification.id, currentUserId, {
                      'actionTaken': 'accepted',
                    });
              },
            ),
            _notifActionButton(
              label: 'Decline',
              filled: false,
              onPressed: () async {
                await ref
                    .read(followServiceProvider)
                    .declineFollowRequest(fromUserId, currentUserId);
                await ref
                    .read(notificationServiceProvider)
                    .updateNotificationData(notification.id, currentUserId, {
                      'actionTaken': 'declined',
                    });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _notifActionButton({
    required String label,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    const textStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    const minSize = Size(0, 30);
    const hPad = EdgeInsets.symmetric(horizontal: 12);

    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.signal,
          foregroundColor: Colors.black,
          minimumSize: minSize,
          padding: hPad,
          textStyle: textStyle,
          shape: shape,
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textV2Primary,
        minimumSize: minSize,
        padding: hPad,
        textStyle: textStyle,
        side: const BorderSide(color: AppColors.surfaceV2Active),
        shape: shape,
      ),
      child: Text(label),
    );
  }

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
      // A partner leaving opens the same place: the session, which is still
      // live for this member and theirs to finish or leave.
      case NotificationType.partnerLeft:
        final sessionId = data?['sessionId'] as String?;
        final sessionType =
            data?['sessionType'] as String? ?? WorkoutType.gym.value;
        if (sessionId != null) {
          await _openSessionNotification(sessionId, fallbackType: sessionType);
        }
        break;

      case NotificationType.voiceNote:
        final sessionId = data?['sessionId'] as String?;
        final sessionType =
            data?['sessionType'] as String? ?? WorkoutType.gym.value;
        if (sessionId != null) {
          await _openSessionNotification(sessionId, fallbackType: sessionType);
        }
        break;

      case NotificationType.newFollower:
      case NotificationType.followRequest:
        final fromUserId = data?['fromUserId'] as String?;
        if (fromUserId != null) {
          context.push('/user/$fromUserId');
        }
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
              socialTab: SocialTab.board,
            ),
          );
        }
        break;
      case NotificationType.turnChange:
        final sessionId = data?['sessionId'] as String?;
        final sessionType =
            data?['sessionType'] as String? ?? WorkoutType.gym.value;
        if (sessionId != null) {
          await _openSessionNotification(sessionId, fallbackType: sessionType);
        }
        break;
      case NotificationType.jointPostInvite:
        // An invite points at an unpublished draft the recipient still has to
        // complete — open the composer, not the (unpublishable) post detail.
        final invitePostId = data?['postId'] as String?;
        if (invitePostId != null) {
          context.push(AppRouteLocations.jointPostComposer(invitePostId));
        }
        break;
      case NotificationType.jointPostExpired:
        // Expiry offers go to post detail, where the solo-repost flow lives.
        final expiredPostId = data?['postId'] as String?;
        if (expiredPostId != null) {
          context.push(AppRouteLocations.postDetail(expiredPostId));
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
      case NotificationType.newFollower:
        return Icons.person_add_alt_1_rounded;
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
      case NotificationType.partnerLeft:
        return Icons.person_remove_rounded;
      case NotificationType.jointPostInvite:
        return Icons.group_add_rounded;
      case NotificationType.jointPostExpired:
        return Icons.hourglass_bottom_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.unknown:
        return AppColors.textV2Secondary;
      case NotificationType.sessionInvite:
      case NotificationType.buddySession:
        return AppColors.signal;
      case NotificationType.voiceNote:
        return AppColors.secondary;
      case NotificationType.newFollower:
        return AppColors.signal;
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
        return AppColors.signal;
      case NotificationType.partnerLeft:
        // Informational, not an alert — the member's own session is unaffected.
        return AppColors.textV2Secondary;
      case NotificationType.jointPostInvite:
        return AppColors.signal;
      case NotificationType.jointPostExpired:
        return Colors.orange;
    }
  }
}

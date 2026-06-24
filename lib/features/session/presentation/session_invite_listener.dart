import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_providers.dart';
import '../../../services/notification_service.dart';
import '../../../services/session_service.dart';

class SessionInviteListener extends ConsumerStatefulWidget {
  const SessionInviteListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionInviteListener> createState() =>
      _SessionInviteListenerState();
}

class _SessionInviteListenerState extends ConsumerState<SessionInviteListener> {
  final Set<String> _presentedNotificationIds = <String>{};
  bool _isShowingInvite = false;

  DateTime? _expiresAt(AppNotification notification) {
    final value = notification.data?['expiresAt'];
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  bool _isActionable(AppNotification notification) {
    if (notification.read ||
        notification.type != NotificationType.sessionInvite ||
        _presentedNotificationIds.contains(notification.id)) {
      return false;
    }

    final sessionId = notification.data?['sessionId'];
    final expiresAt = _expiresAt(notification);
    return sessionId is String &&
        sessionId.isNotEmpty &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now());
  }

  Future<void> _presentInvite(AppNotification notification) async {
    if (_isShowingInvite || !mounted) return;
    _isShowingInvite = true;
    _presentedNotificationIds.add(notification.id);

    final data = notification.data ?? const <String, dynamic>{};
    final sessionId = data['sessionId'] as String;
    final hostName =
        data['hostName'] as String? ??
        data['byUserName'] as String? ??
        'A friend';
    final sessionType = data['sessionType'] as String? ?? 'workout';

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceV2Elevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Workout invitation'),
        content: Text(
          '$hostName invited you to a $sessionType session. Join before the invitation expires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('Decline'),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('Accept'),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    try {
      await ref
          .read(notificationServiceProvider)
          .markNotificationAsRead(notification);

      if (action == 'Decline') {
        final userId = ref.read(authSessionProvider).valueOrNull?.id;
        if (userId != null) {
          await ref
              .read(sessionServiceProvider)
              .declineInvite(sessionId: sessionId, userId: userId);
        }
      } else if (action == 'Accept' && mounted) {
        context.go(AppRouteLocations.gymSessionSetup(sessionId));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update invitation: $error')),
        );
      }
    } finally {
      _isShowingInvite = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authSessionProvider).valueOrNull?.id;
    if (userId != null) {
      ref.listen<AsyncValue<List<AppNotification>>>(
        userNotificationsProvider(userId),
        (_, next) {
          final notifications = next.valueOrNull;
          if (notifications == null || _isShowingInvite) return;

          for (final notification in notifications) {
            if (_isActionable(notification)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _presentInvite(notification);
              });
              break;
            }
          }
        },
      );
    }

    return widget.child;
  }
}

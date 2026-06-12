import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../auth/auth_providers.dart';
import '../../../widgets/widgets.dart';
import '../../../services/notification_service.dart';
import 'package:flutter/services.dart';

/// Notification preferences page for managing notification settings.
/// Allows users to enable/disable different notification types.
class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  ConsumerState<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends ConsumerState<NotificationPreferencesPage> {
  NotificationPreferences? _preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid == null) return;

    final prefs = await ref
        .read(notificationServiceProvider)
        .getNotificationPreferences(uid);

    if (mounted) {
      setState(() {
        _preferences = prefs;
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePreference(NotificationPreferences newPrefs) async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid == null) return;

    // Optimistic update
    setState(() => _preferences = newPrefs);

    try {
      await ref
          .read(notificationServiceProvider)
          .updateNotificationPreferences(uid, newPrefs);
    } catch (e) {
      // Revert on error
      await _loadPreferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating preferences: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(width: 16),
                Text(
                  'Notification Settings',
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _preferences == null
                ? const Center(child: Text('Error loading preferences'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMasterToggle(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildNotificationTypesSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.userAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active,
                color: AppColors.userAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Push Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.md,
                    ),
                  ),
                  Text(
                    'Receive push notifications on this device',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _preferences!.pushEnabled,
              onChanged: (value) {
                _updatePreference(_preferences!.copyWith(pushEnabled: value));
              },
              activeThumbColor: AppColors.userAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTypesSection() {
    final isEnabled = _preferences!.pushEnabled;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'NOTIFICATION TYPES',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  _buildPreferenceItem(
                    icon: Icons.fitness_center,
                    iconColor: AppColors.userAccent,
                    title: 'Session Invites',
                    description:
                        'When someone invites you to a workout session',
                    value: _preferences!.sessionInvites,
                    onChanged: (value) {
                      _updatePreference(
                        _preferences!.copyWith(sessionInvites: value),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildPreferenceItem(
                    icon: Icons.mic,
                    iconColor: AppColors.secondary,
                    title: 'Voice Notes',
                    description: 'When you receive a voice note in a session',
                    value: _preferences!.voiceNotes,
                    onChanged: (value) {
                      _updatePreference(
                        _preferences!.copyWith(voiceNotes: value),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildPreferenceItem(
                    icon: Icons.person_add,
                    iconColor: Colors.blue,
                    title: 'Follow Requests',
                    description: 'When someone wants to follow you',
                    value: _preferences!.followRequests,
                    onChanged: (value) {
                      _updatePreference(
                        _preferences!.copyWith(followRequests: value),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildPreferenceItem(
                    icon: Icons.check_circle,
                    iconColor: AppColors.success,
                    title: 'Follow Accepted',
                    description: 'When your follow request is accepted',
                    value: _preferences!.followAccepted,
                    onChanged: (value) {
                      _updatePreference(
                        _preferences!.copyWith(followAccepted: value),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildPreferenceItem(
                    icon: Icons.people,
                    iconColor: Colors.blue,
                    title: 'Buddy Invites & Sessions',
                    description: 'Buddy requests and session notifications',
                    value: _preferences!.buddyInvites,
                    onChanged: (value) {
                      _updatePreference(
                        _preferences!.copyWith(buddyInvites: value),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildPreferenceItem(
                    icon: Icons.favorite,
                    iconColor: Colors.red,
                    title: 'Post Likes',
                    description: 'When someone likes your post',
                    value: _preferences!.postLikes,
                    onChanged: (value) {
                      _updatePreference(
                        _preferences!.copyWith(postLikes: value),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // MVP: Comments disabled - wrapped with feature flag
                  MVPFeatureWrapper(
                    feature: FeatureFlag.comments,
                    featureName: 'Comment Notifications',
                    description: 'Notifications for comments. Coming soon!',
                    child: _buildPreferenceItem(
                      icon: Icons.comment,
                      iconColor: Colors.orange,
                      title: 'Post Comments',
                      description: 'When someone comments on your post',
                      value: _preferences!.postComments,
                      onChanged: (value) {
                        _updatePreference(
                          _preferences!.copyWith(postComments: value),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  _buildPreferenceItem(
                    icon: Icons.emoji_events,
                    iconColor: Colors.amber,
                    title: 'Session Milestones',
                    description: 'PRs, streaks, and session achievements',
                    value: _preferences!.sessionMilestones,
                    onChanged: (value) {
                      _updatePreference(
                        _preferences!.copyWith(sessionMilestones: value),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: AppFontSize.sm,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: AppFontSize.xs,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.userAccent,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'fluttermoji_avatar.dart';

/// Buddies activity carousel matching React Native BuddiesActivityCarousel.
class BuddiesActivityCarousel extends StatelessWidget {
  const BuddiesActivityCarousel({super.key});

  // Mock data - in a real app, this would come from a service
  static const List<Map<String, dynamic>> _buddies = [
    {
      'name': 'Alex',
      'activity': 'Just finished a workout! 💪',
      'isOnline': true,
    },
    {'name': 'Jordan', 'activity': 'On a 12-day streak 🔥', 'isOnline': true},
    {'name': 'Sam', 'activity': 'Set a new PR today!', 'isOnline': false},
    {'name': 'Riley', 'activity': 'Morning cardio completed', 'isOnline': true},
    {'name': 'Casey', 'activity': '21-day streak! 🏆', 'isOnline': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryMuted,
            AppColors.primaryLight.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Text('👥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Buddies Activity',
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _buddies.length,
              itemBuilder: (context, index) {
                final buddy = _buddies[index];
                return _BuddyChip(
                  name: buddy['name'] as String,
                  activity: buddy['activity'] as String,
                  isOnline: buddy['isOnline'] as bool,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _BuddyChip extends StatelessWidget {
  final String name;
  final String activity;
  final bool isOnline;

  const _BuddyChip({
    required this.name,
    required this.activity,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              FluttermojiAvatar(
                displayName: name,
                size: 32,
                showGradientBorder: false,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            name,
            style: const TextStyle(
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600,
              color: AppColors.textV2Primary,
            ),
          ),
          Text(
            activity,
            style: TextStyle(fontSize: 10, color: AppColors.textV2Secondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

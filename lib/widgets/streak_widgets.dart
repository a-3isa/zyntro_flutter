import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/user_service.dart';
import 'fluttermoji_avatar.dart';

export 'streak_card.dart';

/// A widget to display a user's spot on the streak podium (Rank 1, 2, 3).
class StreakPodiumSpot extends StatelessWidget {
  final FriendStreakComparison entry;
  final int rank;
  final double height;

  const StreakPodiumSpot({
    super.key,
    required this.entry,
    required this.rank,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = {
      1: Colors.amber,
      2: Colors.grey.shade400,
      3: Colors.brown.shade300,
    };
    final isCurrentUser = entry.isCurrentUser;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: isCurrentUser
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.warmAccent,
                          width: 3,
                        ),
                      )
                    : null,
                child: FluttermojiAvatar(
                  avatarConfig: entry.avatarConfig,
                  photoUrl: entry.photoURL,
                  displayName: entry.displayName,
                  size: rank == 1 ? 64 : 52,
                  showGradientBorder: false,
                  ringColor: FluttermojiAvatar.colorFromAvatarConfig(
                    entry.avatarConfig,
                  ),
                ),
              ),
              if (rank == 1)
                const Positioned(
                  top: -12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('👑', style: TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: 80,
            child: Text(
              entry.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: AppFontSize.sm,
                color: isCurrentUser ? AppColors.warmAccent : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${entry.currentStreak} days 🔥',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              fontWeight: FontWeight.bold,
              color: AppColors.warmAccent,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              color: colors[rank]!.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.md),
              ),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors[rank],
                  fontSize: AppFontSize.lg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A list item widget for streak leaderboard entries.
class StreakListItem extends StatelessWidget {
  final FriendStreakComparison entry;

  const StreakListItem({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: entry.isCurrentUser ? AppColors.warmBackground : null,
      shape: entry.isCurrentUser
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              side: const BorderSide(color: AppColors.warmAccent, width: 2),
            )
          : null,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: entry.isCurrentUser ? AppColors.warmAccent : null,
                ),
              ),
            ),
            FluttermojiAvatar(
              avatarConfig: entry.avatarConfig,
              photoUrl: entry.photoURL,
              displayName: entry.displayName,
              size: 40,
              showGradientBorder: false,
              ringColor: FluttermojiAvatar.colorFromAvatarConfig(
                entry.avatarConfig,
              ),
            ),
          ],
        ),
        title: Text(
          entry.displayName,
          style: TextStyle(
            fontWeight: entry.isCurrentUser ? FontWeight.bold : FontWeight.w500,
            color: entry.isCurrentUser ? AppColors.warmAccent : null,
          ),
        ),
        subtitle: Row(
          children: [
            const Text('Current: '),
            Flexible(
              child: Text(
                '${entry.currentStreak} 🔥',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: entry.isCurrentUser
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warmAccent,
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

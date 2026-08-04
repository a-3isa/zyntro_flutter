import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/constants/constants.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';
import '../utils/image_cache_manager.dart';
import 'fluttermoji_avatar.dart';

/// Compact activity card widget for displaying recent friend activity.
/// Shows workout type icon, metrics, optional photo, and time ago.
class RecentActivityCard extends StatelessWidget {
  final ActivityItem activity;
  final VoidCallback? onTap;
  final String? heroTag;

  const RecentActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: heroTag ?? 'activity_${activity.id}',
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: 200,
          height: 160,
          margin: const EdgeInsets.only(right: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getGradientColors(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: AppColors.borderDark.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: _getPrimaryColor().withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Photo background if available
              if (activity.mediaURLs != null && activity.mediaURLs!.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    child: CachedNetworkImage(
                      cacheManager: ZyntroImageCacheManager(),
                      imageUrl: activity.mediaURLs!.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppColors.surfaceV2Elevated),
                      errorWidget: (context, url, error) =>
                          Container(color: AppColors.surfaceV2Elevated),
                    ),
                  ),
                ),

              // Gradient overlay for readability
              if (activity.mediaURLs != null && activity.mediaURLs!.isNotEmpty)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: User avatar + name
                    Row(
                      children: [
                        // User avatar
                        FluttermojiAvatar(
                          photoUrl: activity.userPhotoURL,
                          displayName: activity.userName,
                          size: 32,
                          showGradientBorder: false,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        // User name
                        Expanded(
                          child: Text(
                            activity.userName,
                            style: const TextStyle(
                              color: AppColors.textV2Primary,
                              fontWeight: FontWeight.w600,
                              fontSize: AppFontSize.sm,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Workout type badge with icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _getPrimaryColor().withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.sm,
                            ),
                            border: Border.all(
                              color: _getPrimaryColor().withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getWorkoutIcon(),
                                size: 14,
                                color: _getPrimaryColor(),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activity.workoutTypeEnum.displayName,
                                style: TextStyle(
                                  color: _getPrimaryColor(),
                                  fontSize: AppFontSize.xs,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Stats summary
                    Text(
                      _getStatsText(),
                      style: const TextStyle(
                        color: AppColors.textV2Primary,
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Time ago
                    Text(
                      timeago.format(activity.timestamp),
                      style: TextStyle(
                        color: AppColors.textV2Secondary,
                        fontSize: AppFontSize.xs,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get gradient colors based on workout category.
  List<Color> _getGradientColors() {
    final workoutType = activity.workoutTypeEnum;

    if (workoutType.isStrength) {
      // Purple/blue for strength
      return [AppColors.activityGradientBase, const Color(0xFF2A1F40)];
    } else if (workoutType.isCardio) {
      // Orange/red for cardio
      return [AppColors.activityGradientBase, const Color(0xFF401F1F)];
    } else if (workoutType == WorkoutType.cycling) {
      // Green for cycling
      return [AppColors.activityGradientBase, const Color(0xFF1F4028)];
    } else {
      // Neutral for other
      return [AppColors.activityGradientBase, const Color(0xFF141B2D)];
    }
  }

  /// Get primary accent color based on workout category.
  Color _getPrimaryColor() {
    final workoutType = activity.workoutTypeEnum;

    if (workoutType.isStrength) {
      return AppColors.userAccent;
    } else if (workoutType.isCardio) {
      return AppColors.secondary;
    } else if (workoutType == WorkoutType.cycling) {
      return AppColors.success;
    } else {
      return AppColors.premium;
    }
  }

  /// Get workout icon based on type.
  IconData _getWorkoutIcon() {
    switch (activity.workoutTypeEnum) {
      case WorkoutType.gym:
        return Icons.fitness_center;
      case WorkoutType.running:
        return Icons.directions_run;
      case WorkoutType.cycling:
        return Icons.directions_bike;
      case WorkoutType.swimming:
        return Icons.pool;
      case WorkoutType.yoga:
        return Icons.self_improvement;
      case WorkoutType.hiit:
        return Icons.timer;
      case WorkoutType.walking:
        return Icons.directions_walk;
      case WorkoutType.sports:
        return Icons.sports_soccer;
      case WorkoutType.other:
        return Icons.category;
    }
  }

  /// Get stats text based on workout summary.
  String _getStatsText() {
    final summary = activity.summary;
    if (summary == null) return activity.title;

    // For cardio workouts, show distance and duration
    if (summary.isCardioWorkout) {
      final parts = <String>[];
      if (summary.distance != null) {
        parts.add('${summary.distance!.toStringAsFixed(1)} km');
      }
      if (summary.duration != null) {
        parts.add(summary.duration!);
      }
      if (parts.isNotEmpty) return parts.join(' • ');
    }

    // For strength workouts, show exercises and sets
    if (summary.totalExercises != null || summary.totalSets != null) {
      final parts = <String>[];
      if (summary.totalExercises != null) {
        parts.add(
          '${summary.totalExercises} exercise${summary.totalExercises! > 1 ? 's' : ''}',
        );
      }
      if (summary.totalSets != null) {
        parts.add(
          '${summary.totalSets} set${summary.totalSets! > 1 ? 's' : ''}',
        );
      }
      if (parts.isNotEmpty) return parts.join(', ');
    }

    return activity.title;
  }
}

/// Shimmer loading card for recent activity section.
class RecentActivityCardShimmer extends StatelessWidget {
  const RecentActivityCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 160,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppColors.borderDark.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar shimmer
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedDark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevatedDark,
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Badge shimmer
            Container(
              width: 70,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Stats shimmer
            Container(
              width: 120,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Time shimmer
            Container(
              width: 60,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

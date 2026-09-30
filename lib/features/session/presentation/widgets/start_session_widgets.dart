import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/models/models.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../utils/haptic_manager.dart';

/// Maps workout type icon names to Material icons (Z-ARCH-002).
IconData workoutTypeIconData(String iconName) {
  switch (iconName) {
    case 'fitness_center':
      return Icons.fitness_center_rounded;
    case 'directions_run':
      return Icons.directions_run_rounded;
    case 'directions_bike':
      return Icons.directions_bike_rounded;
    case 'pool':
      return Icons.pool_rounded;
    case 'self_improvement':
      return Icons.self_improvement_rounded;
    case 'timer':
      return Icons.timer_rounded;
    case 'directions_walk':
      return Icons.directions_walk_rounded;
    case 'sports_soccer':
      return Icons.sports_soccer_rounded;
    case 'category':
    default:
      return Icons.category_rounded;
  }
}

/// Section eyebrow label on the train screen (Z-ARCH-002).
class StartSessionSectionLabel extends StatelessWidget {
  const StartSessionSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textV2Tertiary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// Initials avatar used when a buddy has no photo (Z-ARCH-002).
class StartSessionAvatarPlaceholder extends StatelessWidget {
  const StartSessionAvatarPlaceholder({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceV2,
      child: Center(
        child: Text(
          user.displayName.isNotEmpty
              ? user.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

/// Workout type tile in the quick-start grid (Z-ARCH-002).
class StartSessionTypeCard extends StatelessWidget {
  const StartSessionTypeCard({
    super.key,
    required this.type,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final WorkoutType type;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeColor = AppColors.typeColor(type.value);
    final icon = workoutTypeIconData(type.icon);

    return GestureDetector(
      onTap: () {
        HapticManager.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: AppCurves.press,
        decoration: BoxDecoration(
          color: isSelected
              ? typeColor.withValues(alpha: 0.15)
              : AppColors.surfaceV2.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? typeColor : AppColors.surfaceV2Active,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -10,
                child: Transform.rotate(
                  angle: 0.6,
                  child: Container(
                    width: 40,
                    height: 120,
                    color: typeColor.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: typeColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: typeColor, size: 18),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label.toUpperCase(),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: typeColor,
                                letterSpacing: 0.08,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        color: AppColors.textV2Primary,
                      ),
                      overflow: TextOverflow.ellipsis,
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
}

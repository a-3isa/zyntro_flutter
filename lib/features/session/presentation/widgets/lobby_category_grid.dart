// lib/features/session/presentation/widgets/lobby_category_grid.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_theme.dart';

/// Reusable workout-type selection grid for the session lobby.
/// Lifted from `SessionInviteAcceptancePage._buildTypeGrid`.
class LobbyCategoryGrid extends StatelessWidget {
  const LobbyCategoryGrid({
    super.key,
    required this.hostType,
    required this.selected,
    required this.onSelect,
  });

  final WorkoutType hostType;
  final WorkoutType? selected;
  final ValueChanged<WorkoutType> onSelect;

  IconData _iconForWorkout(String iconName) {
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

  List<Color> _gradientFor(String category) {
    switch (category) {
      case 'cardio':
        return AppColors.secondaryGradient;
      case 'strength':
        return AppColors.primaryGradient;
      case 'flexibility':
        return AppColors.successGradient;
      case 'mixed':
        return AppColors.cardGradient;
      default:
        return [AppColors.textV2Secondary, AppColors.textV2Tertiary];
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 400 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: WorkoutType.values.length,
          itemBuilder: (context, index) {
            final type = WorkoutType.values[index];
            final isSelected = selected == type;
            final isHostType = type == hostType;
            final gradient = _gradientFor(type.category);

            return GestureDetector(
              onTap: () => onSelect(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : AppColors.surfaceV2Elevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : (isHostType
                              ? gradient.first.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.05)),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: gradient.first.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : gradient.first.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _iconForWorkout(type.icon),
                            size: 30,
                            color: isSelected ? Colors.white : gradient.first,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          type.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 14,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textV2Primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    if (isHostType)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : gradient.first.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'HOST',
                            style: TextStyle(
                              color: isSelected ? Colors.white : gradient.first,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

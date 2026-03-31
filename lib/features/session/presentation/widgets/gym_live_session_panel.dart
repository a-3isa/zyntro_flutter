import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/gym_session_plan.dart';

class GymLiveSessionPanel extends StatelessWidget {
  const GymLiveSessionPanel({
    super.key,
    required this.exercise,
    required this.currentSetNumber,
    required this.completedSets,
    required this.isUsersTurn,
    required this.isSetRunning,
    required this.onStartSet,
    required this.onFinishSet,
    this.isWorkoutComplete = false,
  });

  final PlannedExercise exercise;
  final int currentSetNumber;
  final int completedSets;
  final bool isUsersTurn;
  final bool isSetRunning;
  final bool isWorkoutComplete;
  final VoidCallback onStartSet;
  final VoidCallback onFinishSet;

  @override
  Widget build(BuildContext context) {
    final setLabel = 'Set $currentSetNumber of ${exercise.plannedSets}';
    final completedLabel = '$completedSets completed';

    if (!isUsersTurn) {
      return _GymLiveCard(
        icon: Icons.visibility_rounded,
        accentColor: AppColors.sessionGray400,
        title: 'Partner turn',
        subtitle: 'Cheer them on while they finish this set.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.sessionText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              setLabel,
              style: const TextStyle(
                color: AppColors.sessionMutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              completedLabel,
              style: const TextStyle(color: AppColors.sessionMutedText),
            ),
          ],
        ),
      );
    }

    return _GymLiveCard(
      icon: isWorkoutComplete ? Icons.verified_rounded : Icons.fitness_center,
      accentColor: isWorkoutComplete
          ? AppColors.sessionNeonGreen
          : AppColors.sessionNeonGreen,
      title: isWorkoutComplete ? 'Planned workout complete' : 'Your next set',
      subtitle: isWorkoutComplete
          ? 'You finished every planned set for this exercise.'
          : 'Start the set first, then log reps and weight after you finish.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.sessionText,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: setLabel,
                accentColor: AppColors.sessionNeonGreen,
              ),
              _MetricPill(
                label: completedLabel,
                accentColor: AppColors.sessionGray400,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isWorkoutComplete)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSetRunning ? onFinishSet : onStartSet,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sessionNeonGreen,
                  foregroundColor: AppColors.sessionNavy900,
                ),
                icon: Icon(
                  isSetRunning ? Icons.flag_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isSetRunning ? 'Finish Set' : 'Start Set'),
              ),
            ),
        ],
      ),
    );
  }
}

class _GymLiveCard extends StatelessWidget {
  const _GymLiveCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.sessionNavy800,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sessionText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.sessionMutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.accentColor});

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

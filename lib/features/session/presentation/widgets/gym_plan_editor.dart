import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/gym_session_plan.dart';

class GymPlanEditor extends StatelessWidget {
  const GymPlanEditor({
    super.key,
    required this.exercises,
    required this.onAddExercise,
    required this.onRemoveExercise,
    required this.onSetsChanged,
    this.isLocked = false,
  });

  final List<PlannedExercise> exercises;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;
  final void Function(int index, int plannedSets) onSetsChanged;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderDarkSecondary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Workout plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: isLocked ? null : onAddExercise,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverseDark,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add exercise'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (exercises.isEmpty)
              const Text(
                'Choose exercises from the database first. If something is missing, add it as a custom exercise.',
                style: TextStyle(color: AppColors.textSecondaryDark),
              )
            else
              ...exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDarkSecondary),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textInverseDark,
                            child: Text('${index + 1}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                if (exercise.muscleGroup != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      exercise.muscleGroup!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondaryDark,
                                          ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text(
                                      'Planned sets',
                                      style: TextStyle(
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    DropdownButton<int>(
                                      dropdownColor: AppColors.surfaceDark,
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                      ),
                                      value: exercise.plannedSets,
                                      items: List.generate(
                                        8,
                                        (setIndex) => DropdownMenuItem(
                                          value: setIndex + 1,
                                          child: Text('${setIndex + 1}'),
                                        ),
                                      ),
                                      onChanged: isLocked
                                          ? null
                                          : (value) {
                                              if (value == null) return;
                                              onSetsChanged(index, value);
                                            },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove exercise',
                            onPressed: isLocked ? null : () => onRemoveExercise(index),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

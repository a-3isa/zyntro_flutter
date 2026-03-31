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
  });

  final List<PlannedExercise> exercises;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;
  final void Function(int index, int plannedSets) onSetsChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.sessionNavy800,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sessionNavy700),
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
                      color: AppColors.sessionText,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAddExercise,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sessionNeonGreen,
                    foregroundColor: AppColors.sessionNavy900,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add exercise'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (exercises.isEmpty)
              const Text(
                'Choose exercises from the database to build your plan. If one is missing, add it as a custom exercise.',
                style: TextStyle(color: AppColors.sessionMutedText),
              )
            else
              ...exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.sessionNavy700,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.sessionGray400),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.sessionNeonGreen,
                            foregroundColor: AppColors.sessionNavy900,
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
                                    color: AppColors.sessionText,
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
                                            color: AppColors.sessionMutedText,
                                          ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text(
                                      'Planned sets',
                                      style: TextStyle(
                                        color: AppColors.sessionText,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    DropdownButton<int>(
                                      dropdownColor: AppColors.sessionNavy800,
                                      style: const TextStyle(
                                        color: AppColors.sessionText,
                                      ),
                                      value: exercise.plannedSets,
                                      items: List.generate(
                                        8,
                                        (setIndex) => DropdownMenuItem(
                                          value: setIndex + 1,
                                          child: Text('${setIndex + 1}'),
                                        ),
                                      ),
                                      onChanged: (value) {
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
                            onPressed: () => onRemoveExercise(index),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.sessionGray400,
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

import 'package:flutter/material.dart';

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
    return Card(
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
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAddExercise,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add exercise'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (exercises.isEmpty)
              const Text(
                'Choose exercises from the database to build your plan. If one is missing, add it as a custom exercise.',
              )
            else
              ...exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
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
                                  ),
                                ),
                                if (exercise.muscleGroup != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      exercise.muscleGroup!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Planned sets'),
                                    const SizedBox(width: 12),
                                    DropdownButton<int>(
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
                            icon: const Icon(Icons.delete_outline_rounded),
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

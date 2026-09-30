import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  String _planSummary() {
    final totalSets = exercises.fold<int>(0, (sum, e) => sum + e.plannedSets);
    final ex = exercises.length == 1 ? '1 exercise' : '${exercises.length} exercises';
    final st = totalSets == 1 ? '1 set' : '$totalSets sets';
    return '$ex · $st';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workout plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                      if (exercises.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _planSummary(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textV2Secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!isLocked)
                  FilledButton.icon(
                    onPressed: onAddExercise,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.signal,
                      foregroundColor: AppColors.textInverseDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Add exercise',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (exercises.isEmpty)
              const Text(
                'Choose exercises from the database first. If something is missing, add it as a custom exercise.',
                style: TextStyle(color: AppColors.textV2Secondary),
              )
            else
              ...exercises.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseCard(
                    index: entry.key,
                    exercise: entry.value,
                    isLocked: isLocked,
                    onSetsChanged: onSetsChanged,
                    onRemove: onRemoveExercise,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// A single planned-exercise row: order badge, name + muscle/equipment detail,
/// an inline +/- sets stepper, and a refined remove button.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.index,
    required this.exercise,
    required this.isLocked,
    required this.onSetsChanged,
    required this.onRemove,
  });

  final int index;
  final PlannedExercise exercise;
  final bool isLocked;
  final void Function(int index, int plannedSets) onSetsChanged;
  final ValueChanged<int> onRemove;

  static const int _minSets = 1;
  static const int _maxSets = 20;

  @override
  Widget build(BuildContext context) {
    final detail = [
      exercise.muscleGroup,
      exercise.equipment,
    ].where((v) => v != null && v.isNotEmpty).join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDarkSecondary),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.signal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.textInverseDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                      if (detail.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            detail,
                            style: const TextStyle(
                              color: AppColors.textV2Secondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isLocked)
                  _RemoveButton(onTap: () => onRemove(index)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Sets',
                  style: TextStyle(
                    color: AppColors.textV2Secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _SetsStepper(
                  value: exercise.plannedSets,
                  enabled: !isLocked,
                  onChanged: (v) => onSetsChanged(index, v),
                  min: _minSets,
                  max: _maxSets,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded +/- stepper for the planned set count.
class _SetsStepper extends StatelessWidget {
  const _SetsStepper({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDarkSecondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: enabled && value > min
                ? () {
                    HapticFeedback.selectionClick();
                    onChanged(value - 1);
                  }
                : null,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textV2Primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: enabled && value < max
                ? () {
                    HapticFeedback.selectionClick();
                    onChanged(value + 1);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? AppColors.signal
                : AppColors.textV2Tertiary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Compact, restrained remove control  a ghost icon button that only turns
/// destructive-red on press, so it reads as secondary to the plan itself.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Remove exercise',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          splashColor: AppColors.errorV2.withValues(alpha: 0.18),
          highlightColor: AppColors.errorV2.withValues(alpha: 0.10),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textV2Tertiary,
            ),
          ),
        ),
      ),
    );
  }
}

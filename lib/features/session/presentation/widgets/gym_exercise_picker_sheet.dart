import 'package:flutter/material.dart';

import '../../../../core/data/gym_exercises.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/gym_session_plan.dart';

class GymExercisePickerSheet extends StatefulWidget {
  const GymExercisePickerSheet({
    super.key,
    required this.onExerciseSelected,
  });

  final ValueChanged<PlannedExercise> onExerciseSelected;

  @override
  State<GymExercisePickerSheet> createState() => _GymExercisePickerSheetState();
}

class _GymExercisePickerSheetState extends State<GymExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GymExercise> get _results {
    return GymExercises.search(_searchController.text.trim());
  }

  Future<void> _showCustomExerciseDialog() async {
    final customController = TextEditingController(
      text: _searchController.text.trim(),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.sessionNavy800,
          title: const Text(
            'Add custom exercise',
            style: TextStyle(color: AppColors.sessionText),
          ),
          content: TextField(
            controller: customController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Exercise name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.sessionMutedText),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sessionNeonGreen,
                foregroundColor: AppColors.sessionNavy900,
              ),
              onPressed: () {
                Navigator.of(context).pop(customController.text.trim());
              },
              child: const Text('Save custom exercise'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null || result.isEmpty) return;
    widget.onExerciseSelected(
      PlannedExercise.custom(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: result,
        plannedSets: 3,
        order: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final results = _results;
    final showCustomFallback = query.isNotEmpty && results.isEmpty;

    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.sessionNavy900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add exercise',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sessionText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Search the exercise database first, then add a custom move only if you need one.',
                style: TextStyle(color: AppColors.sessionMutedText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search exercises',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: showCustomFallback
                    ? _NoMatchesState(
                        query: query,
                        onAddCustom: _showCustomExerciseDialog,
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: results.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final exercise = results[index];
                          return ListTile(
                            title: Text(
                              exercise.name,
                              style: const TextStyle(
                                color: AppColors.sessionText,
                              ),
                            ),
                            subtitle: Text(
                              '${exercise.muscleGroup.displayName} • ${exercise.equipment.map((item) => item.displayName).join(', ')}',
                              style: const TextStyle(
                                color: AppColors.sessionMutedText,
                              ),
                            ),
                            onTap: () {
                              widget.onExerciseSelected(
                                PlannedExercise.catalog(
                                  id:
                                      '${exercise.id}_${DateTime.now().microsecondsSinceEpoch}',
                                  exerciseId: exercise.id,
                                  name: exercise.name,
                                  plannedSets: 3,
                                  order: 0,
                                  muscleGroup: exercise.muscleGroup.displayName,
                                  equipment: exercise.equipment
                                      .map((item) => item.displayName)
                                      .join(', '),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState({
    required this.query,
    required this.onAddCustom,
  });

  final String query;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No exercises matched',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.sessionText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We could not find "$query" in the exercise database.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.sessionMutedText),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sessionNeonGreen,
              foregroundColor: AppColors.sessionNavy900,
            ),
            onPressed: onAddCustom,
            child: const Text('Add custom exercise'),
          ),
        ],
      ),
    );
  }
}

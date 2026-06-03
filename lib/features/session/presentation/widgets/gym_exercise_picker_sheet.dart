import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/gym_session_plan.dart';
import '../../../../services/exercise_catalog_service.dart';

class GymExercisePickerSheet extends ConsumerStatefulWidget {
  const GymExercisePickerSheet({
    super.key,
    required this.onExerciseSelected,
    this.userId,
  });

  final ValueChanged<PlannedExercise> onExerciseSelected;

  /// When provided, personal exercises for this user are included in results.
  final String? userId;

  @override
  ConsumerState<GymExercisePickerSheet> createState() =>
      _GymExercisePickerSheetState();
}

class _GymExercisePickerSheetState
    extends ConsumerState<GymExercisePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ExercisePickerResult> _results = [];
  bool _loading = false;
  bool _error = false;

  // Set-count selection state
  ExercisePickerResult? _pendingResult;
  int _pendingSetCount = 3;

  @override
  void initState() {
    super.initState();
    _doSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String query) async {
    final userId = widget.userId ?? '';
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final service = ref.read(exerciseCatalogServiceProvider);
      final results = await service.search(userId, query);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectExercise(ExercisePickerResult result) {
    setState(() {
      _pendingResult = result;
      _pendingSetCount = 3;
    });
  }

  void _confirmSelection() {
    final result = _pendingResult;
    if (result == null) return;

    final id = '${result.id}_${DateTime.now().microsecondsSinceEpoch}';
    final PlannedExercise exercise;

    if (result.source == ExerciseResultSource.catalog) {
      exercise = PlannedExercise.catalog(
        id: id,
        exerciseId: result.id,
        name: result.name,
        plannedSets: _pendingSetCount,
        order: 0,
        muscleGroup: result.muscleGroup,
        equipment: result.equipment,
      );
    } else {
      exercise = PlannedExercise.custom(
        id: id,
        name: result.name,
        plannedSets: _pendingSetCount,
        order: 0,
        personalExerciseId: result.id,
        muscleGroup: result.muscleGroup,
        equipment: result.equipment,
      );
    }

    widget.onExerciseSelected(exercise);
  }

  Future<void> _showCustomExerciseDialog() async {
    final customController = TextEditingController(
      text: _searchController.text.trim(),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceV2,
          title: const Text(
            'Add custom exercise',
            style: TextStyle(color: AppColors.textV2Primary),
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
                style: TextStyle(color: AppColors.textV2Secondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverseDark,
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
    // Create via service if userId is available, otherwise create local custom
    final userId = widget.userId;
    if (userId != null && userId.isNotEmpty) {
      try {
        final service = ref.read(exerciseCatalogServiceProvider);
        final pickerResult = await service.createCustomExercise(
          userId: userId,
          name: result,
        );
        _selectExercise(pickerResult);
        return;
      } catch (_) {
        // Fall through to local custom on service error
      }
    }
    // Local custom fallback (no userId or service error)
    _selectExercise(ExercisePickerResult(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      source: ExerciseResultSource.custom,
      name: result,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // If an exercise is pending set-count confirmation, show the set selector.
    final pending = _pendingResult;
    if (pending != null) {
      return _SetCountSelector(
        exercise: pending,
        setCount: _pendingSetCount,
        onSetCountChanged: (v) => setState(() => _pendingSetCount = v),
        onConfirm: _confirmSelection,
        onBack: () => setState(() => _pendingResult = null),
      );
    }

    final query = _searchController.text.trim();
    final showNoResults = !_loading && !_error && query.isNotEmpty && _results.isEmpty;

    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.backgroundV2),
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
                  color: AppColors.textV2Primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Search the exercise database first, then add a custom move only if you need one.',
                style: TextStyle(color: AppColors.textV2Secondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search exercises',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => _doSearch(v.trim()),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: _buildResultsArea(query, showNoResults),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsArea(String query, bool showNoResults) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load exercises',
              style: TextStyle(color: AppColors.textV2Primary),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverseDark,
              ),
              onPressed: () => _doSearch(_searchController.text.trim()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (showNoResults) {
      return _NoMatchesState(
        query: query,
        onAddCustom: _showCustomExerciseDialog,
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (context, idx) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _results[index];
        final detail = [result.muscleGroup, result.equipment]
            .where((v) => v != null && v.isNotEmpty)
            .join(' • ');
        return ListTile(
          title: Text(
            result.name,
            style: const TextStyle(color: AppColors.textV2Primary),
          ),
          subtitle: detail.isNotEmpty
              ? Text(
                  detail,
                  style: const TextStyle(color: AppColors.textV2Secondary),
                )
              : null,
          onTap: () => _selectExercise(result),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Set count selector (T023)
// ---------------------------------------------------------------------------

class _SetCountSelector extends StatelessWidget {
  const _SetCountSelector({
    required this.exercise,
    required this.setCount,
    required this.onSetCountChanged,
    required this.onConfirm,
    required this.onBack,
  });

  final ExercisePickerResult exercise;
  final int setCount;
  final ValueChanged<int> onSetCountChanged;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  static const int _minSets = 1;
  static const int _maxSets = 20;

  @override
  Widget build(BuildContext context) {
    final isValid = setCount >= _minSets && setCount <= _maxSets;
    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.backgroundV2),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.textV2Secondary),
                    SizedBox(width: 4),
                    Text('Back',
                        style: TextStyle(color: AppColors.textV2Secondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Primary,
                ),
              ),
              if (exercise.muscleGroup != null) ...[
                const SizedBox(height: 4),
                Text(
                  exercise.muscleGroup!,
                  style:
                      const TextStyle(color: AppColors.textV2Secondary),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Sets',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textV2Primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.textV2Secondary),
                    onPressed: setCount > _minSets
                        ? () => onSetCountChanged(setCount - 1)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$setCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.textV2Secondary),
                    onPressed: setCount < _maxSets
                        ? () => onSetCountChanged(setCount + 1)
                        : null,
                  ),
                ],
              ),
              if (!isValid)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Please choose between 1 and 20 sets',
                    style: TextStyle(color: AppColors.errorV2, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isValid
                        ? AppColors.primary
                        : AppColors.textV2Tertiary,
                    foregroundColor: AppColors.textInverseDark,
                  ),
                  onPressed: isValid ? onConfirm : null,
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No matches empty state (unchanged)
// ---------------------------------------------------------------------------

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
              color: AppColors.textV2Primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We could not find "$query" in the exercise database.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textV2Secondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverseDark,
            ),
            onPressed: onAddCustom,
            child: const Text('Add custom exercise'),
          ),
        ],
      ),
    );
  }
}

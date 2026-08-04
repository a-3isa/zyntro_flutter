import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/gym_session_plan.dart';
import '../../../../services/exercise_catalog_service.dart';

/// Multi-select exercise picker. Tap a row to toggle it in/out of the
/// selection; selected rows get an inline sets stepper. Returns the final
/// list of [PlannedExercise] via `Navigator.pop` when Save is tapped
/// (or `null`/an empty pop when dismissed without saving).
class GymExercisePickerSheet extends ConsumerStatefulWidget {
  const GymExercisePickerSheet({super.key, this.userId});

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

  // Selection state, keyed by ExercisePickerResult.id. _selectionOrder tracks
  // the order exercises were tapped so Save preserves that order.
  final Map<String, ExercisePickerResult> _selectedResults = {};
  final Map<String, int> _selectedSetCounts = {};
  final List<String> _selectionOrder = [];

  static const int _minSets = 1;
  static const int _maxSets = 20;
  static const int _defaultSets = 3;

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

  void _toggleExercise(ExercisePickerResult result) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedResults.containsKey(result.id)) {
        _selectedResults.remove(result.id);
        _selectedSetCounts.remove(result.id);
        _selectionOrder.remove(result.id);
      } else {
        _selectedResults[result.id] = result;
        _selectedSetCounts[result.id] = _defaultSets;
        _selectionOrder.add(result.id);
      }
    });
  }

  void _addAndSelect(ExercisePickerResult result) {
    setState(() {
      if (!_results.any((r) => r.id == result.id)) {
        _results = [result, ..._results];
      }
      _selectedResults[result.id] = result;
      _selectedSetCounts[result.id] = _defaultSets;
      if (!_selectionOrder.contains(result.id)) {
        _selectionOrder.add(result.id);
      }
    });
  }

  void _changeSetCount(String id, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = _selectedSetCounts[id] ?? _defaultSets;
      _selectedSetCounts[id] = (current + delta).clamp(_minSets, _maxSets);
    });
  }

  void _save() {
    final exercises = <PlannedExercise>[];
    for (var i = 0; i < _selectionOrder.length; i++) {
      final id = _selectionOrder[i];
      final result = _selectedResults[id];
      if (result == null) continue;
      final setCount = _selectedSetCounts[id] ?? _defaultSets;
      final plannedId = '${result.id}_${DateTime.now().microsecondsSinceEpoch}_$i';

      exercises.add(
        result.source == ExerciseResultSource.catalog
            ? PlannedExercise.catalog(
                id: plannedId,
                exerciseId: result.id,
                name: result.name,
                plannedSets: setCount,
                order: i,
                muscleGroup: result.muscleGroup,
                equipment: result.equipment,
              )
            : PlannedExercise.custom(
                id: plannedId,
                name: result.name,
                plannedSets: setCount,
                order: i,
                personalExerciseId: result.id,
                muscleGroup: result.muscleGroup,
                equipment: result.equipment,
              ),
      );
    }
    Navigator.of(context).pop(exercises);
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                backgroundColor: AppColors.userAccent,
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
        _addAndSelect(pickerResult);
        return;
      } catch (_) {
        // Fall through to local custom on service error
      }
    }
    // Local custom fallback (no userId or service error)
    _addAndSelect(
      ExercisePickerResult(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        source: ExerciseResultSource.custom,
        name: result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    // Show empty state whenever there are no results (including initial empty load),
    // not only when the user has typed a query.
    final showNoResults = !_loading && !_error && _results.isEmpty;
    final selectedCount = _selectionOrder.length;

    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.backgroundV2),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add exercises',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textV2Secondary,
                    ),
                  ),
                ],
              ),
              const Text(
                'Tap to select. Search the database first, then add a custom move only if you need one.',
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
              Flexible(child: _buildResultsArea(query, showNoResults)),
              const SizedBox(height: 12),
              _buildSaveBar(selectedCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveBar(int selectedCount) {
    final hasSelection = selectedCount > 0;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: hasSelection
              ? AppColors.userAccent
              : AppColors.surfaceV2Elevated,
          foregroundColor: hasSelection
              ? AppColors.textInverseDark
              : AppColors.textV2Tertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: hasSelection ? _save : null,
        child: Text(
          hasSelection
              ? 'Save $selectedCount exercise${selectedCount == 1 ? '' : 's'}'
              : 'Select exercises to continue',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildResultsArea(String query, bool showNoResults) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading exercises'));
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
                backgroundColor: AppColors.userAccent,
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
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        final isSelected = _selectedResults.containsKey(result.id);
        final setCount = _selectedSetCounts[result.id] ?? _defaultSets;
        final detail = [
          result.muscleGroup,
          result.equipment,
        ].where((v) => v != null && v.isNotEmpty).join(' · ');

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.userAccent.withValues(alpha: 0.12)
                  : AppColors.surfaceV2Elevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.userAccent
                    : AppColors.borderDarkSecondary,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _toggleExercise(result),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SelectionIndicator(isSelected: isSelected),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.userAccent
                                    : AppColors.textV2Primary,
                              ),
                            ),
                            if (detail.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  detail,
                                  style: const TextStyle(
                                    color: AppColors.textV2Secondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (isSelected) ...[
                              const SizedBox(height: 8),
                              _SetCountStepper(
                                setCount: setCount,
                                minSets: _minSets,
                                maxSets: _maxSets,
                                onDecrement: () =>
                                    _changeSetCount(result.id, -1),
                                onIncrement: () =>
                                    _changeSetCount(result.id, 1),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Row sub-widgets
// ---------------------------------------------------------------------------

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.userAccent : Colors.transparent,
        border: isSelected
            ? null
            : Border.all(color: AppColors.textV2Tertiary, width: 1.5),
      ),
      child: isSelected
          ? const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.textInverseDark,
            )
          : null,
    );
  }
}

class _SetCountStepper extends StatelessWidget {
  const _SetCountStepper({
    required this.setCount,
    required this.minSets,
    required this.maxSets,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int setCount;
  final int minSets;
  final int maxSets;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepperButton(
          icon: Icons.remove_rounded,
          onPressed: setCount > minSets ? onDecrement : null,
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$setCount sets',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Primary,
              fontSize: 13,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          onPressed: setCount < maxSets ? onIncrement : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceV2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? AppColors.textV2Primary
                : AppColors.textV2Tertiary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No matches empty state
// ---------------------------------------------------------------------------

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState({required this.query, required this.onAddCustom});

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
              backgroundColor: AppColors.userAccent,
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

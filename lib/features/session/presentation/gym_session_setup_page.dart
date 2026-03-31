import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/session_service.dart';
import '../domain/gym_session_plan.dart';
import 'widgets/gym_exercise_picker_sheet.dart';
import 'widgets/gym_plan_editor.dart';

/// Minimal shell for gym setup sessions.
class GymSessionSetupPage extends ConsumerStatefulWidget {
  final String sessionId;

  const GymSessionSetupPage({super.key, required this.sessionId});

  @override
  ConsumerState<GymSessionSetupPage> createState() =>
      _GymSessionSetupPageState();
}

class _GymSessionSetupPageState extends ConsumerState<GymSessionSetupPage> {
  bool _didRedirect = false;
  List<PlannedExercise> _draftExercises = const [];

  Future<void> _openExercisePicker() async {
    final selected = await showModalBottomSheet<PlannedExercise>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return GymExercisePickerSheet(
          onExerciseSelected: (exercise) => Navigator.of(context).pop(exercise),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _draftExercises = [
        ..._draftExercises,
        _withOrderAndSets(
          exercise: selected,
          order: _draftExercises.length,
          plannedSets: selected.plannedSets,
        ),
      ];
    });
  }

  void _removeExercise(int index) {
    setState(() {
      final updated = [..._draftExercises]..removeAt(index);
      _draftExercises = _reindexExercises(updated);
    });
  }

  void _updatePlannedSets(int index, int plannedSets) {
    final updated = [..._draftExercises];
    updated[index] = _withOrderAndSets(
      exercise: updated[index],
      order: index,
      plannedSets: plannedSets,
    );
    setState(() => _draftExercises = updated);
  }

  List<PlannedExercise> _reindexExercises(List<PlannedExercise> exercises) {
    return exercises.asMap().entries.map((entry) {
      return _withOrderAndSets(
        exercise: entry.value,
        order: entry.key,
        plannedSets: entry.value.plannedSets,
      );
    }).toList();
  }

  PlannedExercise _withOrderAndSets({
    required PlannedExercise exercise,
    required int order,
    required int plannedSets,
  }) {
    if (exercise.source == PlannedExerciseSource.catalog) {
      return PlannedExercise.catalog(
        id: exercise.id,
        exerciseId: exercise.exerciseId!,
        name: exercise.name,
        plannedSets: plannedSets,
        order: order,
        muscleGroup: exercise.muscleGroup,
        equipment: exercise.equipment,
      );
    }

    return PlannedExercise.custom(
      id: exercise.id,
      name: exercise.name,
      plannedSets: plannedSets,
      order: order,
      muscleGroup: exercise.muscleGroup,
      equipment: exercise.equipment,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Session?>>(
      currentSessionProvider(widget.sessionId),
      (previous, next) {
        final session = next.valueOrNull;
        if (!mounted || _didRedirect) return;
        if (session == null || session.phase != SessionPhase.live) return;

        _didRedirect = true;
        context.go(
          '${AppRoutes.sessionRoom.replaceFirst(':sessionId', session.id)}?type=${session.type}',
        );
      },
    );

    final sessionAsync = ref.watch(currentSessionProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: sessionAsync.when(
              loading: _buildLoadingShell,
              error: (error, stackTrace) => _buildErrorShell(),
              data: (session) {
                if (session == null) {
                  return _buildErrorShell(
                    title: 'Session not found',
                    message: 'We could not load this gym setup session.',
                  );
                }

                return _buildSetupShell(session);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShell() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        SizedBox(height: 20),
        Text(
          'Preparing your gym session',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'We are loading the setup details now.',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSetupShell(Session session) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Gym session setup',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Prepare your plan before jumping into the live room.',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            session.title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GymPlanEditor(
            exercises: _draftExercises,
            onAddExercise: _openExercisePicker,
            onRemoveExercise: _removeExercise,
            onSetsChanged: _updatePlannedSets,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorShell({
    String title = 'Unable to load setup',
    String message = 'Please try again in a moment.',
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 32,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

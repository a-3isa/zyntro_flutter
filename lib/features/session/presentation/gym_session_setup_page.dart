import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_providers.dart';
import '../../../services/session_service.dart';
import '../domain/gym_session_plan.dart';
import 'widgets/gym_exercise_picker_sheet.dart';
import 'widgets/gym_plan_editor.dart';

/// Interactive gym setup flow before a session goes live.
class GymSessionSetupPage extends ConsumerStatefulWidget {
  final String sessionId;
  /// Pre-seeded exercises (e.g. cloned from host plan on invite acceptance).
  /// When provided, skips the Firestore plan fetch and uses these directly.
  final List<PlannedExercise>? seededExercises;

  const GymSessionSetupPage({
    super.key,
    required this.sessionId,
    this.seededExercises,
  });

  @override
  ConsumerState<GymSessionSetupPage> createState() =>
      _GymSessionSetupPageState();
}

class _GymSessionSetupPageState extends ConsumerState<GymSessionSetupPage> {
  bool _didRedirect = false;
  List<PlannedExercise> _draftExercises = const [];
  bool _isLoadingPlan = true;
  bool _isSavingReady = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.seededExercises != null) {
      // Pre-seeded by invite acceptance — no Firestore fetch needed
      _draftExercises = _reindexExercises(widget.seededExercises!);
      _isLoadingPlan = false;
    } else {
      Future.microtask(_loadInitialPlan);
    }
  }

  Future<void> _loadInitialPlan() async {
    final authUser = await ref.read(authSessionProvider.future);
    final session = await ref.read(currentSessionProvider(widget.sessionId).future);
    if (!mounted || authUser == null || session == null) {
      if (mounted) {
        setState(() => _isLoadingPlan = false);
      }
      return;
    }

    final sessionService = ref.read(sessionServiceProvider);
    if (!session.participants.contains(authUser.id)) {
      await sessionService.joinSession(widget.sessionId, authUser.id);
    }

    final plan = await sessionService.ensureGymPlan(
      sessionId: widget.sessionId,
      hostId: session.hostId,
      userId: authUser.id,
    );

    if (!mounted) return;
    setState(() {
      _draftExercises = _reindexExercises(plan.exercises);
      _isReady = plan.isReady;
      _isLoadingPlan = false;
    });
  }

  Future<void> _openExercisePicker() async {
    if (_isReady) return;
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
    if (_isReady) return;
    setState(() {
      final updated = [..._draftExercises]..removeAt(index);
      _draftExercises = _reindexExercises(updated);
    });
  }

  void _updatePlannedSets(int index, int plannedSets) {
    if (_isReady) return;
    final updated = [..._draftExercises];
    updated[index] = _withOrderAndSets(
      exercise: updated[index],
      order: index,
      plannedSets: plannedSets,
    );
    setState(() => _draftExercises = updated);
  }

  bool get _isPlanValid {
    return _draftExercises.isNotEmpty &&
        _draftExercises.every((exercise) => exercise.plannedSets > 0);
  }

  Future<void> _markReady(Session session) async {
    if (_isSavingReady || !_isPlanValid) return;

    final authUser = ref.read(authSessionProvider).valueOrNull;
    if (authUser == null) return;

    setState(() => _isSavingReady = true);
    final sessionService = ref.read(sessionServiceProvider);
    final plan = GymSessionPlan(
      userId: authUser.id,
      source: authUser.id == session.hostId
          ? GymSessionPlanSource.hostTemplate
          : GymSessionPlanSource.personal,
      isReady: true,
      exercises: _draftExercises,
    );

    try {
      await sessionService.saveGymPlan(sessionId: widget.sessionId, plan: plan);
      await sessionService.setGymPlanReady(
        sessionId: widget.sessionId,
        userId: authUser.id,
        isReady: true,
      );

      if (!mounted) return;
      setState(() {
        _isReady = true;
        _isSavingReady = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingReady = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save your setup yet: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
          AppRouteLocations.sessionRoom(session.id, type: session.type),
        );
      },
    );

    final sessionAsync = ref.watch(currentSessionProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.accentLime,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Preparing your gym session',
          style: GoogleFonts.syne(
            color: AppColors.textV2Primary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Loading the setup details now.',
          style: GoogleFonts.outfit(
            color: AppColors.textV2Secondary,
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
          Text(
            'Gym Session Setup',
            style: GoogleFonts.syne(
              color: AppColors.textV2Primary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            _isReady
                ? 'Your plan is locked in. We will jump to the live room once everyone is ready.'
                : 'Prepare your plan before jumping into the live room.',
            style: GoogleFonts.outfit(
              color: AppColors.textV2Secondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            session.title,
            style: GoogleFonts.syne(
              color: AppColors.textV2Primary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_isLoadingPlan)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            GymPlanEditor(
              exercises: _draftExercises,
              onAddExercise: _openExercisePicker,
              onRemoveExercise: _removeExercise,
              onSetsChanged: _updatePlannedSets,
              isLocked: _isReady,
            ),
            const SizedBox(height: 16),
            Text(
              _isReady
                  ? 'Waiting for the rest of the group to finish setup.'
                  : 'Each athlete can personalize their own copy of this plan before the room starts.',
              style: GoogleFonts.outfit(
                color: AppColors.textV2Secondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isReady || !_isPlanValid || _isSavingReady
                  ? null
                  : () => _markReady(session),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _isReady || !_isPlanValid || _isSavingReady
                      ? AppColors.surfaceV2Active
                      : AppColors.accentLime,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _isSavingReady
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.backgroundV2,
                          ),
                        )
                      : Text(
                          _isReady ? 'Ready — Locked in' : 'I\'m Ready',
                          style: GoogleFonts.syne(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _isReady || !_isPlanValid
                                ? AppColors.textV2Tertiary
                                : AppColors.backgroundV2,
                          ),
                        ),
                ),
              ),
            ),
          ],
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
          style: GoogleFonts.syne(
            color: AppColors.textV2Primary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: GoogleFonts.outfit(
            color: AppColors.textV2Secondary,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_providers.dart';
import '../../../services/session_service.dart';
import '../../../services/user_cache_service.dart';
import '../domain/gym_session_plan.dart';
import 'widgets/gym_exercise_picker_sheet.dart';
import 'widgets/gym_plan_editor.dart';

/// Page shown when a user taps a session invite notification.
/// Lets them preview the host's workout, pick their own workout type,
/// optionally edit the host's gym plan, and join the session.
class SessionInviteAcceptancePage extends ConsumerStatefulWidget {
  const SessionInviteAcceptancePage({
    super.key,
    required this.sessionId,
    this.notificationData,
  });

  final String sessionId;
  final Map<String, dynamic>? notificationData;

  @override
  ConsumerState<SessionInviteAcceptancePage> createState() =>
      _SessionInviteAcceptancePageState();
}

class _SessionInviteAcceptancePageState
    extends ConsumerState<SessionInviteAcceptancePage> {
  User? _host;
  bool _isLoadingHost = true;
  String? _hostLoadError;

  bool _isLoadingHostPlan = false;
  List<PlannedExercise> _exercises = [];
  bool _hasInitializedFromHost = false;
  String? _lastHostPlanLoadedForHostId;

  WorkoutType? _selectedType;
  bool _isJoining = false;
  bool _redirectAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHost());
  }

  Future<void> _loadHost() async {
    final sessionAsync = ref.read(currentSessionProvider(widget.sessionId));
    final session = sessionAsync.valueOrNull;
    if (session == null) {
      // Wait until session resolves; will be retried from build via _ensureInitialized.
      return;
    }
    await _ensureHostAndDefaults(session);
  }

  Future<void> _ensureHostAndDefaults(Session session) async {
    if (_host != null && _host!.id == session.hostId) return;

    if (mounted) {
      setState(() {
        _isLoadingHost = true;
        _hostLoadError = null;
      });
    }

    try {
      final host = await ref
          .read(userCacheServiceProvider)
          .getUser(session.hostId);
      if (!mounted) return;

      setState(() {
        _host = host;
        _isLoadingHost = false;
        _selectedType ??= WorkoutType.fromString(session.type);
      });

      // If user pre-selects (or defaults to) gym, load host plan once.
      if (_selectedType == WorkoutType.gym) {
        await _loadHostPlanIfNeeded(session.hostId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHost = false;
        _hostLoadError = 'Could not load host info. $e';
      });
    }
  }

  Future<void> _loadHostPlanIfNeeded(String hostId) async {
    if (_lastHostPlanLoadedForHostId == hostId && _hasInitializedFromHost) {
      return;
    }
    if (_isLoadingHostPlan) return;

    setState(() => _isLoadingHostPlan = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('plans')
          .doc(hostId)
          .get();

      final data = snapshot.data();
      List<PlannedExercise> seeded = const [];
      if (snapshot.exists && data != null) {
        final hostPlan = GymSessionPlan.fromMap(data);
        seeded = hostPlan.exercises
            .map((exercise) => PlannedExercise.fromMap(exercise.toMap()))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _exercises = seeded;
        _hasInitializedFromHost = true;
        _lastHostPlanLoadedForHostId = hostId;
        _isLoadingHostPlan = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHostPlan = false;
      });
      _showError('Could not load host\'s plan: $e');
    }
  }

  void _onSelectType(WorkoutType type, Session session) {
    if (_selectedType == type) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedType = type);

    if (type == WorkoutType.gym) {
      _loadHostPlanIfNeeded(session.hostId);
    }
  }

  Future<void> _openExercisePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: GymExercisePickerSheet(
          onExerciseSelected: (exercise) {
            Navigator.of(ctx).pop();
            setState(() {
              final nextOrder = _exercises.length;
              _exercises = [
                ..._exercises,
                exercise.source == PlannedExerciseSource.catalog
                    ? PlannedExercise.catalog(
                        id: exercise.id,
                        exerciseId: exercise.exerciseId!,
                        name: exercise.name,
                        plannedSets: exercise.plannedSets,
                        order: nextOrder,
                        muscleGroup: exercise.muscleGroup,
                        equipment: exercise.equipment,
                      )
                    : PlannedExercise.custom(
                        id: exercise.id,
                        name: exercise.name,
                        plannedSets: exercise.plannedSets,
                        order: nextOrder,
                        muscleGroup: exercise.muscleGroup,
                        equipment: exercise.equipment,
                      ),
              ];
            });
          },
        ),
      ),
    );
  }

  void _removeExercise(int index) {
    if (index < 0 || index >= _exercises.length) return;
    setState(() {
      final next = List<PlannedExercise>.from(_exercises)..removeAt(index);
      _exercises = _reindex(next);
    });
  }

  void _updateSets(int index, int plannedSets) {
    if (index < 0 || index >= _exercises.length) return;
    final existing = _exercises[index];
    setState(() {
      final next = List<PlannedExercise>.from(_exercises);
      next[index] = existing.source == PlannedExerciseSource.catalog
          ? PlannedExercise.catalog(
              id: existing.id,
              exerciseId: existing.exerciseId!,
              name: existing.name,
              plannedSets: plannedSets,
              order: existing.order,
              muscleGroup: existing.muscleGroup,
              equipment: existing.equipment,
            )
          : PlannedExercise.custom(
              id: existing.id,
              name: existing.name,
              plannedSets: plannedSets,
              order: existing.order,
              muscleGroup: existing.muscleGroup,
              equipment: existing.equipment,
            );
      _exercises = next;
    });
  }

  List<PlannedExercise> _reindex(List<PlannedExercise> list) {
    return List<PlannedExercise>.generate(list.length, (index) {
      final item = list[index];
      if (item.order == index) return item;
      return item.source == PlannedExerciseSource.catalog
          ? PlannedExercise.catalog(
              id: item.id,
              exerciseId: item.exerciseId!,
              name: item.name,
              plannedSets: item.plannedSets,
              order: index,
              muscleGroup: item.muscleGroup,
              equipment: item.equipment,
            )
          : PlannedExercise.custom(
              id: item.id,
              name: item.name,
              plannedSets: item.plannedSets,
              order: index,
              muscleGroup: item.muscleGroup,
              equipment: item.equipment,
            );
    });
  }

  Future<void> _handleJoin(Session session) async {
    final selectedType = _selectedType;
    if (selectedType == null) return;

    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    if (uid == null) {
      _showError('You must be signed in to accept an invite.');
      return;
    }

    setState(() => _isJoining = true);

    try {
      GymSessionPlan? planToSubmit;
      if (selectedType == WorkoutType.gym) {
        planToSubmit = GymSessionPlan(
          userId: uid,
          source: session.hostId == uid
              ? GymSessionPlanSource.hostTemplate
              : GymSessionPlanSource.personal,
          isReady: false,
          exercises: _reindex(_exercises),
        );
      }

      await ref.read(sessionServiceProvider).acceptInvite(
            sessionId: widget.sessionId,
            userId: uid,
            chosenWorkoutType: selectedType.value,
            plan: planToSubmit,
          );

      await HapticFeedback.mediumImpact();

      if (!mounted) return;
      _navigateToNextScreen(selectedType);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isJoining = false);
      await HapticFeedback.vibrate();
      _showError('Could not join session. $e');
    }
  }

  void _navigateToNextScreen(WorkoutType type) {
    if (type == WorkoutType.gym) {
      context.go(AppRouteLocations.gymSessionSetup(widget.sessionId));
    } else {
      context.go(AppRouteLocations.sessionRoom(
        widget.sessionId,
        type: type.value,
      ));
    }
  }

  void _handleAlreadyParticipant(Session session, String uid) {
    if (_redirectAttempted) return;
    _redirectAttempted = true;

    final recordedType = session.participantTypes[uid];
    final type = recordedType != null
        ? WorkoutType.fromString(recordedType)
        : WorkoutType.fromString(session.type);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRouteLocations.sessionEntry(
        sessionId: widget.sessionId,
        type: type.value,
        phase: session.phase,
      ));
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  IconData _iconForWorkout(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'directions_run':
        return Icons.directions_run_rounded;
      case 'directions_bike':
        return Icons.directions_bike_rounded;
      case 'pool':
        return Icons.pool_rounded;
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      case 'timer':
        return Icons.timer_rounded;
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
      case 'category':
      default:
        return Icons.category_rounded;
    }
  }

  List<Color> _gradientFor(String category) {
    switch (category) {
      case 'cardio':
        return AppColors.secondaryGradient;
      case 'strength':
        return AppColors.primaryGradient;
      case 'flexibility':
        return AppColors.successGradient;
      case 'mixed':
        return AppColors.cardGradient;
      default:
        return [AppColors.textSecondaryDark, AppColors.textTertiaryDark];
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(currentSessionProvider(widget.sessionId));
    final authUser = ref.watch(authSessionProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => _buildLoading(),
          error: (err, _) => _buildError(
            message: 'Could not load this invite.\n$err',
            onRetry: () => ref.refresh(currentSessionProvider(widget.sessionId)),
          ),
          data: (session) {
            if (session == null) {
              return _buildError(
                message: 'This session no longer exists.',
                onRetry: () => context.pop(),
                retryLabel: 'Go back',
              );
            }

            // Kick off host load if needed.
            if (!_isLoadingHost && _host == null && _hostLoadError == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _ensureHostAndDefaults(session);
              });
            } else if (_host != null && _host!.id != session.hostId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _ensureHostAndDefaults(session);
              });
            }

            // Handle already-a-participant case.
            if (authUser != null &&
                session.participants.contains(authUser.id)) {
              _handleAlreadyParticipant(session, authUser.id);
              return _buildLoading();
            }

            if (_isLoadingHost || _selectedType == null) {
              return _buildLoading();
            }
            if (_hostLoadError != null) {
              return _buildError(
                message: _hostLoadError!,
                onRetry: () => _ensureHostAndDefaults(session),
              );
            }

            return _buildContent(session);
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildError({
    required String message,
    required VoidCallback onRetry,
    String retryLabel = 'Retry',
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 56, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 12,
              ),
            ),
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Session session) {
    final selectedType = _selectedType!;
    final hostType = WorkoutType.fromString(session.type);
    final isGym = selectedType == WorkoutType.gym;
    final isSameAsHost = selectedType == hostType;

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHostCard(session, hostType),
                const SizedBox(height: 24),
                const _SectionTitle('Choose your workout'),
                const SizedBox(height: 8),
                Text(
                  isSameAsHost
                      ? 'Same as host — you will share turns during the session.'
                      : 'Different from host — you will train side-by-side in parallel.',
                  style: const TextStyle(
                    color: AppColors.textTertiaryDark,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTypeGrid(session, hostType),
                const SizedBox(height: 28),
                if (isGym) ...[
                  const _SectionTitle('Edit your plan'),
                  const SizedBox(height: 8),
                  const Text(
                    'We pre-loaded the host\'s plan. Add or remove exercises and tune your set counts before you join.',
                    style: TextStyle(
                      color: AppColors.textTertiaryDark,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingHostPlan)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else
                    GymPlanEditor(
                      exercises: _exercises,
                      onAddExercise: _openExercisePicker,
                      onRemoveExercise: _removeExercise,
                      onSetsChanged: _updateSets,
                      isLocked: _isJoining,
                    ),
                ] else ...[
                  _buildParallelCard(selectedType),
                ],
                const SizedBox(height: 32),
                _buildJoinCta(session, selectedType),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _isJoining
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRouteLocations.main);
                    }
                  },
            tooltip: 'Decline',
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textDark, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceSecondaryDark,
              padding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Session Invite',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostCard(Session session, WorkoutType hostType) {
    final host = _host;
    final hostName = host?.displayName ?? 'A friend';
    final initial = hostName.isNotEmpty ? hostName[0].toUpperCase() : '?';
    final gradient = _gradientFor(hostType.category);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: gradient.first.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostName,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'invited you to train',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: gradient.first.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconForWorkout(hostType.icon),
                            color: gradient.first,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hostType.displayName,
                            style: TextStyle(
                              color: gradient.first,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeGrid(Session session, WorkoutType hostType) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 400 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: WorkoutType.values.length,
          itemBuilder: (context, index) {
            final type = WorkoutType.values[index];
            final isSelected = _selectedType == type;
            final isHostType = type == hostType;
            final gradient = _gradientFor(type.category);

            return GestureDetector(
              onTap: _isJoining ? null : () => _onSelectType(type, session),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : AppColors.surfaceSecondaryDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : (isHostType
                            ? gradient.first.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.05)),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: gradient.first.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : gradient.first.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _iconForWorkout(type.icon),
                            size: 30,
                            color:
                                isSelected ? Colors.white : gradient.first,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          type.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 14,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    if (isHostType)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : gradient.first.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'HOST',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : gradient.first,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParallelCard(WorkoutType type) {
    final gradient = _gradientFor(type.category);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDarkSecondary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gradient.first.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _iconForWorkout(type.icon),
              color: gradient.first,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You will log your ${type.displayName.toLowerCase()} workout',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Side-by-side with the host. No plan needed — just join and start moving.',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCta(Session session, WorkoutType type) {
    final gradient = _gradientFor(type.category);
    final canJoin = !_isJoining && !_isLoadingHostPlan;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: canJoin
              ? LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: canJoin ? null : AppColors.surfaceSecondaryDark,
          borderRadius: BorderRadius.circular(18),
          boxShadow: canJoin
              ? [
                  BoxShadow(
                    color: gradient.first.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: canJoin ? () => _handleJoin(session) : null,
            child: Center(
              child: _isJoining
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          type == WorkoutType.gym
                              ? 'Review Plan & Join'
                              : 'Join Session',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 17,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
      ),
    );
  }
}

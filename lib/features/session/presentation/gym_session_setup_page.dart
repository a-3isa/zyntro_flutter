import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_providers.dart';
import '../../../services/session_service.dart';
import '../domain/gym_session_plan.dart';
import 'widgets/gym_exercise_picker_sheet.dart';
import 'widgets/gym_plan_editor.dart';
import 'widgets/lobby_category_grid.dart';

// ---------------------------------------------------------------------------
// Lobby state enum — private to this file.
// ---------------------------------------------------------------------------
enum _LobbyState {
  terminalCancelled, // status == cancelled (host cancelled / friend left)
  terminalDeclined, // invitationStatus == declined (friend declined before joining)
  hostBuildingPlan, // gym host: editor (ready disabled until friend joins)
  hostNonGymConfirm, // non-gym host: "I'm ready" (disabled until friend joins)
  hostWaitingForBuddy, // host is ready; waiting for friend to join/agree
  friendChoosingCategory,
  friendWaitingForHostPlan,
  friendReviewPlan,
  friendConfirm, // non-gym/different-cat friend: "Ready to start?"
  selfWaitingForPartner,
}

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
  WorkoutType? _friendChosenType;

  /// The "I'm ready" action is enabled only once the invited friend has joined
  /// (solo/matchmaking sessions have no invited friend → always enabled). The
  /// gate also enforces this server-side; this is the UI mirror.
  /// NOTE: the Session model has no `invitedUserIds`; the single invited friend
  /// is `partnerId` with `partnerKind == realFriend`.
  bool _readyEnabled(Session session) {
    final friend = session.partnerId;
    if (session.partnerKind != PairedPartnerKind.realFriend || friend == null) {
      return true;
    }
    return session.participants.contains(friend);
  }

  _LobbyState _resolveState(Session session, String uid) {
    final isHost = session.hostId == uid;
    final hostType = WorkoutType.fromString(session.type);

    // Terminal states first — neither side can proceed past these.
    if (session.status == SessionStatus.cancelled) {
      return _LobbyState.terminalCancelled;
    }
    if (session.invitationStatus == WorkoutInvitationStatus.declined) {
      return _LobbyState.terminalDeclined;
    }

    final viewerType =
        WorkoutType.fromString(session.participantTypes[uid] ?? session.type);

    // Matchmaking / non-invite setup sessions reuse this same page but must
    // KEEP the legacy behavior: every participant builds independently and marks
    // ready — no friend handshake, no waiting-for-host, no category step.
    // Friend invites are exactly those with `partnerKind == realFriend`.
    if (session.partnerKind != PairedPartnerKind.realFriend) {
      if (_isReady) return _LobbyState.selfWaitingForPartner;
      return viewerType == WorkoutType.gym
          ? _LobbyState.hostBuildingPlan
          : _LobbyState.hostNonGymConfirm;
    }

    if (isHost) {
      if (_isReady) return _LobbyState.hostWaitingForBuddy;
      // Host prepares WHILE the friend decides (invite-first, build-after).
      // The editor / confirm is always available; only the ready button is gated
      // via _readyEnabled(session).
      return hostType == WorkoutType.gym
          ? _LobbyState.hostBuildingPlan
          : _LobbyState.hostNonGymConfirm;
    }

    // Friend — a pending invitee (not yet in participants) stays on the
    // category chooser with a Join button until joinSetup adds them to the
    // roster.
    final joined = session.participants.contains(uid);
    if (!joined) return _LobbyState.friendChoosingCategory;
    final myType =
        WorkoutType.fromString(session.participantTypes[uid] ?? session.type);
    if (_isReady) return _LobbyState.selfWaitingForPartner;
    final sameAsHost = myType == hostType;
    if (sameAsHost && myType == WorkoutType.gym) {
      final hostPlan = ref
          .watch(gymSessionPlanProvider((
            sessionId: session.id,
            userId: session.hostId,
          )))
          .valueOrNull;
      if (hostPlan == null || !hostPlan.isReady) {
        return _LobbyState.friendWaitingForHostPlan;
      }
      return _LobbyState.friendReviewPlan;
    }
    if (myType == WorkoutType.gym) return _LobbyState.hostBuildingPlan; // friend builds own
    return _LobbyState.friendConfirm;
  }

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
    final session = await ref.read(
      currentSessionProvider(widget.sessionId).future,
    );
    if (!mounted || authUser == null || session == null) {
      if (mounted) setState(() => _isLoadingPlan = false);
      return;
    }
    // Pending invitee (not yet a participant): no joinSession / ensureGymPlan /
    // presence / event / plan-doc writes until joinSetup runs from the lobby.
    if (!session.participants.contains(authUser.id)) {
      if (mounted) setState(() => _isLoadingPlan = false);
      return;
    }
    final plan = await ref.read(sessionServiceProvider).ensureGymPlan(
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
          : GymSessionPlanSource.personalCopy,
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

  /// Non-gym / parallel ready path — writes a stub plan (no exercises required)
  /// and flips readiness. Does NOT route through _markReady which requires
  /// _isPlanValid (≥1 exercise).
  Future<void> _confirmReadyNoPlan(Session session) async {
    if (_isSavingReady) return;
    final authUser = ref.read(authSessionProvider).valueOrNull;
    if (authUser == null) return;
    setState(() => _isSavingReady = true);
    final svc = ref.read(sessionServiceProvider);
    final myType = WorkoutType.fromString(
      session.participantTypes[authUser.id] ?? session.type,
    );
    try {
      await svc.saveGymPlan(
        sessionId: widget.sessionId,
        plan: GymSessionPlan.defaultPersonalPlan(
          userId: authUser.id,
          workoutType: myType,
        ), // ready stub, no exercises required for non-gym/parallel
      );
      await svc.setGymPlanReady(
        sessionId: widget.sessionId,
        userId: authUser.id,
        isReady: true,
      );
      if (mounted) {
        setState(() {
          _isReady = true;
          _isSavingReady = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingReady = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unable to confirm: $error'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // Pending invitee: pick category locally; nothing is written until Join.
  void _onFriendPickCategory(WorkoutType type) {
    setState(() => _friendChosenType = type);
  }

  // Join button (pending invitee only): joins setup with the chosen category.
  Future<void> _onJoinSetup(Session session) async {
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    final type = _friendChosenType ?? WorkoutType.fromString(session.type);
    if (uid == null) return;
    try {
      final svc = ref.read(sessionServiceProvider);
      await svc.joinSetup(
        sessionId: session.id,
        userId: uid,
        chosenWorkoutType: type.value,
      );
      // The pending invitee did NOT run _loadInitialPlan (it early-returns for
      // non-participants), and it won't re-run on this pending→joined rebuild.
      // Load the freshly-seeded plan now so the Edit path / readiness reflect
      // the stub instead of opening an empty editor.
      final plan = await svc.ensureGymPlan(
        sessionId: session.id,
        hostId: session.hostId,
        userId: uid,
      );
      if (mounted) {
        setState(() {
          _draftExercises = _reindexExercises(plan.exercises);
          _isReady = plan.isReady; // false — joinSetup wrote a not-ready stub
          _isLoadingPlan = false;
        });
      }
      // The stream rebuild also moves us out of the pending "choose category"
      // state automatically (we are now in participants).
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not join: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _onAgreeHostPlan(Session session) async {
    final hostPlan = ref.read(gymSessionPlanProvider(
      (sessionId: session.id, userId: session.hostId),
    )).valueOrNull;
    if (hostPlan == null) return;
    setState(() => _draftExercises = _reindexExercises(hostPlan.exercises));
    await _markReady(session); // writes own copy + setGymPlanReady
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
    ref.listen<AsyncValue<Session?>>(currentSessionProvider(widget.sessionId), (
      previous,
      next,
    ) {
      final session = next.valueOrNull;
      if (!mounted || _didRedirect) return;
      if (session == null || session.phase != SessionPhase.live) return;

      _didRedirect = true;
      final authUser = ref.read(authSessionProvider).valueOrNull;
      final myType =
          authUser != null
              ? (session.participantTypes[authUser.id] ?? session.type)
              : session.type;
      // context.go: entering live session — replace setup in stack so back doesn't return here
      context.go(AppRouteLocations.sessionRoom(session.id, type: myType));
    });

    final sessionAsync = ref.watch(currentSessionProvider(widget.sessionId));

    // Resolve session and uid for optional cancel AppBar.
    final session = sessionAsync.valueOrNull;
    final authUser = ref.watch(authSessionProvider).valueOrNull;
    final lobbyState =
        session != null && authUser != null
            ? _resolveState(session, authUser.id)
            : null;
    final showCancel =
        session != null &&
        authUser != null &&
        lobbyState != null &&
        _showCancelButton(lobbyState, session, authUser.id);

    // Non-null when showCancel is true (checked above).
    final cancelSession = session;
    final cancelUid = authUser?.id;
    final isHost = cancelSession?.hostId == cancelUid;

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      appBar: showCancel && cancelSession != null && cancelUid != null
          ? AppBar(
              backgroundColor: AppColors.backgroundV2,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: isHost ? 'Cancel setup' : 'Leave',
                onPressed: () => _onCancelSetup(cancelSession, cancelUid),
              ),
              title: Text(
                isHost ? 'Cancel setup' : 'Leave',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Secondary,
                ),
              ),
            )
          : null,
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

                final authUser = ref.watch(authSessionProvider).valueOrNull;
                if (authUser == null) return _buildLoadingShell();

                final lobbyState = _resolveState(session, authUser.id);
                return _buildLobbyShell(session, authUser.id, lobbyState);
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cancel / leave button for FRIEND-INVITE sessions.
  // ---------------------------------------------------------------------------

  /// Returns true for states where a cancel/leave affordance should appear
  /// (host: host-owned states; joined-friend: joined states). Does NOT apply
  /// to terminal states or the pending-invitee `friendChoosingCategory` state
  /// (which already has Decline handled by declineInvite).
  bool _showCancelButton(_LobbyState lobbyState, Session session, String uid) {
    if (session.partnerKind != PairedPartnerKind.realFriend) return false;
    const hostStates = {
      _LobbyState.hostBuildingPlan,
      _LobbyState.hostNonGymConfirm,
      _LobbyState.hostWaitingForBuddy,
    };
    const joinedFriendStates = {
      _LobbyState.friendWaitingForHostPlan,
      _LobbyState.friendReviewPlan,
      _LobbyState.friendConfirm,
      _LobbyState.selfWaitingForPartner,
    };
    final isHost = session.hostId == uid;
    if (isHost) return hostStates.contains(lobbyState);
    return joinedFriendStates.contains(lobbyState);
  }

  Future<void> _onCancelSetup(Session session, String uid) async {
    final isHost = session.hostId == uid;
    final reason = isHost ? 'setup_host_cancelled' : 'setup_partner_left';
    try {
      await ref.read(sessionServiceProvider).cancelSetup(
        sessionId: session.id,
        byUserId: uid,
        reason: reason,
      );
      if (mounted) {
        context.go(AppRouteLocations.mainTab(MainShellTab.session));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel setup: $error')),
        );
      }
    }
  }

  Widget _buildLobbyShell(Session session, String uid, _LobbyState lobbyState) {
    switch (lobbyState) {
      case _LobbyState.terminalCancelled:
        return _buildTerminalPanel(
          message: 'This setup was cancelled',
        );
      case _LobbyState.terminalDeclined:
        return _buildTerminalPanel(
          message: 'Your buddy declined',
        );
      case _LobbyState.hostWaitingForBuddy:
        return _buildWaitingView(
          title: 'Waiting for your buddy to agree',
        );
      case _LobbyState.friendWaitingForHostPlan:
        return _buildWaitingView(
          title: 'Waiting for the host to finish the plan',
        );
      case _LobbyState.selfWaitingForPartner:
        return _buildWaitingView(
          title: 'Waiting for your buddy',
        );
      case _LobbyState.friendChoosingCategory:
        return _buildFriendChoosingCategoryShell(session, uid);
      case _LobbyState.hostBuildingPlan:
      case _LobbyState.friendReviewPlan:
        return _buildSetupShell(session, uid, lobbyState);
      case _LobbyState.hostNonGymConfirm:
      case _LobbyState.friendConfirm:
        return _buildNonGymConfirmShell(session, uid, lobbyState);
    }
  }

  Widget _buildSetupShell(Session session, String uid, _LobbyState lobbyState) {
    final isInvitedSameGymCopy =
        uid != session.hostId &&
        session.partnerKind == PairedPartnerKind.realFriend &&
        session.participantTypes[session.hostId] == WorkoutType.gym.value &&
        session.participantTypes[uid] == WorkoutType.gym.value;

    final readyEnabled = _readyEnabled(session);

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.userAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              color: AppColors.userAccent,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Gym Session Setup',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textV2Primary,
              letterSpacing: -0.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            _isReady
                ? 'Your plan is locked in. We will jump to the live room once everyone is ready.'
                : 'Prepare your plan before jumping into the live room.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textV2Secondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            session.title,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textV2Primary,
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
            if (!readyEnabled)
              Text(
                'Waiting for your buddy to join',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.textV2Secondary,
                ),
                textAlign: TextAlign.center,
              )
            else
              Text(
                _isReady
                    ? 'Waiting for the rest of the group to finish setup.'
                    : isInvitedSameGymCopy
                    ? 'Review the host gym plan, then adjust only your personal copy.'
                    : 'Each athlete can personalize their own copy of this plan before the room starts.',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.textV2Secondary,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            if (lobbyState == _LobbyState.friendReviewPlan && !_isReady) ...[
              FilledButton(
                onPressed: _isSavingReady ? null : () => _onAgreeHostPlan(session),
                child: _isSavingReady
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.backgroundV2,
                        ),
                      )
                    : const Text('Agree'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isSavingReady || !_isPlanValid
                    ? null
                    : () => _markReady(session),
                child: const Text('Edit & Ready'),
              ),
            ] else
              FilledButton(
                onPressed: _isReady || !_isPlanValid || _isSavingReady || !readyEnabled
                    ? null
                    : () => _markReady(session),
                child: _isSavingReady
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.backgroundV2,
                        ),
                      )
                    : Text(_isReady ? 'Ready — Locked in' : "I'm ready"),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildNonGymConfirmShell(
      Session session, String uid, _LobbyState lobbyState) {
    final isHost = uid == session.hostId;
    final readyEnabled = _readyEnabled(session);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.userAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.directions_run_rounded,
            color: AppColors.userAccent,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          session.title,
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textV2Primary,
            letterSpacing: -0.8,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (!readyEnabled)
          Text(
            'Waiting for your buddy to join',
            style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isSavingReady || (isHost && !readyEnabled)
              ? null
              : () => _confirmReadyNoPlan(session),
          child: _isSavingReady
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.backgroundV2,
                  ),
                )
              : const Text("Ready to start?"),
        ),
      ],
    );
  }

  Widget _buildFriendChoosingCategoryShell(Session session, String uid) {
    final hostType = WorkoutType.fromString(session.type);
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your workout type',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textV2Primary,
              letterSpacing: -0.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a category to join the session.',
            style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LobbyCategoryGrid(
            hostType: hostType,
            selected: _friendChosenType,
            onSelect: _onFriendPickCategory,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _friendChosenType == null ? null : () => _onJoinSetup(session),
            child: const Text('Join'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              try {
                await ref.read(sessionServiceProvider).declineInvite(
                  sessionId: session.id,
                  userId: uid,
                );
                if (mounted) {
                  context.go(AppRouteLocations.mainTab(MainShellTab.session));
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not decline: $error')),
                  );
                }
              }
            },
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView({required String title}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textV2Primary,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTerminalPanel({required String message}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.error,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textV2Primary,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () =>
              context.go(AppRouteLocations.mainTab(MainShellTab.session)),
          child: const Text('Back to Train'),
        ),
      ],
    );
  }

  Widget _buildLoadingShell() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.userAccent,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Preparing your gym session',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textV2Primary,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Loading the setup details now.',
          style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
          textAlign: TextAlign.center,
        ),
      ],
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
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textV2Primary,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: AppTextStyles.body.copyWith(color: AppColors.textV2Secondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../../core/constants/feature_flags.dart';
import '../../auth/auth_providers.dart';
import '../../../services/session_service.dart';
import '../../../services/follow_service.dart';
import '../../../core/models/models.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/pulse_dot.dart';
import '../../../utils/haptic_manager.dart';
import '../../../utils/offline_manager.dart';
import '../domain/gym_session_plan.dart';
import 'widgets/gym_exercise_picker_sheet.dart';

/// Signals the train screen to reset to its home view.
/// Increment this value whenever the session FAB is tapped.
final sessionViewResetProvider = StateProvider<int>((ref) => 0);

/// True when the centre FAB should render as an active Start button.
final sessionFabActiveProvider = StateProvider<bool>((ref) => false);

/// True while the session creation is in flight (spinner in FAB).
final sessionFabLoadingProvider = StateProvider<bool>((ref) => false);

/// Shell increments this to fire the Start action from the FAB.
final sessionStartTriggerProvider = StateProvider<int>((ref) => 0);

/// Train screen — workout type + partner selection + session start.
class StartSessionPage extends ConsumerStatefulWidget {
  const StartSessionPage({super.key});

  @override
  ConsumerState<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends ConsumerState<StartSessionPage> {
  WorkoutType? _selectedType; // null = nothing chosen yet
  // partner mode: 'solo' | 'bot' | 'friends' | 'random'
  String _partnerMode = 'solo';
  final Set<String> _selectedFriends = {};
  bool _isLoading = false;
  bool _isLoadingFollows = true;
  List<User> _mutualFollows = [];
  // views: 'home' | 'plan'
  String _view = 'home';
  late List<PlannedExercise> _plan;
  bool _hasShownWorkoutsPopup = false;

  // Live friends strip
  List<Map<String, dynamic>> _liveFriends = [];

  // Stats for Train home screen
  int _weekSessions = 0;
  static const int _weekTarget = 5;
  int _streakDays = 0;
  List<Session> _recentSessions = [];

  static const _prefKeyType = 'last_workout_type';

  @override
  void initState() {
    super.initState();
    _plan = [];
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMutualFollows();
      _loadStats();
      _loadLiveFriends();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedType = prefs.getString(_prefKeyType);
    if (savedType != null && mounted) {
      setState(() => _selectedType = WorkoutType.fromString(savedType));
    }
  }

  Future<void> _savePreferences() async {
    if (_selectedType == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyType, _selectedType!.value);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadStats() async {
    final uid = await _readCurrentUserId();
    if (uid == null) {
      return;
    }
    try {
      final service = ref.read(sessionServiceProvider);
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );

      final allSessions = await service.getUserSessions(uid, limit: 20);
      final weekCount = allSessions
          .where((s) => s.createdAt.isAfter(weekStartDate))
          .length;

      if (mounted) {
        setState(() {
          _weekSessions = weekCount;
          _recentSessions = allSessions.take(3).toList();
          _streakDays = weekCount; // approximate from this-week count
        });
      }
    } catch (_) {
      // Keep the home stats fallback values when history loading fails.
    }
  }

  Future<String?> _readCurrentUserId() async {
    final current = ref.read(authSessionProvider).value?.id;
    if (current != null) return current;
    try {
      return (await ref.read(authSessionProvider.future))?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadMutualFollows() async {
    setState(() => _isLoadingFollows = true);
    final uid = await _readCurrentUserId();
    if (uid == null) {
      if (mounted) setState(() => _isLoadingFollows = false);
      return;
    }

    try {
      final follows = await ref
          .read(followServiceProvider)
          .getMutualFollows(uid);
      if (mounted) {
        setState(() => _mutualFollows = follows);
      }
    } catch (e) {
      debugPrint('Error loading follows: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFollows = false);
      }
    }
  }

  /// Best-effort: checks which mutual follows currently have an active session.
  /// Fails silently — the strip simply stays hidden if this errors or returns empty.
  Future<void> _loadLiveFriends() async {
    try {
      final uid = await _readCurrentUserId();
      if (uid == null) return;

      final follows = await ref
          .read(followServiceProvider)
          .getMutualFollows(uid);
      if (follows.isEmpty) return;

      final sessionService = ref.read(sessionServiceProvider);
      final liveUsers = <Map<String, dynamic>>[];

      for (final user in follows) {
        try {
          final activeId = await sessionService.checkActiveSession(user.id);
          if (activeId != null) {
            liveUsers.add({
              'name': user.displayName,
              'photoURL': user.photoURL,
            });
          }
        } catch (_) {
          // Skip this user silently
        }
      }

      if (mounted && liveUsers.isNotEmpty) {
        setState(() => _liveFriends = liveUsers);
      }
    } catch (_) {
      // Best-effort: fail silently
    }
  }

  Future<void> _handleStartSession() async {
    await _startSelectedSession(includeEmptyPlanExtra: false);
  }

  Future<void> _startSelectedSession({
    required bool includeEmptyPlanExtra,
  }) async {
    final type = _selectedType;
    if (type == null) return;
    setState(() => _isLoading = true);

    try {
      final uid = await _readCurrentUserId();
      if (uid == null) throw Exception('Not authenticated');

      final sessionService = ref.read(sessionServiceProvider);
      final existingSessionId = await sessionService.checkActiveSession(uid);
      if (existingSessionId != null) {
        final shouldCreateNew = await _resolveActiveSessionConflict(
          sessionService: sessionService,
          uid: uid,
          type: type,
          existingSessionId: existingSessionId,
        );
        if (!shouldCreateNew) return;
      }

      final plannedExercises = _currentPlannedExercises();
      final gymPlan = _buildHostGymPlan(
        uid: uid,
        type: type,
        plannedExercises: plannedExercises,
      );
      final sessionId = await _createSelectedSession(
        sessionService: sessionService,
        uid: uid,
        type: type,
        gymPlan: gymPlan,
      );
      await _saveGymPlanBestEffort(
        sessionService: sessionService,
        sessionId: sessionId,
        gymPlan: gymPlan,
        plannedExercises: plannedExercises,
      );

      await HapticFeedback.mediumImpact();
      _openCreatedSession(
        sessionId: sessionId,
        type: type,
        plannedExercises: plannedExercises,
        includeEmptyPlanExtra: includeEmptyPlanExtra,
      );
    } catch (e) {
      debugPrint('[StartSessionPage] Failed to start session: $e');
      if (mounted) {
        _showError(_mapStartSessionError(e));
        await HapticFeedback.vibrate();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _resolveActiveSessionConflict({
    required SessionService sessionService,
    required String uid,
    required WorkoutType type,
    required String existingSessionId,
  }) async {
    if (!mounted) return false;
    setState(() => _isLoading = false);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceV2Elevated,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Active Session Found',
              style: AppTextStyles.h4.copyWith(color: AppColors.textV2Primary),
            ),
            const SizedBox(height: 8),
            Text(
              'You already have a workout in progress. Resume it or end it to start a new one.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textV2Secondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ZyntroButton(
              title: 'Resume Active Session',
              variant: ZyntroButtonVariant.primary,
              fullWidth: true,
              onPressed: () => Navigator.pop(ctx, 'resume'),
            ),
            const SizedBox(height: 8),
            ZyntroButton(
              title: 'End Old & Start New',
              variant: ZyntroButtonVariant.destructive,
              fullWidth: true,
              onPressed: () => Navigator.pop(ctx, 'end'),
            ),
            const SizedBox(height: 8),
            ZyntroButton(
              title: 'Cancel',
              variant: ZyntroButtonVariant.ghost,
              fullWidth: true,
              onPressed: () => Navigator.pop(ctx, 'cancel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return false;

    if (action == 'resume') {
      context.push(
        AppRouteLocations.sessionRoom(existingSessionId, type: type.value),
      );
      return false;
    }
    if (action == 'end') {
      setState(() => _isLoading = true);
      await sessionService.endSession(existingSessionId, uid, null);
      return true;
    }
    return false;
  }

  List<PlannedExercise> _currentPlannedExercises() {
    // Re-stamp order to match current list position; preserve catalog/custom identity (T025).
    return _plan
        .asMap()
        .entries
        .map((entry) => entry.value.copyWithPlanFields(order: entry.key))
        .toList();
  }

  GymSessionPlan _buildHostGymPlan({
    required String uid,
    required WorkoutType type,
    required List<PlannedExercise> plannedExercises,
  }) {
    return GymSessionPlan(
      userId: uid,
      workoutType: type,
      source: GymSessionPlanSource.hostTemplate,
      isReady: true,
      exercises: plannedExercises,
      updatedAt: DateTime.now(),
    );
  }

  Future<String> _createSelectedSession({
    required SessionService sessionService,
    required String uid,
    required WorkoutType type,
    required GymSessionPlan gymPlan,
  }) {
    if (_partnerMode == 'bot') {
      return sessionService.createBotPairedSession(
        hostId: uid,
        type: type.value,
        title: '${type.displayName} Session',
        plan: gymPlan,
      );
    }

    final invitedIds = _partnerMode == 'friends' && _selectedFriends.isNotEmpty
        ? _selectedFriends.toList()
        : null;
    return sessionService.createSession(
      hostId: uid,
      type: type.value,
      title: '${type.displayName} Session',
      invitedUserIds: invitedIds,
      phase: SessionPhase.live,
    );
  }

  Future<void> _saveGymPlanBestEffort({
    required SessionService sessionService,
    required String sessionId,
    required GymSessionPlan gymPlan,
    required List<PlannedExercise> plannedExercises,
  }) async {
    if (_partnerMode == 'bot' || plannedExercises.isEmpty) return;

    try {
      await sessionService.saveGymPlan(sessionId: sessionId, plan: gymPlan);
    } catch (e) {
      debugPrint('[StartSessionPage] saveGymPlan failed (non-fatal): $e');
    }
  }

  void _openCreatedSession({
    required String sessionId,
    required WorkoutType type,
    required List<PlannedExercise> plannedExercises,
    required bool includeEmptyPlanExtra,
  }) {
    if (!mounted) return;
    context.push(
      AppRouteLocations.sessionRoom(sessionId, type: type.value),
      extra: includeEmptyPlanExtra || plannedExercises.isNotEmpty
          ? {'plannedExercises': plannedExercises}
          : null,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorV2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _mapStartSessionError(Object error) {
    final normalizedError = error.toString().toLowerCase();

    if (normalizedError.contains('permission-denied') ||
        normalizedError.contains('insufficient permissions') ||
        normalizedError.contains('app attestation failed') ||
        normalizedError.contains('app check') ||
        normalizedError.contains('appcheck')) {
      return 'Firebase blocked session creation for this build. Check Firestore permissions or App Check allowlisting.';
    }

    if (normalizedError.contains('network') ||
        normalizedError.contains('connection')) {
      return 'Check your internet connection and try again.';
    }

    if (normalizedError.contains('not eligible')) {
      return 'You can only invite one mutual friend who has not blocked you.';
    }

    if (normalizedError.contains('exactly one invited friend')) {
      return 'Choose one friend for a paired session.';
    }

    if (normalizedError.contains('expired')) {
      return 'That invite expired. Send a new one to train together.';
    }

    if (normalizedError.contains('delivery')) {
      return 'Invite delivery failed. Try again in a moment.';
    }

    return 'Failed to start session. Please try again.';
  }

  IconData _getIconData(String iconName) {
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

  @override
  Widget build(BuildContext context) {
    // Reset to home view when the session FAB is tapped from another tab.
    ref.listen<int>(sessionViewResetProvider, (_, _) {
      if (_view != 'home') setState(() => _view = 'home');
    });

    // Fire start action when the shell FAB is tapped while on this tab.
    ref.listen<int>(sessionStartTriggerProvider, (_, _) {
      if (_isLoading) return;
      final isFriendInvite =
          _partnerMode == 'friends' && _selectedFriends.isNotEmpty;
      if (_view == 'plan') {
        HapticManager.heavy();
        _handleStartSessionWithPlan();
      } else if (isFriendInvite && _selectedType != null) {
        HapticManager.medium();
        _handleStartFriendInvite(_selectedType!);
      } else if (_selectedType != null) {
        HapticManager.medium();
        if (_selectedType == WorkoutType.gym) {
          _navigateToPlanView();
        } else {
          _handleStartSession();
        }
      }
    });

    // Sync FAB state to shell providers after every build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final active = _selectedType != null && !_isLoading;
      if (ref.read(sessionFabActiveProvider) != active) {
        ref.read(sessionFabActiveProvider.notifier).state = active;
      }
      if (ref.read(sessionFabLoadingProvider) != _isLoading) {
        ref.read(sessionFabLoadingProvider.notifier).state = _isLoading;
      }
    });
    // Force solo mode when connectivity drops.
    ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      final isOnline = next.value ?? true;
      if (!isOnline && _partnerMode != 'solo') {
        setState(() {
          _partnerMode = 'solo';
          _selectedFriends.clear();
        });
      }
    });
    if (_view == 'plan') {
      if (!_hasShownWorkoutsPopup) {
        _hasShownWorkoutsPopup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _view == 'plan') _showPastWorkoutsPopup();
        });
      }
      return _buildPlanView();
    }
    return _buildHomeView();
  }

  Future<void> _handleStartFriendInvite(WorkoutType type) async {
    final uid = await _readCurrentUserId();
    if (uid == null || _selectedFriends.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final sessionService = ref.read(sessionServiceProvider);
      final existing = await sessionService.checkActiveSession(uid);
      if (existing != null) {
        // Offer resume / end-and-start-new, same as the solo path. Without this
        // the tap silently did nothing when a stale active session existed.
        final proceed = await _resolveActiveSessionConflict(
          sessionService: sessionService,
          uid: uid,
          type: type,
          existingSessionId: existing,
        );
        if (!proceed) return;
      }
      final sessionId = await sessionService.createSession(
        hostId: uid,
        type: type.value,
        title: '${type.displayName} Session',
        invitedUserIds: _selectedFriends.toList(),
        phase: SessionPhase.setup,
      );
      await HapticFeedback.mediumImpact();
      if (mounted) context.push(AppRouteLocations.gymSessionSetup(sessionId));
    } catch (e) {
      if (mounted) {
        _showError(_mapStartSessionError(e));
        await HapticFeedback.vibrate();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToPlanView() {
    setState(() {
      _view = 'plan';
      _plan = [];
      _hasShownWorkoutsPopup = false;
    });
  }

  Color _getTypeColor(WorkoutType type) {
    switch (type.value) {
      case 'gym':
        return const Color(0xFFC8FF00);
      case 'running':
        return const Color(0xFF38BDF8);
      case 'cycling':
        return const Color(0xFFA78BFA);
      case 'swimming':
        return const Color(0xFF22D3EE);
      case 'yoga':
        return const Color(0xFF34D399);
      case 'hiit':
        return const Color(0xFFFF8C00);
      default:
        return const Color(0xFF888888);
    }
  }

  Widget _buildAvatarPlaceholder(User user) {
    return Container(
      color: AppColors.surfaceV2,
      child: Center(
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  // ─── Live friends strip ─────────────────────────────────────────────────────

  Widget _buildLiveStrip() {
    if (_liveFriends.isEmpty) return const SizedBox.shrink();
    final names = _liveFriends
        .take(2)
        .map((u) => (u['name'] as String).split(' ').first)
        .join(', ');
    final extra = _liveFriends.length > 2 ? ' +${_liveFriends.length - 2}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceV2Active),
      ),
      child: Row(
        children: [
          // Stacked avatars
          SizedBox(
            width: (_liveFriends.length.clamp(1, 3) * 20.0) + 12,
            height: 28,
            child: Stack(
              children: [
                for (int i = 0; i < _liveFriends.length.clamp(0, 3); i++)
                  Positioned(
                    left: i * 20.0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.backgroundV2,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: _liveFriends[i]['photoURL'] != null
                            ? CachedNetworkImage(
                                imageUrl: _liveFriends[i]['photoURL'] as String,
                                fit: BoxFit.cover,
                                errorWidget: (_, url, e) => _avatarFallback(
                                  _liveFriends[i]['name'] as String,
                                ),
                              )
                            : _avatarFallback(
                                _liveFriends[i]['name'] as String,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$names$extra ${_liveFriends.length == 1 ? 'is' : 'are'} training now',
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                color: AppColors.textV2Secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          PulseDot(color: const Color(0xFFFF4D4D), size: 6),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF4D4D),
              letterSpacing: 0.08,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: AppColors.surfaceV2Elevated,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.textV2Primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ─── Home (Train) view ──────────────────────────────────────────────────────

  Widget _buildHomeView() {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Train',
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 34,
                        color: AppColors.textV2Primary,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildWeekCard(),
                    const SizedBox(height: 20),
                    _buildLiveStrip(),
                    const SizedBox(height: 8),
                    _buildSectionLabel('WORKOUT TYPE'),
                    const SizedBox(height: 12),
                    _buildTypeSelectionGrid(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('TRAIN WITH'),
                    const SizedBox(height: 12),
                    _buildPartnerModeRow(),
                    if (!(ref.watch(connectivityProvider).value ?? true))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "You're offline — solo sessions only",
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _buildBuddiesStrip(
                      isOffline:
                          !(ref.watch(connectivityProvider).value ?? true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelectionGrid() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.05,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _quickStartTypes
          .map((item) => _buildTypeCard(item.type, item.label))
          .toList(),
    );
  }

  Widget _buildTypeCard(WorkoutType type, String label) {
    final isSelected = _selectedType == type;
    final typeColor = _getTypeColor(type);
    final icon = _getIconData(type.icon);

    return GestureDetector(
      onTap: () {
        HapticManager.selection();
        setState(() => _selectedType = _selectedType == type ? null : type);
        _savePreferences();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: AppCurves.press,
        decoration: BoxDecoration(
          color: isSelected
              ? typeColor.withValues(alpha: 0.15)
              : AppColors.surfaceV2.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? typeColor : AppColors.surfaceV2Active,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Diagonal shimmer accent
              Positioned(
                top: -20,
                right: -10,
                child: Transform.rotate(
                  angle: 0.6,
                  child: Container(
                    width: 40,
                    height: 120,
                    color: typeColor.withValues(alpha: 0.04),
                  ),
                ),
              ),
              // Left accent bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: typeColor),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: typeColor, size: 18),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label.toUpperCase(),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: typeColor,
                                letterSpacing: 0.08,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        color: AppColors.textV2Primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerModeRow() {
    final pairedSessionsEnabled = ref.watch(
      pairedFriendSessionsEnabledProvider,
    );
    final isOffline = !(ref.watch(connectivityProvider).value ?? true);
    final modes = [
      (id: 'solo', label: 'Solo', icon: Icons.person_outline_rounded),
      if (pairedSessionsEnabled) ...[
        (id: 'bot', label: 'Bot', icon: Icons.smart_toy_outlined),
        (id: 'friends', label: 'Friend', icon: Icons.person_add_alt_1),
      ],
    ];
    return Row(
      children: modes.map((m) {
        final isActive = _partnerMode == m.id;
        final isDisabled = isOffline && m.id != 'solo';
        return Expanded(
          child: GestureDetector(
            onTap: isDisabled
                ? null
                : () {
                    HapticManager.light();
                    setState(() {
                      _partnerMode = m.id;
                      if (m.id != 'friends') _selectedFriends.clear();
                    });
                    if (m.id == 'friends') {
                      _loadMutualFollows();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(right: m.id == modes.last.id ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDisabled
                    ? AppColors.surfaceV2.withValues(alpha: 0.4)
                    : isActive
                    ? AppColors.surfaceV2Elevated
                    : AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDisabled
                      ? AppColors.surfaceV2Active.withValues(alpha: 0.3)
                      : isActive
                      ? AppColors.userAccent.withValues(alpha: 0.4)
                      : AppColors.surfaceV2Active,
                  width: 1.5,
                ),
              ),
              child: Opacity(
                opacity: isDisabled ? 0.4 : 1.0,
                child: Column(
                  children: [
                    Icon(
                      m.icon,
                      size: 20,
                      color: isActive
                          ? AppColors.userAccent
                          : AppColors.textV2Tertiary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppColors.textV2Primary
                            : AppColors.textV2Tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Always-visible horizontal strip of the user's buddies (mutual follows).
  /// Tapping a buddy selects them and switches the partner mode to "Friend".
  Widget _buildBuddiesStrip({bool isOffline = false}) {
    if (_isLoadingFollows && _mutualFollows.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_mutualFollows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        _buildSectionLabel('YOUR BUDDIES'),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _mutualFollows.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final u = _mutualFollows[i];
              final selected = _selectedFriends.contains(u.id);
              final firstName = u.displayName.trim().split(' ').first;
              return GestureDetector(
                onTap: isOffline
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_selectedFriends.contains(u.id)) {
                            _selectedFriends.clear();
                            _partnerMode = 'solo';
                          } else {
                            _selectedFriends
                              ..clear()
                              ..add(u.id);
                            _partnerMode = 'friends';
                          }
                        });
                      },
                child: SizedBox(
                  width: 64,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.userAccent
                                : AppColors.surfaceV2Active,
                            width: selected ? 2.5 : 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: (u.photoURL != null && u.photoURL!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: u.photoURL!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      _buildAvatarPlaceholder(u),
                                )
                              : _buildAvatarPlaceholder(u),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.userAccent
                              : AppColors.textV2Secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_selectedFriends.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${_selectedFriends.length} friend selected',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.userAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeekCard() {
    final progress = _weekTarget == 0
        ? 0.0
        : (_weekSessions / _weekTarget).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _RingPainter(progress: progress.toDouble()),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_weekSessions',
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 28,
                        color: AppColors.userAccent,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'of $_weekTarget',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textV2Tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIS WEEK',
                  style: TextStyle(
                    color: AppColors.textV2Tertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_weekSessions session${_weekSessions == 1 ? '' : 's'}',
                  style: AppTextStyles.h4.copyWith(
                    fontSize: 22,
                    color: AppColors.textV2Primary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '$_streakDays',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 15,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'streak',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                    const SizedBox(width: 25),
                    // Text(
                    //   'total',
                    //   style: TextStyle(
                    //     fontSize: 11,
                    //     color: AppColors.textV2Tertiary,
                    //   ),
                    // ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textV2Tertiary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }

  static const _quickStartTypes = [
    (type: WorkoutType.gym, label: 'Strength'),
    (type: WorkoutType.running, label: 'Cardio'),
    (type: WorkoutType.hiit, label: 'HIIT'),
    (type: WorkoutType.cycling, label: 'Cycling'),
    (type: WorkoutType.yoga, label: 'Yoga'),
    (type: WorkoutType.swimming, label: 'Swim'),
  ];

  Future<void> _showPastWorkoutsPopup() async {
    // Gather gym sessions that have at least one exercise in the summary.
    final gymSessions = _recentSessions
        .where(
          (s) =>
              s.type == 'gym' &&
              s.summary != null &&
              (s.summary!.exercises?.isNotEmpty ?? false),
        )
        .toList();

    if (gymSessions.isEmpty || !mounted) return;

    final selected = await showModalBottomSheet<Session>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PastWorkoutsSheet(sessions: gymSessions),
    );

    if (selected != null && mounted) {
      _loadPlanFromSession(selected);
    }
  }

  void _loadPlanFromSession(Session session) {
    const uuid = Uuid();
    final exercises = session.summary?.exercises ?? [];
    final loaded = exercises.asMap().entries.map((entry) {
      final ex = entry.value;
      return PlannedExercise.custom(
        id: uuid.v4(),
        name: ex.name,
        plannedSets: ex.sets > 0 ? ex.sets.clamp(1, 20) : 3,
        order: entry.key,
      );
    }).toList();
    setState(() => _plan = loaded);
  }

  Widget _buildPlanView() {
    const bg = AppColors.backgroundV2;
    const s1 = AppColors.surfaceV2;
    const t1 = AppColors.textV2Primary;
    const t2 = AppColors.textV2Secondary;
    final totalSets = _plan.fold<int>(0, (sum, e) => sum + e.plannedSets);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _view = 'home'),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceV2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: t2,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Plan Session',
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 22,
                        color: t1,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    '$totalSets sets total',
                    style: AppTextStyles.caption.copyWith(color: t2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Exercise list
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _plan.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = _plan.removeAt(oldIndex);
                    _plan.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final item = _plan[index];
                  return _ExercisePlanRow(
                    key: ValueKey(item.id),
                    item: item,
                    index: index,
                    onDelete: () => setState(() => _plan.removeAt(index)),
                    onSetsChanged: (sets) => setState(() {
                      // PlannedExercise is immutable — replace entry (T024).
                      _plan[index] =
                          _plan[index].copyWithPlanFields(plannedSets: sets);
                    }),
                  );
                },
              ),
            ),
            // Add exercise button (T019 — replaces inline free-text field)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: _openExercisePicker,
                child: Container(
                  decoration: BoxDecoration(
                    color: s1,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: AppColors.userAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Add exercise',
                        style: AppTextStyles.body.copyWith(color: t1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Begin session button
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (_plan.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Add at least one exercise to start',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textV2Tertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ZyntroButton(
                      title: _plan.isEmpty
                          ? 'Begin Session ($totalSets sets)'
                          : 'Begin Session ($totalSets sets)',
                      fullWidth: true,
                      size: ZyntroButtonSize.lg,
                      variant: ZyntroButtonVariant.primary,
                      loading: _isLoading,
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticManager.heavy();
                              _handleStartSessionWithPlan();
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExercisePicker() async {
    final uid = await _readCurrentUserId();
    if (!mounted) return;

    final selected = await showModalBottomSheet<List<PlannedExercise>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) =>
            GymExercisePickerSheet(userId: uid),
      ),
    );

    if (!mounted || selected == null || selected.isEmpty) return;
    setState(() {
      final baseOrder = _plan.length;
      for (var i = 0; i < selected.length; i++) {
        // Rebuild with correct order index; preserve catalog/custom source (T025).
        _plan.add(selected[i].copyWithPlanFields(order: baseOrder + i));
      }
    });
    HapticManager.light();
  }

  Future<void> _handleStartSessionWithPlan() async {
    await _startSelectedSession(includeEmptyPlanExtra: true);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textV2Tertiary,
        letterSpacing: 2,
      ),
    );
  }
}

class _ExercisePlanRow extends StatelessWidget {
  final PlannedExercise item;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<int> onSetsChanged;

  const _ExercisePlanRow({
    required super.key,
    required this.item,
    required this.index,
    required this.onDelete,
    required this.onSetsChanged,
  });

  @override
  Widget build(BuildContext context) {
    const t1 = AppColors.textV2Primary;
    const t3 = AppColors.textV2Tertiary;
    const s1 = AppColors.surfaceV2;
    const s3 = AppColors.surfaceV2Active;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.errorV2,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: s1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              '${index + 1}',
              style: AppTextStyles.label.copyWith(fontSize: 13, color: t3),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: t1,
                ),
              ),
            ),
            // Sets pill picker 1–6
            Row(
              children: List.generate(6, (i) {
                final n = i + 1;
                final isActive = item.plannedSets == n;
                return GestureDetector(
                  onTap: () => onSetsChanged(n),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.userAccent : s3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.backgroundV2 : t3,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Icon(Icons.drag_handle, color: t3, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;
    const strokeWidth = 8.0;
    const startAngle = -math.pi / 2;
    const sweepFull = 2 * math.pi;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepFull,
      false,
      Paint()
        ..color = const Color(0xFF2A2A2A)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Progress arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepFull * progress,
        false,
        Paint()
          ..color = const Color(0xFFC8FF00)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _PastWorkoutsSheet extends StatefulWidget {
  const _PastWorkoutsSheet({required this.sessions});

  final List<Session> sessions;

  @override
  State<_PastWorkoutsSheet> createState() => _PastWorkoutsSheetState();
}

class _PastWorkoutsSheetState extends State<_PastWorkoutsSheet> {
  int? _selected;

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Active,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Load a past workout?',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textV2Primary,
                fontSize: 20,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Pick a workout to load into your plan, then tweak or start it as-is.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textV2Secondary,
                height: 1.4,
              ),
            ),
          ),
          ...widget.sessions.asMap().entries.map((entry) {
            final i = entry.key;
            final session = entry.value;
            final exercises = session.summary?.exercises ?? [];
            final isSelected = _selected == i;
            return GestureDetector(
              onTap: () => setState(() => _selected = isSelected ? null : i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.userAccent.withValues(alpha: 0.1)
                      : AppColors.surfaceV2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.userAccent
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title.isNotEmpty
                                ? session.title
                                : 'Gym Session',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textV2Primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _relativeDate(session.createdAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textV2Secondary,
                            ),
                          ),
                          if (exercises.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              exercises.map((e) => e.name).join(' · '),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textV2Secondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.userAccent,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ZyntroButton(
              title: 'Load',
              fullWidth: true,
              variant: ZyntroButtonVariant.primary,
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, widget.sessions[_selected!]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: ZyntroButton(
              title: 'Start from scratch',
              fullWidth: true,
              variant: ZyntroButtonVariant.ghost,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

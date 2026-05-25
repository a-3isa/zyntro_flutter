import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../auth/auth_providers.dart';
import '../../../services/session_service.dart';
import '../../../services/follow_service.dart';
import '../../../core/models/models.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/pulse_dot.dart';
import '../../../utils/haptic_manager.dart';
import '../domain/exercise_plan_item.dart';

/// Train screen — workout type + partner selection + session start.
class StartSessionPage extends ConsumerStatefulWidget {
  const StartSessionPage({super.key});

  @override
  ConsumerState<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends ConsumerState<StartSessionPage> {
  WorkoutType? _selectedType; // null = nothing chosen yet
  // partner mode: 'solo' | 'friends' | 'random'
  String _partnerMode = 'solo';
  final Set<String> _selectedFriends = {};
  bool _isLoading = false;
  bool _isLoadingFollows = true;
  List<User> _mutualFollows = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // views: 'home' | 'plan'
  String _view = 'home';
  late List<ExercisePlanItem> _plan;
  final TextEditingController _exerciseInputController = TextEditingController();
  List<String> _suggestions = [];

  bool _startButtonPressed = false;

  // Live friends strip
  List<Map<String, dynamic>> _liveFriends = [];

  // Stats for Train home screen
  int _weekSessions = 0;
  static const int _weekTarget = 5;
  int _streakDays = 0;
  int _totalSessions = 0;
  List<Session> _recentSessions = [];
  bool _isLoadingStats = true;

  static const _prefKeyType = 'last_workout_type';

  @override
  void initState() {
    super.initState();
    _plan = kDefaultPlan.map((e) => ExercisePlanItem(name: e.name, sets: e.sets)).toList();
    _loadPreferences();
    _loadMutualFollows();
    _loadStats();
    _loadLiveFriends();
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
    _searchController.dispose();
    _exerciseInputController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingStats = false);
      return;
    }
    try {
      final service = ref.read(sessionServiceProvider);
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      final allSessions = await service.getUserSessions(uid, limit: 20);
      final weekCount = allSessions
          .where((s) => s.createdAt.isAfter(weekStartDate))
          .length;

      if (mounted) {
        setState(() {
          _weekSessions = weekCount;
          _totalSessions = allSessions.length;
          _recentSessions = allSessions.take(3).toList();
          _streakDays = weekCount; // approximate from this-week count
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadMutualFollows() async {
    setState(() => _isLoadingFollows = true);
    final authState = ref.read(authSessionProvider);
    final uid = authState.valueOrNull?.id;
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
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
      if (uid == null) return;

      final follows = await ref.read(followServiceProvider).getMutualFollows(uid);
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

  List<User> get _filteredFriends {
    if (_searchQuery.isEmpty) return _mutualFollows;
    return _mutualFollows.where((user) {
      final query = _searchQuery.toLowerCase();
      return user.displayName.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _handleStartSession() async {
    final type = _selectedType;
    if (type == null) return;
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
      if (uid == null) throw Exception('Not authenticated');

      final sessionService = ref.read(sessionServiceProvider);
      final existingSessionId = await sessionService.checkActiveSession(uid);

      if (existingSessionId != null && mounted) {
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
                  style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You already have a workout in progress. Resume it or end it to start a new one.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
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

        if (!mounted) return;

        if (action == 'resume') {
          context.push(AppRouteLocations.sessionRoom(existingSessionId, type: type.value));
          return;
        } else if (action == 'end') {
          setState(() => _isLoading = true);
          await sessionService.endSession(existingSessionId, uid, null);
        } else {
          return;
        }
      }

      // Build invited list from selected friends
      final invitedIds = _partnerMode == 'friends' && _selectedFriends.isNotEmpty
          ? _selectedFriends.toList()
          : null;

      final sessionId = await sessionService.createSession(
        hostId: uid,
        type: type.value,
        title: '${type.displayName} Session',
        invitedUserIds: invitedIds,
        phase: SessionPhase.live,
      );

      await HapticFeedback.mediumImpact();

      if (mounted) {
        context.push(AppRouteLocations.sessionRoom(sessionId, type: type.value));
      }
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


  String _getTypeLabel(WorkoutType type) {
    for (final item in _quickStartTypes) {
      if (item.type == type) return item.label;
    }
    return type.displayName;
  }

  @override
  Widget build(BuildContext context) {
    if (_view == 'plan') return _buildPlanView();
    return _buildHomeView();
  }

  Color _getTypeColor(WorkoutType type) {
    switch (type.value) {
      case 'gym': return const Color(0xFFC8FF00);
      case 'running': return const Color(0xFF38BDF8);
      case 'cycling': return const Color(0xFFA78BFA);
      case 'swimming': return const Color(0xFF22D3EE);
      case 'yoga': return const Color(0xFF34D399);
      case 'hiit': return const Color(0xFFFF8C00);
      default: return const Color(0xFF888888);
    }
  }

  Widget _buildFriendTile(User user, {int index = 0}) {
    final isSelected = _selectedFriends.contains(user.id);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedFriends.remove(user.id);
          } else if (_selectedFriends.length < 10) {
            _selectedFriends.add(user.id);
          }
        });
        HapticManager.light();
      },
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentLime.withValues(alpha: 0.1)
                : AppColors.surfaceV2Elevated.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.accentLime.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.accentLime : Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: user.photoURL != null
                      ? CachedNetworkImage(
                          imageUrl: user.photoURL!,
                          placeholder: (context, url) => Container(color: AppColors.surfaceV2),
                          errorWidget: (context, url, error) => _buildAvatarPlaceholder(user),
                          fit: BoxFit.cover,
                        )
                      : _buildAvatarPlaceholder(user),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                    Text(
                      '@${user.id.substring(0, 8)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  key: ValueKey(isSelected),
                  color: isSelected ? AppColors.accentLime : AppColors.textV2Tertiary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
    );
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

  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceV2Elevated.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2Elevated,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 16, color: AppColors.surfaceV2Elevated),
                      const SizedBox(height: 6),
                      Container(width: 80, height: 12, color: AppColors.surfaceV2Elevated),
                    ],
                  ),
                ),
              ],
            ),
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
                            color: AppColors.backgroundV2, width: 2),
                      ),
                      child: ClipOval(
                        child: _liveFriends[i]['photoURL'] != null
                            ? CachedNetworkImage(
                                imageUrl:
                                    _liveFriends[i]['photoURL'] as String,
                                fit: BoxFit.cover,
                                errorWidget: (_, url, e) => _avatarFallback(
                                    _liveFriends[i]['name'] as String),
                              )
                            : _avatarFallback(
                                _liveFriends[i]['name'] as String),
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
              style: GoogleFonts.outfit(
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
            style: GoogleFonts.outfit(
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
    final canStart = _selectedType != null && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Train',
                      style: GoogleFonts.syne(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
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
                    if (_partnerMode == 'friends') ...[
                      const SizedBox(height: 12),
                      _buildFriendsSection(),
                    ],
                    if (_recentSessions.isNotEmpty || _isLoadingStats) ...[
                      const SizedBox(height: 28),
                      _buildSectionLabel('RECENT'),
                      const SizedBox(height: 12),
                      _buildRecentList(),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Sticky Start Session CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildStartSessionCta(canStart: canStart),
            ),
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
        setState(() => _selectedType = type);
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
                  )
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
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label.toUpperCase(),
                              style: GoogleFonts.outfit(
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
                      style: GoogleFonts.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
    final modes = [
      (id: 'solo', label: 'Solo', icon: Icons.person_outline_rounded),
      (id: 'friends', label: 'Friends', icon: Icons.group_outlined),
      (id: 'random', label: 'Random', icon: Icons.shuffle_rounded),
    ];
    return Row(
      children: modes.map((m) {
        final isActive = _partnerMode == m.id;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticManager.light();
              setState(() => _partnerMode = m.id);
              if (m.id == 'random' && _selectedType != null) {
                context.push(AppRouteLocations.matchmaking(_selectedType!));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(right: m.id == 'random' ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? AppColors.surfaceV2Elevated : AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? AppColors.accentLime.withValues(alpha: 0.4)
                      : AppColors.surfaceV2Active,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(m.icon,
                    size: 20,
                    color: isActive ? AppColors.accentLime : AppColors.textV2Tertiary,
                  ),
                  const SizedBox(height: 4),
                  Text(m.label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.textV2Primary : AppColors.textV2Tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFriendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_mutualFollows.isNotEmpty || _isLoadingFollows)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceV2Elevated.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textV2Primary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: TextStyle(color: AppColors.textV2Tertiary),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textV2Tertiary, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        const SizedBox(height: 10),
        if (_isLoadingFollows)
          _buildLoadingSkeleton()
        else if (_mutualFollows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No mutual follows yet — start solo or find friends.',
              style: TextStyle(color: AppColors.textV2Tertiary, fontSize: 13),
            ),
          )
        else
          ..._filteredFriends.asMap().entries.map(
            (e) => _buildFriendTile(e.value, index: e.key),
          ),
        if (_selectedFriends.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_selectedFriends.length} friend${_selectedFriends.length > 1 ? 's' : ''} selected',
              style: TextStyle(
                color: AppColors.accentLime,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
                      style: GoogleFonts.syne(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textV2Primary,
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
                  style: GoogleFonts.syne(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textV2Primary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '$_streakDays 🔥',
                      style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentLime,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$_totalSessions',
                      style: GoogleFonts.syne(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                      ),
                    ),
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
                    Text(
                      'total',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textV2Tertiary,
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

  Widget _buildStartSessionCta({required bool canStart}) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _startButtonPressed = true),
      onTapUp: (_) {
        setState(() => _startButtonPressed = false);
        if (_selectedType != null && !_isLoading) {
          HapticManager.medium();
          if (_selectedType == WorkoutType.gym) {
            setState(() => _view = 'plan');
          } else {
            _handleStartSession();
          }
        }
      },
      onTapCancel: () => setState(() => _startButtonPressed = false),
      child: AnimatedScale(
        scale: _startButtonPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: AppCurves.press,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: _selectedType == null
                ? AppColors.surfaceV2Active
                : AppColors.accentLime,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.backgroundV2,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _selectedType == null
                          ? 'Select a workout type'
                          : 'Start ${_getTypeLabel(_selectedType!)} Session',
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _selectedType == null
                            ? AppColors.textV2Tertiary
                            : AppColors.backgroundV2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (_partnerMode == 'friends' && _selectedFriends.isNotEmpty)
                      Text(
                        'with ${_selectedFriends.length} friend${_selectedFriends.length > 1 ? 's' : ''}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.backgroundV2.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
        ),
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


  Widget _buildRecentList() {
    if (_isLoadingStats) {
      return Column(
        children: List.generate(2, (_) => Container(
          height: 64,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceV2,
            borderRadius: BorderRadius.circular(14),
          ),
        )),
      );
    }
    return Column(
      children: _recentSessions.map((session) {
        final color = _getTypeColorByString(session.type);
        final icon = _getIconData(_workoutIconForType(session.type));
        final ago = _formatAgo(session.createdAt);
        final duration = session.endedAt != null
            ? _formatDuration(session.endedAt!.difference(session.startedAt))
            : '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceV2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title.isNotEmpty ? session.title : session.type,
                      style: TextStyle(
                        color: AppColors.textV2Primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      duration.isNotEmpty ? '$ago · $duration' : ago,
                      style: TextStyle(
                        color: AppColors.textV2Tertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getTypeColorByString(String type) {
    switch (type) {
      case 'gym': return const Color(0xFFC8FF00);
      case 'running': return const Color(0xFF38BDF8);
      case 'cycling': return const Color(0xFFA78BFA);
      case 'swimming': return const Color(0xFF22D3EE);
      case 'yoga': return const Color(0xFF34D399);
      case 'hiit': return const Color(0xFFFF8C00);
      default: return const Color(0xFF888888);
    }
  }

  String _workoutIconForType(String type) {
    switch (type) {
      case 'running': return 'directions_run';
      case 'cycling': return 'directions_bike';
      case 'swimming': return 'pool';
      case 'yoga': return 'self_improvement';
      case 'hiit': return 'timer';
      default: return 'fitness_center';
    }
  }

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 2) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return 'Just now';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    return '${m}m';
  }

  Widget _buildPlanView() {
    const bg = AppColors.backgroundV2;
    const s1 = AppColors.surfaceV2;
    const t1 = AppColors.textV2Primary;
    const t2 = AppColors.textV2Secondary;
    const t3 = AppColors.textV2Tertiary;
    final totalSets = _plan.fold<int>(0, (sum, e) => sum + e.sets);

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
                      child: Icon(Icons.arrow_back_rounded, color: t2, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Plan Session',
                      style: GoogleFonts.syne(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: t1,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    '$totalSets sets total',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: t2,
                    ),
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
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
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
                    onSetsChanged: (sets) => setState(() => item.sets = sets),
                  );
                },
              ),
            ),
            // Add exercise input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: s1,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _exerciseInputController,
                      style: GoogleFonts.outfit(fontSize: 14, color: t1),
                      decoration: InputDecoration(
                        hintText: 'Add exercise...',
                        hintStyle: GoogleFonts.outfit(color: t3),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.add, color: AppColors.accentLime),
                          onPressed: _addExercise,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _suggestions = value.isEmpty
                              ? []
                              : kExerciseSuggestions
                                  .where((s) => s.toLowerCase().contains(value.toLowerCase()))
                                  .take(4)
                                  .toList();
                        });
                      },
                      onSubmitted: (_) => _addExercise(),
                    ),
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: _suggestions.map((s) {
                        return GestureDetector(
                          onTap: () {
                            _exerciseInputController.text = s;
                            _addExercise();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentLime.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              s,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.accentLime,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Begin session button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ZyntroButton(
                title: 'Begin Session ⚡  ($totalSets sets)',
                fullWidth: true,
                size: ZyntroButtonSize.lg,
                variant: ZyntroButtonVariant.primary,
                loading: _isLoading,
                onPressed: _isLoading ? null : () {
                  HapticManager.heavy();
                  _handleStartSessionWithPlan();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addExercise() {
    final name = _exerciseInputController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _plan.add(ExercisePlanItem(name: name, sets: 3));
      _exerciseInputController.clear();
      _suggestions = [];
    });
    HapticManager.light();
  }

  Future<void> _handleStartSessionWithPlan() async {
    final type = _selectedType;
    if (type == null) return;
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
      if (uid == null) throw Exception('Not authenticated');

      final sessionService = ref.read(sessionServiceProvider);

      final invitedIds = _partnerMode == 'friends' && _selectedFriends.isNotEmpty
          ? _selectedFriends.toList()
          : null;

      final sessionId = await sessionService.createSession(
        hostId: uid,
        type: type.value,
        title: '${type.displayName} Session',
        invitedUserIds: invitedIds,
        phase: SessionPhase.live,
      );

      await HapticFeedback.mediumImpact();

      if (mounted) {
        final exerciseNames = _plan.map((e) => e.name).toList();
        context.push(
          AppRouteLocations.sessionRoom(sessionId, type: type.value),
          extra: {'plannedExercises': exerciseNames},
        );
      }
    } catch (e) {
      debugPrint('[StartSessionPage] Failed to start session with plan: $e');
      if (mounted) {
        _showError(_mapStartSessionError(e));
        await HapticFeedback.vibrate();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textV2Tertiary,
        letterSpacing: 2,
      ),
    );
  }
}

class _ExercisePlanRow extends StatelessWidget {
  final ExercisePlanItem item;
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
              style: GoogleFonts.syne(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t3,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: t1,
                ),
              ),
            ),
            // Sets pill picker 1–6
            Row(
              children: List.generate(6, (i) {
                final n = i + 1;
                final isActive = item.sets == n;
                return GestureDetector(
                  onTap: () => onSetsChanged(n),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.accentLime : s3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: GoogleFonts.syne(
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


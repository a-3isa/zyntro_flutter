import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../../services/session_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/follow_service.dart';
import '../../../core/models/models.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/zyntro_card.dart';
import '../../../widgets/premium_effects.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/premium_animations.dart';

/// Premium Start session screen for configuring workout type and inviting friends.
class StartSessionPage extends ConsumerStatefulWidget {
  const StartSessionPage({super.key});

  @override
  ConsumerState<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends ConsumerState<StartSessionPage> {
  WorkoutType _selectedType = WorkoutType.gym;
  SessionMode _selectedMode = SessionMode.turnBased;
  final Set<String> _selectedFriends = {};
  bool _isLoading = false;
  bool _isLoadingFollows = true;
  List<User> _mutualFollows = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMutualFollows();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMutualFollows() async {
    setState(() => _isLoadingFollows = true);
    final authState = ref.read(authStateProvider);
    final uid = authState.valueOrNull?.uid;
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

  List<User> get _filteredFriends {
    if (_searchQuery.isEmpty) return _mutualFollows;
    return _mutualFollows.where((user) {
      final query = _searchQuery.toLowerCase();
      return user.displayName.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _handleStartSession() async {
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authStateProvider);
      final uid = authState.valueOrNull?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final sessionId = await ref
          .read(sessionServiceProvider)
          .createSession(
            hostId: uid,
            type: _selectedType.value,
            title: '${_selectedType.displayName} Session',
            mode: _selectedMode,
            invitedUserIds: _selectedFriends.isNotEmpty
                ? _selectedFriends.toList()
                : null,
          );

      await HapticFeedback.mediumImpact();

      if (mounted) {
        context.push('/session/room/$sessionId?type=${_selectedType.value}');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to start session. Please try again.';
        if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage = 'Check your internet connection and try again.';
        }
        _showError(errorMessage);
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
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

  List<Color> _getCategoryGradient(String category) {
    switch (category) {
      case 'cardio':
        return AppColors.secondaryGradient;
      case 'strength':
        return AppColors.primaryGradient;
      case 'flexibility':
        return AppColors.successGradient;
      case 'mixed':
        return AppColors.premiumGradient;
      default:
        return [AppColors.textSecondaryDark, AppColors.textTertiaryDark];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,

      body: Column(
        children: [
          // Custom Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                BounceAnimation(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: GradientText(
                    text: 'Start Session',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    colors: [AppColors.textDark, AppColors.textSecondaryDark],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Background orbs
                Positioned(
                  top: -80,
                  right: -80,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _getCategoryGradient(
                            _selectedType.category,
                          ).first.withValues(alpha: 0.2),
                          _getCategoryGradient(
                            _selectedType.category,
                          ).first.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Workout type selection
                      Text(
                        'Workout Type',
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Responsive grid for workout types
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 400
                              ? 3
                              : 2;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: AppSpacing.md,
                                  mainAxisSpacing: AppSpacing.md,
                                  childAspectRatio: 1.0,
                                ),
                            itemCount: WorkoutType.values.length,
                            itemBuilder: (context, index) {
                              final type = WorkoutType.values[index];
                              return _buildTypeCard(type: type);
                            },
                          );
                        },
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // Session mode
                      Row(
                        children: [
                          Text(
                            'Session Mode',
                            style: TextStyle(
                              fontSize: AppFontSize.lg,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message:
                                'Choose how you want to log sets with friends',
                            triggerMode: TooltipTriggerMode.tap,
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      ...SessionMode.values.map((mode) => _buildModeCard(mode)),

                      const SizedBox(height: AppSpacing.xxl),

                      // Invite friends section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Invite Friends',
                            style: TextStyle(
                              fontSize: AppFontSize.lg,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (_selectedFriends.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: AppColors.primaryGradient,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_selectedFriends.length} selected',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Optional - start solo or with friends',
                        style: TextStyle(
                          color: AppColors.textTertiaryDark,
                          fontSize: AppFontSize.sm,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Search bar
                      if (_mutualFollows.isNotEmpty || _isLoadingFollows)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryDark,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.lg,
                            ),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppColors.textDark),
                            decoration: InputDecoration(
                              hintText: 'Search friends...',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiaryDark,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppColors.textSecondaryDark,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                        ),

                      const SizedBox(height: AppSpacing.md),

                      if (_isLoadingFollows)
                        _buildLoadingSkeleton()
                      else if (_mutualFollows.isEmpty)
                        ZyntroCard(
                          variant: ZyntroCardVariant.glass,
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_add_outlined,
                                size: 40,
                                color: AppColors.textSecondaryDark,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Text(
                                'No mutual follows yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Start a solo session or find friends first!',
                                style: TextStyle(
                                  color: AppColors.textSecondaryDark,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ..._filteredFriends.asMap().entries.map(
                          (entry) =>
                              _buildFriendTile(entry.value, index: entry.key),
                        ),

                      const SizedBox(height: AppSpacing.xxxl),

                      // Start button with pulsing glow when ready
                      PulsingGlow(
                        glowColor: AppColors.primary,
                        child: ZyntroButton(
                          title: _selectedFriends.isEmpty
                              ? 'Start ${_selectedType.displayName} Session'
                              : 'Start with ${_selectedFriends.length + 1} people',
                          fullWidth: true,
                          size: ZyntroButtonSize.lg,
                          loading: _isLoading,
                          rightIcon: const Icon(Icons.play_arrow_rounded),
                          onPressed: _isLoading ? null : _handleStartSession,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({required WorkoutType type}) {
    final isSelected = _selectedType == type;
    final gradientColors = _getCategoryGradient(type.category);
    final icon = _getIconData(type.icon);

    Widget card = AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : AppColors.surfaceSecondaryDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: isSelected ? gradientColors.first : AppColors.borderDark,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : gradientColors.first.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.white : gradientColors.first,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            type.displayName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: AppFontSize.sm,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    // Wrap selected card with PulsingGlow effect
    if (isSelected) {
      card = PulsingGlow(glowColor: gradientColors.first, child: card);
    }

    return BounceAnimation(
      onTap: () {
        setState(() => _selectedType = type);
        HapticFeedback.selectionClick();
      },
      child: card,
    );
  }

  Widget _buildModeCard(SessionMode mode) {
    final isSelected = _selectedMode == mode;
    final isTurnBased = mode == SessionMode.turnBased;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = mode);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: AppDurations.fast,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceSecondaryDark,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isTurnBased
                    ? Icons.sync_alt_rounded
                    : Icons.compare_arrows_rounded,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTurnBased ? 'Turn-Based' : 'Parallel',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTurnBased
                        ? 'Take turns logging sets'
                        : 'Both log sets simultaneously',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            Radio<SessionMode>(
              value: mode,
              // ignore: deprecated_member_use
              groupValue: _selectedMode,
              fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return AppColors.textSecondaryDark;
              }),
              // ignore: deprecated_member_use
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMode = value);
                  HapticFeedback.selectionClick();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(User user, {int index = 0}) {
    final isSelected = _selectedFriends.contains(user.id);

    return SlideInAnimation.fromLeft(
      index: index,
      delay: const Duration(milliseconds: 30),
      child: ScaleOnTap(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedFriends.remove(user.id);
            } else if (_selectedFriends.length < 10) {
              _selectedFriends.add(user.id);
            }
          });
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: AppDurations.fast,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surfaceSecondaryDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderDark,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(colors: AppColors.primaryGradient)
                      : null,
                  color: isSelected ? null : AppColors.surfaceDark,
                ),
                child: user.photoURL != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.photoURL!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textDark,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  user.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              // Animated checkmark with FadeInAnimation
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(isSelected),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: AppColors.primaryGradient,
                          )
                        : null,
                    color: isSelected ? null : AppColors.surfaceDark,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderDark,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ],
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
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryDark,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
            child: Row(
              children: const [
                ShimmerLoader(
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ShimmerLoader(width: double.infinity, height: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../auth/auth_providers.dart';
import '../../../services/session_service.dart';
import '../../../services/follow_service.dart';
import '../../../core/models/models.dart';
import '../../../widgets/zyntro_button.dart';
import '../../../widgets/zyntro_card.dart';
import '../../../widgets/premium_effects.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/premium_animations.dart';

/// Premium Start session screen for configuring workout type and inviting friends.
class StartSessionPage extends ConsumerStatefulWidget {
  const StartSessionPage({
    super.key,
    this.initialType = WorkoutType.gym,
  });

  final WorkoutType initialType;

  @override
  ConsumerState<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends ConsumerState<StartSessionPage> {
  late WorkoutType _selectedType;
  final Set<String> _selectedFriends = {};
  bool _isLoading = false;
  bool _isLoadingFollows = true;
  List<User> _mutualFollows = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadMutualFollows();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final authState = ref.read(authSessionProvider);
      final uid = authState.valueOrNull?.id;
      if (uid == null) throw Exception('Not authenticated');

      final sessionService = ref.read(sessionServiceProvider);
      final existingSessionId = await sessionService.checkActiveSession(uid);

      if (existingSessionId != null && mounted) {
        setState(() => _isLoading = false); // Pause loading for dialog
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceSecondaryDark,
            title: const Text('Active Session Found', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
            content: const Text(
              'You already have an active workout in progress. Would you like to resume it, or end it to start this new one?',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiaryDark)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'resume'),
                child: const Text('Resume Active', style: TextStyle(color: AppColors.primary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, 'end'),
                child: const Text('End Old & Start New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (!mounted) return;
        
        if (action == 'resume') {
          context.push(
            AppRouteLocations.sessionRoom(
              existingSessionId,
              type: _selectedType.value,
            ),
          );
          return;
        } else if (action == 'end') {
          setState(() => _isLoading = true);
          await sessionService.endSession(existingSessionId, uid, null);
        } else {
          return; // Cancelled
        }
      }

      final sessionId = await sessionService.createSession(
            hostId: uid,
            type: _selectedType.value,
            title: '${_selectedType.displayName} Session',
            invitedUserIds: _selectedFriends.isNotEmpty
                ? _selectedFriends.toList()
                : null,
            phase: _selectedType == WorkoutType.gym
                ? SessionPhase.setup
                : SessionPhase.live,
          );

      await HapticFeedback.mediumImpact();

      if (mounted) {
        if (_selectedType == WorkoutType.gym) {
          context.push(AppRouteLocations.gymSessionSetup(sessionId));
        } else {
          context.push(
            AppRouteLocations.sessionRoom(
              sessionId,
              type: _selectedType.value,
            ),
          );
        }
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
        backgroundColor: AppColors.error,
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

  List<Color> _getCategoryGradient(String category) {
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
    final selectedGradient = _getCategoryGradient(_selectedType.category);
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Custom Header with Premium Styling
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 12,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(
                bottom: BorderSide(
                  color: selectedGradient.first.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: selectedGradient.first.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                BounceAnimation(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: GradientText(
                    text: 'Start Session',
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    colors: [AppColors.textDark, AppColors.textSecondaryDark],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Background ambient orbs
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          selectedGradient.first.withValues(alpha: 0.15),
                          selectedGradient.first.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Workout type selection
                      const SectionHeader(title: 'Workout Type'),
                      const SizedBox(height: 8),
                      const Text(
                        'Pick the session type that matches your workout and invite friends to join.',
                        style: TextStyle(
                          color: AppColors.textTertiaryDark,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

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
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.0,
                                ),
                            itemCount: WorkoutType.values.length,
                            itemBuilder: (context, index) {
                              final type = WorkoutType.values[index];
                              return _buildTypeCard(type: type, index: index);
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Invite friends section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SectionHeader(title: 'Invite Friends'),
                          if (_selectedFriends.isNotEmpty)
                            FadeInAnimation(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: AppColors.primaryGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${_selectedFriends.length} selected',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start solo or train together with mutual follows',
                        style: TextStyle(
                          color: AppColors.textTertiaryDark,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      if (_mutualFollows.isNotEmpty || _isLoadingFollows)
                        GlassContainer(
                          blur: 10,
                          backgroundColor: AppColors.surfaceSecondaryDark.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppColors.textDark, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: 'Search friends...',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiaryDark,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppColors.textSecondaryDark,
                                size: 18,
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

                      const SizedBox(height: 16),

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
                                color: AppColors.textTertiaryDark,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No mutual follows yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Start a solo session or find friends first!',
                                style: TextStyle(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 14,
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

                      const SizedBox(height: 40),

                      // Start solo / with friends button
                      ZyntroButton(
                        title: _selectedFriends.isEmpty
                            ? 'Start Solo'
                            : 'Start with ${_selectedFriends.length + 1} athletes',
                        fullWidth: true,
                        size: ZyntroButtonSize.lg,
                        variant: ZyntroButtonVariant.primary,
                        loading: _isLoading,
                        rightIcon: const Icon(Icons.bolt_rounded),
                        onPressed: _isLoading ? null : () {
                          HapticManager.heavy();
                          _handleStartSession();
                        },
                      ),

                      // Random match option (only when no friends selected)
                      if (_selectedFriends.isEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: AppColors.textTertiaryDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    HapticManager.light();
                                    context.push(
                                      AppRouteLocations.matchmaking(
                                        _selectedType,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.shuffle_rounded, size: 20),
                            label: Text(
                              'Find a Random ${_selectedType.displayName} Partner',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondaryDark,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
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

  Widget _buildTypeCard({required WorkoutType type, required int index}) {
    final isSelected = _selectedType == type;
    final gradientColors = _getCategoryGradient(type.category);
    final icon = _getIconData(type.icon);

    return SlideInAnimation(
      index: index,
      child: BounceAnimation(
        onTap: () {
          setState(() => _selectedType = type);
          HapticManager.selection();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : AppColors.surfaceSecondaryDark.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.white : gradientColors.first,
              ),
              const SizedBox(height: 10),
              Text(
                type.displayName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendTile(User user, {int index = 0}) {
    final isSelected = _selectedFriends.contains(user.id);

    return SlideInAnimation.fromBottom(
      index: index,
      child: ScaleOnTap(
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
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surfaceSecondaryDark.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
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
                    color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: user.photoURL != null
                      ? CachedNetworkImage(
                          imageUrl: user.photoURL!,
                          placeholder: (context, url) => Container(color: AppColors.surfaceDark),
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
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '@${user.id.substring(0, 8)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryDark,
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
                  color: isSelected ? AppColors.primary : AppColors.textTertiaryDark,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(User user) {
    return Container(
      color: AppColors.surfaceDark,
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
          child: GlassContainer(
            blur: 5,
            backgroundColor: AppColors.surfaceSecondaryDark.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const ShimmerLoader(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerLoader(width: 120, height: 16),
                      SizedBox(height: 6),
                      ShimmerLoader(width: 80, height: 12),
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
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        color: AppColors.textDark,
      ),
    );
  }
}


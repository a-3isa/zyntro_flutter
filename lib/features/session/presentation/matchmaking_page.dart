import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_route_locations.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/auth_providers.dart';
import '../../../services/matchmaking_service.dart';

/// Searching-for-a-partner screen.
///
/// Enters the matchmaking queue on mount, navigates to the session as soon
/// as a match is found, and allows the user to cancel and go back.
class MatchmakingPage extends ConsumerStatefulWidget {
  final WorkoutType workoutType;

  const MatchmakingPage({super.key, required this.workoutType});

  @override
  ConsumerState<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends ConsumerState<MatchmakingPage>
    with SingleTickerProviderStateMixin {
  String? _queueDocId;
  StreamSubscription<Map<String, dynamic>?>? _queueSub;
  bool _isCancelling = false;
  bool _didNavigate = false;
  String? _error;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startMatchmaking();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _queueSub?.cancel();
    super.dispose();
  }

  Future<void> _startMatchmaking() async {
    final authUser = ref.read(authSessionProvider).valueOrNull;
    if (authUser == null) {
      setState(() {
        _error = 'You must be signed in to find a match.';
      });
      return;
    }

    try {
      final outcome = await ref.read(matchmakingServiceProvider).joinQueue(
            userId: authUser.id,
            workoutType: widget.workoutType,
          );

      if (!mounted) return;

      switch (outcome) {
        case MatchFound(:final sessionId, :final queueDocId):
          _queueDocId = queueDocId;
          _navigateToSession(sessionId);

        case WaitingForMatch(:final queueDocId):
          _queueDocId = queueDocId;
          _listenForMatch(queueDocId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  void _listenForMatch(String queueDocId) {
    _queueSub = ref
        .read(matchmakingServiceProvider)
        .listenToQueueEntry(queueDocId)
        .listen((data) {
      if (!mounted || _didNavigate) return;
      if (data == null) return; // doc deleted (cancelled)

      final status = data['status'] as String?;
      final sessionId = data['sessionId'] as String?;
      if (status == 'matched' && sessionId != null) {
        _navigateToSession(sessionId);
      }
    });
  }

  void _navigateToSession(String sessionId) {
    if (_didNavigate || !mounted) return;
    _didNavigate = true;
    _queueSub?.cancel();

    context.pushReplacement(
      AppRouteLocations.sessionEntry(
        sessionId: sessionId,
        type: widget.workoutType.value,
        phase: widget.workoutType == WorkoutType.gym
            ? SessionPhase.setup
            : SessionPhase.live,
      ),
    );
  }

  Future<void> _cancel() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    _queueSub?.cancel();
    final docId = _queueDocId;
    if (docId != null) {
      try {
        await ref.read(matchmakingServiceProvider).cancelQueue(docId);
      } catch (_) {}
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _isCancelling ? null : _cancel,
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textV2Secondary,
                ),
              ),
              const Spacer(),
              _buildBody(),
              const Spacer(),
              if (_error == null)
                _buildCancelButton()
              else
                _buildRetryButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 48),
          const SizedBox(height: 20),
          Text(
            _error!,
            style: const TextStyle(
                color: AppColors.textV2Secondary, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing icon
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.userAccent.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _getWorkoutIcon(),
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Finding a partner',
          style: TextStyle(
            color: AppColors.textV2Primary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Looking for someone doing ${widget.workoutType.displayName} near your level...',
          style: const TextStyle(
            color: AppColors.textV2Secondary,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildDots(),
      ],
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final offset = i * 0.33;
            final value = (_pulseController.value + offset) % 1.0;
            final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2)
                .clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.userAccent.withValues(alpha: opacity),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isCancelling ? null : _cancel,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textV2Secondary,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isCancelling
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Cancel search'),
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () {
          setState(() {
            _error = null;
          });
          _startMatchmaking();
        },
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.userAccent,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text('Try again'),
      ),
    );
  }

  IconData _getWorkoutIcon() {
    switch (widget.workoutType.icon) {
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
      default:
        return Icons.search_rounded;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/session_service.dart';

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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
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

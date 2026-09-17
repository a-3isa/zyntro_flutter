import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Plan-complete terminal actions in the session room (Z-ARCH-002).
class SessionPlanCompleteView extends StatelessWidget {
  const SessionPlanCompleteView({
    super.key,
    required this.onFinishSession,
    required this.onAddExercise,
  });

  final VoidCallback onFinishSession;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.signal, size: 64),
            const SizedBox(height: 18),
            const Text(
              'Plan complete',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textV2Primary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Finish the session or add another exercise.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textV2Secondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onFinishSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.signal,
                foregroundColor: AppColors.backgroundV2,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Finish Session'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onAddExercise,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textV2Primary,
                side: const BorderSide(color: AppColors.surfaceV2Active),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Add Exercise'),
            ),
          ],
        ),
      ),
    );
  }
}

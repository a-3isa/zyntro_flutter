import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_theme.dart';

/// Duration-based workout log form (Z-ARCH-002).
class SessionDurationInputSection extends StatelessWidget {
  const SessionDurationInputSection({
    super.key,
    required this.workoutType,
    required this.durationController,
    required this.isLogging,
    required this.onLog,
  });

  final WorkoutType workoutType;
  final TextEditingController durationController;
  final bool isLogging;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.self_improvement,
                size: 16,
                color: AppColors.successDark,
              ),
              const SizedBox(width: 6),
              Text(
                workoutType.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.successDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (min)',
                  hintText: '30',
                  prefixIcon: Icon(Icons.timer),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          onPressed: isLogging ? null : onLog,
          icon: isLogging
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(isLogging ? 'Logging...' : 'Log Session'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../cardio_activity_options.dart';
import 'session_room_animations.dart';

/// Cardio activity logging form (Z-ARCH-002).
class SessionCardioInputSection extends StatelessWidget {
  const SessionCardioInputSection({
    super.key,
    required this.workoutType,
    required this.cardioActivityType,
    required this.distanceController,
    required this.durationController,
    required this.paceController,
    required this.distanceFocus,
    required this.durationFocus,
    required this.paceFocus,
    required this.isLogging,
    required this.isRecording,
    required this.isUploadingVoice,
    required this.onActivityTypeChanged,
    required this.onLogActivity,
    required this.onToggleRecording,
  });

  final WorkoutType workoutType;
  final String? cardioActivityType;
  final TextEditingController distanceController;
  final TextEditingController durationController;
  final TextEditingController paceController;
  final FocusNode distanceFocus;
  final FocusNode durationFocus;
  final FocusNode paceFocus;
  final bool isLogging;
  final bool isRecording;
  final bool isUploadingVoice;
  final ValueChanged<String> onActivityTypeChanged;
  final VoidCallback onLogActivity;
  final VoidCallback onToggleRecording;

  @override
  Widget build(BuildContext context) {
    final activityOptions = cardioActivityOptions(workoutType);
    final canLog = cardioActivityType != null && !isLogging;

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.signal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              border: Border.all(
                color: AppColors.signal.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cardioActivityIcon(workoutType.value),
                  size: 16,
                  color: AppColors.signalDim,
                ),
                const SizedBox(width: 6),
                Text(
                  workoutType.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.signalDim,
                  ),
                ),
              ],
            ),
          ),
          if (activityOptions.length > 1) ...[
            Row(
              children: activityOptions.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final isFirst = index == 0;
                final isLast = index == activityOptions.length - 1;
                final isSelected = cardioActivityType == option['value'];

                return Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        onActivityTypeChanged(option['value'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.signal
                            : AppColors.surfaceSecondaryLight,
                        borderRadius: BorderRadius.horizontal(
                          left: isFirst
                              ? const Radius.circular(AppBorderRadius.md)
                              : Radius.zero,
                          right: isLast
                              ? const Radius.circular(AppBorderRadius.md)
                              : Radius.zero,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            option['icon'] as IconData,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              option['label'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: distanceController,
                  focusNode: distanceFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Distance (km)',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: durationController,
                  focusNode: durationFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (min)',
                    prefixIcon: Icon(Icons.timer),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: paceController,
            focusNode: paceFocus,
            decoration: const InputDecoration(
              labelText: 'Pace (optional, e.g. 5:30/km)',
              prefixIcon: Icon(Icons.speed),
              hintText: 'Auto-calculated if empty',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SessionBounce(
                  onTap: canLog ? onLogActivity : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: canLog
                          ? LinearGradient(
                              colors: [
                                AppColors.signal,
                                AppColors.signalDim,
                              ],
                            )
                          : null,
                      color: canLog
                          ? null
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: canLog
                            ? AppColors.signal
                            : Colors.white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isLogging
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'LOG ACTIVITY',
                              style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SessionBounce(
                onTap: isUploadingVoice ? null : onToggleRecording,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRecording
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.signal.withValues(alpha: 0.1),
                    border: Border.all(
                      color: isRecording
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.signal.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Semantics(
                    button: true,
                    label: isRecording
                        ? 'Stop Recording'
                        : 'Record Voice Note',
                    child: Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: isRecording ? AppColors.error : AppColors.signal,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

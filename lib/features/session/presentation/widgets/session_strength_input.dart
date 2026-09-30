import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/session_widgets.dart';
import 'session_room_animations.dart';

/// Strength set logging form (exercise / weight / reps / voice) — Z-ARCH-002.
class SessionStrengthInputSection extends StatelessWidget {
  const SessionStrengthInputSection({
    super.key,
    required this.recentExercises,
    required this.exerciseController,
    required this.weightController,
    required this.repsController,
    required this.weightFocus,
    required this.repsFocus,
    required this.currentExercise,
    required this.isLogging,
    required this.isRecording,
    required this.isUploadingVoice,
    required this.voiceUploadProgress,
    required this.recordingDuration,
    required this.amplitudeStream,
    required this.onExerciseChanged,
    required this.onExerciseSelected,
    required this.onLogSet,
    required this.onToggleRecording,
  });

  final List<String> recentExercises;
  final TextEditingController exerciseController;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final FocusNode weightFocus;
  final FocusNode repsFocus;
  final String? currentExercise;
  final bool isLogging;
  final bool isRecording;
  final bool isUploadingVoice;
  final double voiceUploadProgress;
  final Duration recordingDuration;
  final Stream<double> amplitudeStream;
  final ValueChanged<String?> onExerciseChanged;
  final ValueChanged<String> onExerciseSelected;
  final VoidCallback onLogSet;
  final VoidCallback onToggleRecording;

  @override
  Widget build(BuildContext context) {
    final canLog = currentExercise != null && !isLogging;

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              return recentExercises.where((String option) {
                return option.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                );
              });
            },
            onSelected: onExerciseSelected,
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              if (controller.text != exerciseController.text) {
                controller.text = exerciseController.text;
              }

              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                onChanged: (value) {
                  exerciseController.text = value;
                  onExerciseChanged(value.isNotEmpty ? value : null);
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: weightController,
                  focusNode: weightFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: repsController,
                  focusNode: repsFocus,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Log Amount',
                  hint: 'Adds this set to your workout',
                  child: SessionBounce(
                    onTap: canLog ? onLogSet : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      constraints: const BoxConstraints(minHeight: 56),
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
                                'LOG SET',
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
              ),
              const SizedBox(width: 12),
              if (isUploadingVoice)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: voiceUploadProgress > 0
                              ? voiceUploadProgress
                              : null,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(voiceUploadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontFamily: AppFonts.primary,
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isRecording)
                GestureDetector(
                  onTap: onToggleRecording,
                  child: RecordingWaveform(
                    amplitudeStream: amplitudeStream,
                    duration: recordingDuration,
                  ),
                )
              else
                SessionBounce(
                  onTap: onToggleRecording,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.signal.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.signal.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Record Voice Note',
                      child: Icon(
                        Icons.mic_rounded,
                        color: AppColors.signal,
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

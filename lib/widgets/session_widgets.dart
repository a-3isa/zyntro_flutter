import 'dart:async';
import 'package:flutter/material.dart';

import 'package:timeago/timeago.dart' as timeago;

import '../core/models/models.dart';
import '../core/constants/constants.dart';
import '../core/theme/app_theme.dart';
import 'fluttermoji_avatar.dart';

/// Display for session timer.
class SessionTimer extends StatelessWidget {
  final DateTime startTime;
  final SessionStatus status;
  final VoidCallback? onPauseResume;
  final bool isHost;

  const SessionTimer({
    super.key,
    required this.startTime,
    required this.status,
    this.onPauseResume,
    this.isHost = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final duration = DateTime.now().difference(startTime);
        final hours = duration.inHours.toString().padLeft(2, '0');
        final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status == SessionStatus.active
                      ? AppColors.success
                      : AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Timer Text
              Text(
                '$hours:$minutes:$seconds',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              if (isHost) ...[
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: onPauseResume,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      status == SessionStatus.active
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Participant avatar with online status indicator.
class ParticipantAvatar extends StatelessWidget {
  final String userId;
  final String? photoUrl;
  final String? avatarConfig;
  final String displayName;
  final bool isOnline;
  final bool isTyping;
  final double size;

  const ParticipantAvatar({
    super.key,
    required this.userId,
    this.photoUrl,
    this.avatarConfig,
    required this.displayName,
    this.isOnline = false,
    this.isTyping = false,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isTyping ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: FluttermojiAvatar(
            avatarConfig: avatarConfig,
            photoUrl: photoUrl,
            displayName: displayName,
            size: size - 4,
            showGradientBorder: false,
          ),
        ),

        // Online Indicator
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),

        // Typing Indicator
        if (isTyping)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_horiz, size: 8, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/// Timeline event item widget.
class TimelineItem extends StatelessWidget {
  final TimelineEvent event;
  final VoidCallback? onPlayVoiceNote;
  final bool isPlayingVoiceNote;
  final bool isLoadingAudio;
  final double? voiceNoteDuration; // Duration in seconds

  const TimelineItem({
    super.key,
    required this.event,
    this.onPlayVoiceNote,
    this.isPlayingVoiceNote = false,
    this.isLoadingAudio = false,
    this.voiceNoteDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEventIcon(context),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.text,
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  timeago.format(event.timestamp),
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (event.type == SessionEventType.voiceNote &&
                    onPlayVoiceNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: VoiceNoteWaveform(
                      duration: voiceNoteDuration,
                      isPlaying: isPlayingVoiceNote,
                      isLoading: isLoadingAudio,
                      onTap: onPlayVoiceNote,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventIcon(BuildContext context) {
    IconData icon;
    Color color;

    switch (event.type) {
      case SessionEventType.start:
        icon = Icons.flag;
        color = AppColors.success;
        break;
      case SessionEventType.finish:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case SessionEventType.join:
        icon = Icons.person_add;
        color = AppColors.secondary;
        break;
      case SessionEventType.leave:
        icon = Icons.person_remove;
        color = AppColors.error;
        break;
      case SessionEventType.exercise:
        icon = Icons.fitness_center;
        color = AppColors.primary;
        break;
      case SessionEventType.voiceNote:
        icon = Icons.mic;
        color = AppColors.warning;
        break;
      case SessionEventType.cheer:
        icon = Icons.emoji_events;
        color = AppColors.warmAccent;
        break;
      default:
        icon = Icons.info;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),

      child: Icon(icon, size: 16, color: color),
    );
  }
}

/// Helper function to format duration as MM:SS.
String formatVoiceNoteDuration(double seconds) {
  final mins = (seconds / 60).floor();
  final secs = (seconds % 60).floor();
  return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// Waveform visualization widget for voice notes.
/// Displays animated bars that respond to playback state.
class VoiceNoteWaveform extends StatefulWidget {
  final double? duration; // Duration in seconds
  final bool isPlaying;
  final VoidCallback? onTap;
  final bool isLoading;

  const VoiceNoteWaveform({
    super.key,
    this.duration,
    this.isPlaying = false,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<VoiceNoteWaveform> createState() => _VoiceNoteWaveformState();
}

class _VoiceNoteWaveformState extends State<VoiceNoteWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Static waveform pattern (8 bars with varying heights)
  static const List<double> _waveformPattern = [
    0.3,
    0.6,
    0.9,
    0.5,
    0.8,
    0.4,
    0.7,
    0.35,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isPlaying) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceNoteWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animationController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Stop icon
            if (widget.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange,
                ),
              )
            else
              Icon(
                widget.isPlaying ? Icons.stop : Icons.play_arrow,
                size: 20,
                color: Colors.orange,
              ),
            const SizedBox(width: 8),

            // Waveform bars
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_waveformPattern.length, (index) {
                    final baseHeight = _waveformPattern[index];
                    final animValue = widget.isPlaying
                        ? _animationController.value * 0.3
                        : 0.0;
                    // Offset animation for wave effect
                    final offset = (index % 2 == 0 ? animValue : -animValue);
                    final height = (baseHeight + offset).clamp(0.2, 1.0);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 3,
                      height: 20 * height,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 8),

            // Duration text
            Text(
              widget.isPlaying
                  ? 'Stop'
                  : widget.duration != null
                  ? formatVoiceNoteDuration(widget.duration!)
                  : 'Play',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recording waveform visualization widget.
/// Displays animated bars during active recording.
class RecordingWaveform extends StatefulWidget {
  final Stream<double>? amplitudeStream;
  final Duration duration;

  const RecordingWaveform({
    super.key,
    this.amplitudeStream,
    required this.duration,
  });

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final List<double> _amplitudeHistory = List.filled(10, 0.3);
  StreamSubscription<double>? _amplitudeSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _amplitudeSubscription = widget.amplitudeStream?.listen((amplitude) {
      if (mounted) {
        setState(() {
          _amplitudeHistory.removeAt(0);
          _amplitudeHistory.add(amplitude.clamp(0.1, 1.0));
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing recording indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(
                    alpha: 0.5 + (_pulseController.value * 0.5),
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Duration text
          Text(
            _formatDuration(widget.duration),
            style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'RobotoMono',
            ),
          ),
          const SizedBox(width: 12),

          // Amplitude waveform bars
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_amplitudeHistory.length, (index) {
              final height = _amplitudeHistory[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 3,
                height: 24 * height,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Animated progress bar with smooth value transitions and gradient colors.
/// Adds optional glow effect for high progress values and haptic feedback.
class AnimatedProgressBar extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final List<Color>? gradientColors;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool showGlowAtHighProgress;
  final Duration duration;
  final VoidCallback? onMilestone;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.gradientColors,
    this.backgroundColor,
    this.borderRadius,
    this.showGlowAtHighProgress = true,
    this.duration = const Duration(milliseconds: 300),
    this.onMilestone,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> {
  double _previousValue = 0;

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousValue = oldWidget.value;

    // Check for milestone thresholds (25%, 50%, 75%, 100%)
    final milestones = [0.25, 0.5, 0.75, 1.0];
    for (final milestone in milestones) {
      if (_previousValue < milestone && widget.value >= milestone) {
        widget.onMilestone?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.gradientColors ?? AppColors.primaryGradient;
    final backgroundColor =
        widget.backgroundColor ?? AppColors.surfaceSecondaryDark;
    final borderRadius =
        widget.borderRadius ?? BorderRadius.circular(widget.height / 2);
    final showGlow = widget.showGlowAtHighProgress && widget.value >= 0.8;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            // Background
            Container(color: backgroundColor),
            // Animated progress
            TweenAnimationBuilder<double>(
              tween: Tween(begin: _previousValue, end: widget.value),
              duration: widget.duration,
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animatedValue.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      borderRadius: borderRadius,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Milestone indicator widget displaying milestone markers with animations.
/// Shows checkmarks for completed milestones with pulsing glow effects.
class MilestoneIndicator extends StatelessWidget {
  final int currentValue;
  final List<int> milestones;
  final String? unit;
  final Color? activeColor;
  final Color? inactiveColor;

  const MilestoneIndicator({
    super.key,
    required this.currentValue,
    required this.milestones,
    this.unit,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? AppColors.primary;
    final inactive = inactiveColor ?? AppColors.surfaceSecondaryDark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: milestones.map((milestone) {
        final isCompleted = currentValue >= milestone;
        final isNext =
            !isCompleted &&
            (milestones.indexOf(milestone) == 0 ||
                currentValue >= milestones[milestones.indexOf(milestone) - 1]);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? active.withValues(alpha: 0.15)
                    : inactive.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? active
                      : isNext
                      ? active.withValues(alpha: 0.5)
                      : inactive,
                  width: isCompleted || isNext ? 2 : 1,
                ),
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: active.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, size: 16, color: active)
                    : Text(
                        '$milestone',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isNext ? active : AppColors.textSecondaryDark,
                        ),
                      ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(height: 4),
              Text(
                unit!,
                style: TextStyle(
                  fontSize: 9,
                  color: isCompleted ? active : AppColors.textTertiaryDark,
                ),
              ),
            ],
          ],
        );
      }).toList(),
    );
  }
}

/// Floating emoji widget that animates upward and fades out.
/// Used for cheer reactions in sessions.
class FloatingCheerEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback? onComplete;
  final Duration duration;

  const FloatingCheerEmoji({
    super.key,
    required this.emoji,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<FloatingCheerEmoji> createState() => _FloatingCheerEmojiState();
}

class _FloatingCheerEmojiState extends State<FloatingCheerEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.5,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 70),
    ]).animate(_controller);

    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -100),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _positionAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
        );
      },
    );
  }
}

/// Participant comparison bar chart for multi-user sessions.
/// Displays horizontal bars comparing each participant's progress.
class ParticipantComparisonChart extends StatelessWidget {
  final Map<String, double> participantValues;
  final Map<String, String> participantNames;
  final Map<String, Color>? participantColors;
  final String? unit;
  final double maxValue;

  const ParticipantComparisonChart({
    super.key,
    required this.participantValues,
    required this.participantNames,
    this.participantColors,
    this.unit,
    this.maxValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (participantValues.isEmpty) return const SizedBox.shrink();

    final effectiveMax = maxValue > 0
        ? maxValue
        : participantValues.values.reduce((a, b) => a > b ? a : b);

    final defaultColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: participantValues.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final userId = entry.value.key;
        final value = entry.value.value;
        final name = participantNames[userId] ?? 'User';
        final color =
            participantColors?[userId] ??
            defaultColors[index % defaultColors.length];
        final progress = effectiveMax > 0 ? (value / effectiveMax) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    unit != null
                        ? '${value.toStringAsFixed(1)}$unit'
                        : '$value',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, child) {
                  return Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: animatedValue.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.7)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

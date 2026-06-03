import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/models.dart';
import 'rep_counter_screen.dart';

enum _ActiveTurnPhase { ready, timing, reps, weight }

/// Full-screen widget shown to the active participant during their turn.
///
/// Drives a small state machine (ready -> timing -> reps -> weight) that
/// captures a single set for [exerciseName] and then hands the result back via
/// [onSetSubmit] before resetting to the ready phase.
class ActiveTurnScreen extends StatefulWidget {
  final String exerciseName;
  final int setNumber;
  final FutureOr<void> Function({
    required int reps,
    required double weight,
    required int durationSeconds,
  })
  onSetSubmit;
  final VoidCallback? onTurnEnd;
  final FutureOr<void> Function()? onTimerStart;
  final BotFriend? botFriend;
  final int lastReps;
  final double lastWeight;

  const ActiveTurnScreen({
    super.key,
    required this.exerciseName,
    required this.setNumber,
    required this.onSetSubmit,
    this.onTurnEnd,
    this.onTimerStart,
    this.botFriend,
    this.lastReps = 0,
    this.lastWeight = 0.0,
  });

  @override
  State<ActiveTurnScreen> createState() => _ActiveTurnScreenState();
}

class _ActiveTurnScreenState extends State<ActiveTurnScreen>
    with TickerProviderStateMixin {
  _ActiveTurnPhase _phase = _ActiveTurnPhase.ready;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  int _reps = 0;

  double _weight = 0.0;
  final FocusNode _weightFocus = FocusNode();

  // Pulse state for TIMING phase (toggled by the same ticking [_timer]).
  bool _pulseOn = false;

  // Rest timer — counts up after each submitted set, resets on START tap.
  Timer? _restTimer;
  Duration _restElapsed = Duration.zero;
  bool _isResting = false;

  late AnimationController _repBounceController;
  late Animation<double> _repBounceAnim;
  late Animation<Color?> _repColorAnim;

  static const List<double> _quickPicks = [40, 60, 80, 100, 120];
  static const List<double> _increments = [-10, -5, -2.5, 2.5, 5, 10];

  @override
  void initState() {
    super.initState();
    _weight = widget.lastWeight;
    _repBounceController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _repBounceAnim = _repBounceController.drive(
      CurveTween(curve: const _RepBounceScaleCurve()),
    );
    _repColorAnim =
        ColorTween(
          begin: AppColors.textV2Primary,
          end: AppColors.accentLime,
        ).animate(
          CurvedAnimation(parent: _repBounceController, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    _weightFocus.dispose();
    _repBounceController.dispose();
    super.dispose();
  }

  void _startTimer() {
    HapticFeedback.mediumImpact();
    final onTimerStart = widget.onTimerStart;
    if (onTimerStart != null) {
      unawaited(Future<void>.sync(onTimerStart));
    }
    // Stop rest timer and reset.
    _restTimer?.cancel();
    _restTimer = null;
    _elapsed = Duration.zero;
    _pulseOn = false;
    setState(() {
      _isResting = false;
      _restElapsed = Duration.zero;
      _phase = _ActiveTurnPhase.timing;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        _elapsed = Duration(seconds: _elapsed.inSeconds + 1);
        _pulseOn = !_pulseOn;
      });
    });
  }

  void _stopTimer() {
    if (_phase != _ActiveTurnPhase.timing) return;
    HapticFeedback.selectionClick();
    _timer?.cancel();
    _timer = null;
    setState(() => _phase = _ActiveTurnPhase.reps);
  }

  void _onRepsDone(int reps) {
    setState(() {
      _reps = reps;
      _phase = _ActiveTurnPhase.weight;
    });
    HapticFeedback.mediumImpact();
    _repBounceController.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _weightFocus.requestFocus();
    });
  }

  Future<void> _submitSet() async {
    if (_weight <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a weight before saving')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    await widget.onSetSubmit(
      reps: _reps,
      weight: _weight,
      durationSeconds: _elapsed.inSeconds,
    );
    if (!mounted) return;
    // Start rest timer between sets.
    _restTimer?.cancel();
    _restElapsed = Duration.zero;
    _isResting = true;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() => _restElapsed = Duration(seconds: _restElapsed.inSeconds + 1));
    });
    setState(() {
      _reps = 0;
      _elapsed = Duration.zero;
      _phase = _ActiveTurnPhase.ready;
      // Keep _weight for the next set so the user doesn't re-enter it
    });
  }

  String _formatDuration(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatWeight(double w) {
    if (w == w.truncateToDouble()) return w.toInt().toString();
    return w.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _ActiveTurnPhase.reps) {
      return RepCounterScreen(
        initialCount: widget.lastReps,
        onDone: _onRepsDone,
        botFriend: widget.botFriend,
      );
    }

    return ColoredBox(
      color: AppColors.backgroundV2,
      child: Column(
        children: <Widget>[
          _buildTopBar(),
          Expanded(child: _buildPhaseBody()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              widget.exerciseName,
              style: TextStyle(
                color: AppColors.textV2Secondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBody() {
    switch (_phase) {
      case _ActiveTurnPhase.ready:
        return _buildReady();
      case _ActiveTurnPhase.timing:
        return _buildTiming();
      case _ActiveTurnPhase.weight:
        return _buildWeight();
      case _ActiveTurnPhase.reps:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReady() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'SET ${widget.setNumber}',
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.textV2Tertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.exerciseName,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.textV2Primary,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isResting) ...[
                      _RestTimerDisplay(elapsed: _restElapsed),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 16),
                    if (widget.botFriend != null) ...[
                      _buildBotFixedValues(widget.botFriend!),
                      const SizedBox(height: 24),
                    ],
                    GestureDetector(
                      onTap: _startTimer,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentLime,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentLime.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 60,
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.40),
                              blurRadius: 32,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.backgroundV2,
                              size: 32,
                            ),
                            Text(
                              'START',
                              style: AppTextStyles.label.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.backgroundV2,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBotFixedValues(BotFriend bot) {
    final values = [
      '${bot.gymSetSeconds} sec',
      '${bot.gymReps} reps',
      '${_formatWeight(bot.gymWeightKg)} kg',
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceV2Active),
              ),
              child: Text(
                value,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.accentLime,
                  fontSize: 13,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTiming() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _stopTimer,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Outer pulse ring
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentLime.withValues(
                  alpha: _pulseOn ? 0.20 : 0.06,
                ),
                width: 1.5,
              ),
            ),
          ),
          // Inner pulse ring
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentLime.withValues(
                  alpha: _pulseOn ? 0.12 : 0.04,
                ),
                width: 1.0,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _formatDuration(_elapsed),
                style: AppTextStyles.display.copyWith(
                  color: AppColors.accentLime,
                  fontSize: 88,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: -5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'tap anywhere to stop',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textV2Tertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeight() {
    final textPrimary = AppColors.textV2Primary;
    final textSecondary = AppColors.textV2Secondary;
    final textTertiary = AppColors.textV2Tertiary;
    final surface = AppColors.surfaceV2;
    final surfaceActive = AppColors.surfaceV2Active;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Reps badge
                    AnimatedBuilder(
                      animation: _repBounceController,
                      builder: (BuildContext context, Widget? child) {
                        return Transform.scale(
                          scale: _repBounceAnim.value,
                          alignment: Alignment.centerLeft,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentLime.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.accentLime.withValues(
                                    alpha: 0.40,
                                  ),
                                ),
                              ),
                              child: Text(
                                '$_reps reps',
                                style: AppTextStyles.body.copyWith(
                                  color:
                                      _repColorAnim.value ??
                                      AppColors.accentLime,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Weight display
                    Text(
                      'Weight (kg)',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _formatWeight(_weight),
                        style: AppTextStyles.display.copyWith(
                          color: AppColors.accentLime,
                          fontSize: 60,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quick-pick row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickPicks.map((kg) {
                          final isSelected = _weight == kg;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _weight = kg);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accentLime
                                      : surfaceActive,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${kg.toInt()}',
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: isSelected
                                        ? AppColors.backgroundV2
                                        : textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Increment buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _increments.map((delta) {
                        final isPositive = delta > 0;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _weight = (_weight + delta).clamp(0.0, 999.0);
                              // Round to nearest 0.5
                              _weight = ((_weight * 2).round() / 2).toDouble();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? AppColors.accentLime.withValues(alpha: 0.12)
                                  : surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isPositive
                                    ? AppColors.accentLime.withValues(
                                        alpha: 0.30,
                                      )
                                    : surfaceActive,
                              ),
                            ),
                            child: Text(
                              isPositive ? '+$delta' : '$delta',
                              style: TextStyle(
                                color: isPositive
                                    ? AppColors.accentLime
                                    : textTertiary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Spacer(),
                    // Submit button
                    GestureDetector(
                      onTap: _submitSet,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.accentLime,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentLime.withValues(
                                alpha: 0.30,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Submit Set',
                            style: AppTextStyles.h5.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.backgroundV2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RestTimerDisplay extends StatelessWidget {
  final Duration elapsed;

  const _RestTimerDisplay({required this.elapsed});

  String _format(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'RESTING',
          style: TextStyle(
            color: AppColors.textV2Tertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _format(elapsed),
          style: AppTextStyles.display.copyWith(
            color: AppColors.textV2Secondary,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: -2,
          ),
        ),
      ],
    );
  }
}

class _RepBounceScaleCurve extends Curve {
  const _RepBounceScaleCurve();

  @override
  double transformInternal(double t) {
    if (t <= 0.4) {
      return 1 + (Curves.easeOut.transform(t / 0.4) * 0.18);
    }

    return 1.18 - (Curves.easeOut.transform((t - 0.4) / 0.6) * 0.18);
  }
}

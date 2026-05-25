import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
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
  final void Function({
    required int reps,
    required double weight,
    required int durationSeconds,
  }) onSetSubmit;
  final VoidCallback? onTurnEnd;

  const ActiveTurnScreen({
    super.key,
    required this.exerciseName,
    required this.setNumber,
    required this.onSetSubmit,
    this.onTurnEnd,
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

  late AnimationController _repBounceController;
  late Animation<double> _repBounceAnim;
  late Animation<Color?> _repColorAnim;

  static const List<double> _quickPicks = [40, 60, 80, 100, 120];
  static const List<double> _increments = [-10, -5, -2.5, 2.5, 5, 10];

  @override
  void initState() {
    super.initState();
    _repBounceController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _repBounceAnim = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.18),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.18, end: 1.0),
        weight: 60,
      ),
    ]).animate(
      CurvedAnimation(parent: _repBounceController, curve: AppCurves.spring),
    );
    _repColorAnim = ColorTween(
      begin: AppColors.textV2Primary,
      end: AppColors.accentLime,
    ).animate(
      CurvedAnimation(parent: _repBounceController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _weightFocus.dispose();
    _repBounceController.dispose();
    super.dispose();
  }

  void _startTimer() {
    HapticFeedback.mediumImpact();
    _elapsed = Duration.zero;
    _pulseOn = false;
    setState(() => _phase = _ActiveTurnPhase.timing);
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
      _weight = 0.0;
      _phase = _ActiveTurnPhase.weight;
    });
    HapticFeedback.mediumImpact();
    _repBounceController.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _weightFocus.requestFocus();
    });
  }

  void _submitSet() {
    HapticFeedback.mediumImpact();
    widget.onSetSubmit(
      reps: _reps,
      weight: _weight,
      durationSeconds: _elapsed.inSeconds,
    );
    setState(() {
      _reps = 0;
      _weight = 0.0;
      _elapsed = Duration.zero;
      _phase = _ActiveTurnPhase.ready;
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
      return RepCounterScreen(onDone: _onRepsDone);
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
          if (widget.onTurnEnd != null)
            TextButton(
              onPressed: widget.onTurnEnd,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textV2Secondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: AppColors.surfaceV2Active,
                  ),
                ),
              ),
              child: const Text(
                'Pass Turn',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'SET ${widget.setNumber}',
                    style: GoogleFonts.syne(
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
                    style: GoogleFonts.syne(
                      color: AppColors.textV2Primary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 48),
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
                            color: AppColors.accentLime.withValues(alpha: 0.35),
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
                            style: GoogleFonts.syne(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
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
        ],
      ),
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
                color: AppColors.accentLime
                    .withValues(alpha: _pulseOn ? 0.20 : 0.06),
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
                color: AppColors.accentLime
                    .withValues(alpha: _pulseOn ? 0.12 : 0.04),
                width: 1.0,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _formatDuration(_elapsed),
                style: GoogleFonts.syne(
                  color: AppColors.accentLime,
                  fontSize: 88,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'tap anywhere to stop',
                style: GoogleFonts.outfit(
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
    final textPrimary =
        AppColors.textV2Primary;
    final textSecondary =
        AppColors.textV2Secondary;
    final textTertiary =
        AppColors.textV2Tertiary;
    final surface = AppColors.surfaceV2;
    final surfaceActive =
        AppColors.surfaceV2Active;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentLime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.accentLime.withValues(alpha: 0.40),
                      ),
                    ),
                    child: Text(
                      '$_reps reps',
                      style: GoogleFonts.syne(
                        color: _repColorAnim.value ?? AppColors.accentLime,
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
              style: GoogleFonts.syne(
                color: AppColors.accentLime,
                fontSize: 60,
                fontWeight: FontWeight.w800,
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
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentLime
                            : surfaceActive,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${kg.toInt()}',
                        style: GoogleFonts.syne(
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
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AppColors.accentLime.withValues(alpha: 0.12)
                        : surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPositive
                          ? AppColors.accentLime.withValues(alpha: 0.30)
                          : surfaceActive,
                    ),
                  ),
                  child: Text(
                    isPositive ? '+$delta' : '$delta',
                    style: TextStyle(
                      color: isPositive ? AppColors.accentLime : textTertiary,
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
                    color: AppColors.accentLime.withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Submit Set',
                  style: GoogleFonts.syne(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.backgroundV2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

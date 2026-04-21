import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _ActiveTurnScreenState extends State<ActiveTurnScreen> {
  _ActiveTurnPhase _phase = _ActiveTurnPhase.ready;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  int _reps = 0;

  final TextEditingController _weightController = TextEditingController();
  final FocusNode _weightFocus = FocusNode();

  // Pulse state for TIMING phase (toggled by the same ticking [_timer]).
  bool _pulseOn = false;

  @override
  void dispose() {
    _timer?.cancel();
    _weightController.dispose();
    _weightFocus.dispose();
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
      _phase = _ActiveTurnPhase.weight;
    });
    // Auto-focus the weight field after the phase transition completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _weightFocus.requestFocus();
    });
  }

  void _submitSet() {
    final double? weight = double.tryParse(_weightController.text.trim());
    if (weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight')),
      );
      return;
    }
    final int duration = _elapsed.inSeconds;
    widget.onSetSubmit(
      reps: _reps,
      weight: weight,
      durationSeconds: duration,
    );
    // Reset for the next set.
    _weightController.clear();
    setState(() {
      _reps = 0;
      _elapsed = Duration.zero;
      _phase = _ActiveTurnPhase.ready;
    });
  }

  String _formatDuration(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // The reps phase delegates to a full-screen widget of its own.
    if (_phase == _ActiveTurnPhase.reps) {
      return RepCounterScreen(onDone: _onRepsDone);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(child: _buildPhaseBody()),
          ],
        ),
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
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
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
                foregroundColor: AppColors.textSecondaryDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(
                    color: AppColors.surfaceSecondaryDark,
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Set ${widget.setNumber}',
                    style: const TextStyle(
                      color: AppColors.textTertiaryDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.exerciseName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: _startTimer,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.backgroundDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'START',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            width: 2,
            color: AppColors.primary.withValues(alpha:_pulseOn ? 0.30 : 0.10),
          ),
          color: AppColors.surfaceDark.withValues(alpha:0.4),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 112,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap anywhere to stop',
                style: TextStyle(
                  color: AppColors.textTertiaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeight() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha:0.4),
                ),
              ),
              child: Text(
                '$_reps reps',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Weight (kg)',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _weightController,
            focusNode: _weightFocus,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitSet(),
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceDark,
              hintText: '0.0',
              hintStyle: TextStyle(
                color: AppColors.textTertiaryDark,
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.surfaceSecondaryDark,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _submitSet,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.backgroundDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Submit Set',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

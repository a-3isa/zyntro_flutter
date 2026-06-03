import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'rep_counter_screen.dart';

/// Partner metrics shown in the compact partner card while training
/// in parallel mode.
///
/// A [ParallelPartnerData] instance can describe either a cardio partner
/// (running/cycling/swimming/walking) or a gym partner - the consuming
/// view picks the fields it cares about based on [isCardioPartner].
class ParallelPartnerData {
  final String name;
  final String? photoUrl;
  final String workoutType; // 'running', 'cycling', 'gym', etc.

  // Cardio partner fields
  final double totalDistance; // km
  final String? averagePace; // e.g. "5:30/km"
  final Duration elapsedTime;

  // Gym partner fields
  final String? currentExercise;
  final int totalSets;
  final double totalVolume; // kg

  const ParallelPartnerData({
    required this.name,
    this.photoUrl,
    required this.workoutType,
    this.totalDistance = 0,
    this.averagePace,
    this.elapsedTime = Duration.zero,
    this.currentExercise,
    this.totalSets = 0,
    this.totalVolume = 0,
  });

  bool get isCardioPartner =>
      workoutType == 'running' ||
      workoutType == 'cycling' ||
      workoutType == 'swimming' ||
      workoutType == 'walking';
}

/// The gym-side UI shown in parallel mode - the logged-in participant
/// is lifting while their partner does something different (cardio or
/// their own gym flow). The partner's live data is rendered in the
/// bottom card.
class ParallelGymView extends StatefulWidget {
  /// Current exercise to log.
  final String exerciseName;
  final int setNumber;

  /// Callback when user submits a set.
  final void Function({
    required int reps,
    required double weight,
    required int durationSeconds,
  })
  onSetSubmit;

  /// Partner's real-time data (cardio partner or gym partner).
  final ParallelPartnerData partner;

  const ParallelGymView({
    super.key,
    required this.exerciseName,
    required this.setNumber,
    required this.onSetSubmit,
    required this.partner,
  });

  @override
  State<ParallelGymView> createState() => _ParallelGymViewState();
}

/// Internal phase machine for the embedded active-turn flow.
enum _GymPhase { idle, timing, counting, weighing }

class _ParallelGymViewState extends State<ParallelGymView> {
  _GymPhase _phase = _GymPhase.idle;

  // Timer state.
  Timer? _timer;
  int _elapsedSeconds = 0;

  // Captured results as the user moves through the flow.
  int _reps = 0;
  int _capturedDuration = 0;

  // Weight entry.
  final TextEditingController _weightController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _weightController.dispose();
    super.dispose();
  }

  void _startSet() {
    setState(() {
      _phase = _GymPhase.timing;
      _elapsedSeconds = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds += 1);
    });
  }

  void _finishTiming() {
    _timer?.cancel();
    setState(() {
      _capturedDuration = _elapsedSeconds;
      _phase = _GymPhase.counting;
    });
  }

  void _onRepsDone(int reps) {
    setState(() {
      _reps = reps;
      _phase = _GymPhase.weighing;
    });
  }

  void _submit() {
    final double weight = double.tryParse(_weightController.text.trim()) ?? 0;
    widget.onSetSubmit(
      reps: _reps,
      weight: weight,
      durationSeconds: _capturedDuration,
    );
    // Reset for next set.
    setState(() {
      _phase = _GymPhase.idle;
      _elapsedSeconds = 0;
      _reps = 0;
      _capturedDuration = 0;
      _weightController.clear();
    });
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundV2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double ownHeight = constraints.maxHeight * 0.60;
          final double partnerHeight = constraints.maxHeight * 0.40;
          return Column(
            children: [
              SizedBox(height: ownHeight, child: _buildOwnSection()),
              SizedBox(
                height: partnerHeight,
                child: _PartnerCard(
                  partner: widget.partner,
                  accentColor: AppColors.secondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOwnSection() {
    switch (_phase) {
      case _GymPhase.idle:
        return _buildIdleStart();
      case _GymPhase.timing:
        return _buildTimer();
      case _GymPhase.counting:
        return RepCounterScreen(onDone: _onRepsDone);
      case _GymPhase.weighing:
        return _buildWeightEntry();
    }
  }

  Widget _buildIdleStart() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Set ${widget.setNumber}',
            style: TextStyle(
              color: AppColors.textV2Tertiary,
              fontSize: 14,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.exerciseName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textV2Primary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 36),
          _GradientButton(
            label: 'START SET',
            gradient: AppColors.primaryGradient,
            onTap: _startSet,
          ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.exerciseName,
            style: TextStyle(
              color: AppColors.textV2Secondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceV2,
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              _formatDuration(_elapsedSeconds),
              style: TextStyle(
                color: AppColors.textV2Primary,
                fontSize: 48,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _GradientButton(
            label: 'DONE — COUNT REPS',
            gradient: AppColors.primaryGradient,
            onTap: _finishTiming,
          ),
        ],
      ),
    );
  }

  Widget _buildWeightEntry() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$_reps reps • ${_formatDuration(_capturedDuration)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textV2Secondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Weight (kg)',
            style: TextStyle(
              color: AppColors.textV2Tertiary,
              fontSize: 13,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(color: AppColors.textV2Primary, fontSize: 22),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceV2,
              hintText: '0.0',
              hintStyle: TextStyle(color: AppColors.textV2Tertiary),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _GradientButton(
            label: 'SUBMIT SET',
            gradient: AppColors.primaryGradient,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

/// Compact partner card shown at the bottom of parallel-mode screens.
class _PartnerCard extends StatelessWidget {
  final ParallelPartnerData partner;
  final Color accentColor;

  const _PartnerCard({required this.partner, required this.accentColor});

  String _formatDuration(Duration d) {
    final int totalSeconds = d.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _iconForWorkoutType(String type) {
    switch (type) {
      case 'running':
        return 'Running';
      case 'cycling':
        return 'Cycling';
      case 'swimming':
        return 'Swimming';
      case 'walking':
        return 'Walking';
      case 'gym':
        return 'Gym';
      default:
        return type.isEmpty
            ? 'Training'
            : '${type[0].toUpperCase()}${type.substring(1)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border(top: BorderSide(color: accentColor, width: 2)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Partner progress',
              style: TextStyle(
                color: AppColors.textV2Secondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceV2,
                  backgroundImage:
                      partner.photoUrl != null && partner.photoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(partner.photoUrl!)
                      : null,
                  child: partner.photoUrl == null || partner.photoUrl!.isEmpty
                      ? Text(
                          partner.name.isNotEmpty
                              ? partner.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: AppColors.textV2Primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    partner.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textV2Primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _iconForWorkoutType(partner.workoutType),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (partner.isCardioPartner)
              _buildCardioStats()
            else
              _buildGymStats(),
            const SizedBox(height: 8),
            const Text(
              'Shared time',
              style: TextStyle(
                color: AppColors.textV2Tertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardioStats() {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'DISTANCE',
            value: '${partner.totalDistance.toStringAsFixed(2)} km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(label: 'PACE', value: partner.averagePace ?? '—'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'TIME',
            value: _formatDuration(partner.elapsedTime),
          ),
        ),
      ],
    );
  }

  Widget _buildGymStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          partner.currentExercise ?? 'Resting',
          style: TextStyle(
            color: AppColors.textV2Primary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'SETS',
                value: partner.totalSets.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: 'VOLUME',
                value: '${partner.totalVolume.toStringAsFixed(0)} kg',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textV2Tertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textV2Primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

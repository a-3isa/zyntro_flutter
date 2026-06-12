import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'parallel_gym_view.dart'; // for ParallelPartnerData

/// The cardio-side UI shown in parallel mode - the logged-in participant
/// is running/cycling/swimming/walking while their partner does
/// something different. The partner's live data is rendered in the
/// bottom card.
class ParallelCardioView extends StatefulWidget {
  final String activityType; // 'running', 'cycling', 'swimming', 'walking'
  final void Function({
    required double distanceKm,
    required int durationSeconds,
    required String activityType,
  })
  onCardioLog;
  final ParallelPartnerData partner;

  const ParallelCardioView({
    super.key,
    required this.activityType,
    required this.onCardioLog,
    required this.partner,
  });

  @override
  State<ParallelCardioView> createState() => _ParallelCardioViewState();
}

class _ParallelCardioViewState extends State<ParallelCardioView> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _running = false;

  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _distanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _elapsedSeconds = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds += 1);
    });
  }

  void _logEntry() {
    final double distance =
        double.tryParse(_distanceController.text.trim()) ?? 0;
    widget.onCardioLog(
      distanceKm: distance,
      durationSeconds: _elapsedSeconds,
      activityType: widget.activityType,
    );
    // Reset timer and inputs for a fresh entry.
    _timer?.cancel();
    setState(() {
      _running = false;
      _elapsedSeconds = 0;
      _distanceController.clear();
      _notesController.clear();
    });
  }

  String _formatSeconds(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _activityLabel(String type) {
    switch (type) {
      case 'running':
        return 'Running';
      case 'cycling':
        return 'Cycling';
      case 'swimming':
        return 'Swimming';
      case 'walking':
        return 'Walking';
      default:
        return type.isEmpty
            ? 'Cardio'
            : '${type[0].toUpperCase()}${type.substring(1)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double ownHeight = constraints.maxHeight * 0.60;
            final double partnerHeight = constraints.maxHeight * 0.40;
            return Column(
              children: [
                SizedBox(height: ownHeight, child: _buildOwnSection()),
                SizedBox(
                  height: partnerHeight,
                  child: _CardioPartnerCard(
                    partner: widget.partner,
                    accentColor: AppColors.userAccent,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOwnSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.userAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.userAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _activityLabel(widget.activityType),
                style: TextStyle(
                  color: AppColors.userAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceV2,
                border: Border.all(
                  color: _running ? AppColors.userAccent : AppColors.secondary,
                  width: 3,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatSeconds(_elapsedSeconds),
                    style: TextStyle(
                      color: AppColors.textV2Primary,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _running ? 'RUNNING' : 'READY',
                    style: TextStyle(
                      color: AppColors.textV2Tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!_running)
            _GradientButton(
              label: 'START',
              gradient: AppColors.primaryGradient,
              onTap: _start,
            )
          else ...[
            Text(
              'Distance (km)',
              style: TextStyle(
                color: AppColors.textV2Tertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: AppColors.textV2Primary, fontSize: 18),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceV2,
                hintText: '0.0',
                hintStyle: TextStyle(color: AppColors.textV2Tertiary),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Notes (optional)',
              style: TextStyle(
                color: AppColors.textV2Tertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              style: TextStyle(color: AppColors.textV2Primary, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceV2,
                hintText: 'How did it feel?',
                hintStyle: TextStyle(color: AppColors.textV2Tertiary),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _GradientButton(
              label: 'LOG ENTRY',
              gradient: AppColors.primaryGradient,
              onTap: _logEntry,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact partner card tailored for the cardio-side view. The top
/// accent border uses [AppColors.userAccent] so the screen reads as the
/// participant's own cardio territory while still showing the partner.
class _CardioPartnerCard extends StatelessWidget {
  final ParallelPartnerData partner;
  final Color accentColor;

  const _CardioPartnerCard({required this.partner, required this.accentColor});

  String _formatDuration(Duration d) {
    final int totalSeconds = d.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _labelForWorkoutType(String type) {
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
                    _labelForWorkoutType(partner.workoutType),
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
              _buildRaceStats()
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

  Widget _buildRaceStats() {
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
        const SizedBox(height: 4),
        Text(
          '${partner.totalSets} sets',
          style: TextStyle(
            color: AppColors.textV2Secondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
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

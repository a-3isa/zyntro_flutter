import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Full-screen widget shown to the participant who is waiting for their turn.
///
/// Displays the partner's avatar (with a pulsing glow while their voice note
/// plays), a mirrored timer for the partner's active set, and a hold-to-record
/// voice button for quick coaching messages back.
class WaitingTurnScreen extends StatefulWidget {
  final String partnerName;
  final String? partnerPhotoUrl;
  final String partnerCurrentExercise;
  final int partnerSetNumber;
  final Duration partnerElapsedTime;
  final bool isPartnerVoicePlaying;
  final Future<void> Function() onRecordVoice;
  final bool isRecording;
  final Duration recordingDuration;

  const WaitingTurnScreen({
    super.key,
    required this.partnerName,
    this.partnerPhotoUrl,
    required this.partnerCurrentExercise,
    required this.partnerSetNumber,
    required this.partnerElapsedTime,
    required this.isPartnerVoicePlaying,
    required this.onRecordVoice,
    required this.isRecording,
    required this.recordingDuration,
  });

  @override
  State<WaitingTurnScreen> createState() => _WaitingTurnScreenState();
}

class _WaitingTurnScreenState extends State<WaitingTurnScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isPartnerVoicePlaying) {
      _glowController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaitingTurnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPartnerVoicePlaying && !_glowController.isAnimating) {
      _glowController.repeat();
    } else if (!widget.isPartnerVoicePlaying && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _initialsFor(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Future<void> _handleLongPressStart(LongPressStartDetails _) async {
    HapticFeedback.mediumImpact();
    await widget.onRecordVoice();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundV2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildPartnerHeader(),
              const SizedBox(height: 24),
              _buildTimerCard(),
              const Spacer(),
              Center(
                child: Text(
                  "Your turn is coming...",
                  style: TextStyle(
                    color: AppColors.textV2Tertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              _buildVoiceButton(),
            ],
          ),
        ),
      );
  }

  Widget _buildPartnerHeader() {
    return Column(
      children: <Widget>[
        _buildAvatarWithGlow(),
        const SizedBox(height: 14),
        Text(
          widget.partnerName,
          style: const TextStyle(
            color: AppColors.textV2Primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceV2Elevated,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${widget.partnerCurrentExercise} \u2014 Set ${widget.partnerSetNumber}',
            style: const TextStyle(
              color: AppColors.textV2Secondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithGlow() {
    const double avatarSize = 80;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (widget.isPartnerVoicePlaying)
            AnimatedBuilder(
              animation: _glowController,
              builder: (BuildContext context, Widget? _) {
                final double t =
                    Curves.easeInOut.transform(_glowController.value);
                final double size = avatarSize + (96 - avatarSize) * t;
                final double opacity = 0.8 * (1.0 - t);
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha:opacity),
                      width: 3,
                    ),
                  ),
                );
              },
            ),
          _buildAvatar(avatarSize),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size) {
    final String? url = widget.partnerPhotoUrl;
    final String initials = _initialsFor(widget.partnerName);

    final Widget fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.backgroundV2,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (BuildContext ctx, String url2) => Container(
            color: AppColors.surfaceV2Elevated,
          ),
          errorWidget:
              (BuildContext ctx, String url2, Object err) => fallback,
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.surfaceV2,
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            _formatDuration(widget.partnerElapsedTime),
            style: const TextStyle(
              color: AppColors.textV2Primary,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Partner's current set time",
            style: TextStyle(
              color: AppColors.textV2Tertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    final bool recording = widget.isRecording;
    final Color buttonColor =
        recording ? AppColors.error : AppColors.surfaceV2;
    final Color iconColor =
        recording ? AppColors.textV2Primary : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          recording
              ? 'Recording... ${_formatDuration(widget.recordingDuration)}'
              : 'Hold to send a voice note',
          style: TextStyle(
            color: recording
                ? AppColors.error
                : AppColors.textV2Secondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onLongPressStart: _handleLongPressStart,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: recording
                    ? AppColors.error
                    : AppColors.surfaceV2Elevated,
                width: 2,
              ),
              boxShadow: recording
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.error.withValues(alpha:0.45),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Icon(
              recording ? Icons.mic : Icons.mic_none_rounded,
              color: iconColor,
              size: 30,
            ),
          ),
        ),
      ],
    );
  }
}

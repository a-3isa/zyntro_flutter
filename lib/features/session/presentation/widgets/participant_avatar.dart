import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/turn_eligibility.dart';

/// A participant's avatar, rendered according to whether they are present,
/// temporarily away, or gone.
///
/// The three states must be visually distinct. A partner who stepped out for a
/// phone call is coming back; one who terminated is not. Showing them alike
/// would tell the member the wrong thing about their own workout.
///
/// The avatar is never removed, only treated — the member should still see who
/// they started with.
class ParticipantAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final ParticipantStanding standing;
  final double radius;

  const ParticipantAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.standing = ParticipantStanding.active,
    this.radius = 18,
  });

  bool get _hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// Dimmed for away, dimmer still for left.
  double get _opacity => switch (standing) {
    ParticipantStanding.active => 1,
    ParticipantStanding.away => 0.55,
    ParticipantStanding.left => 0.35,
  };

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceV2,
      backgroundImage: _hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null,
      child: _hasPhoto
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.textV2Primary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );

    if (standing == ParticipantStanding.active) return avatar;

    return Semantics(
      container: true,
      label: standing == ParticipantStanding.left
          ? '$name has left the session'
          : '$name is away',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Desaturated as well as dimmed, so the distinction survives for
          // anyone who cannot rely on a small opacity difference.
          Opacity(
            opacity: _opacity,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126, 0.7152, 0.0722, 0, 0, //
                0.2126, 0.7152, 0.0722, 0, 0, //
                0.2126, 0.7152, 0.0722, 0, 0, //
                0, 0, 0, 1, 0, //
              ]),
              child: avatar,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              key: Key(
                standing == ParticipantStanding.left
                    ? 'participant_left_badge'
                    : 'participant_away_badge',
              ),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.backgroundV2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                standing == ParticipantStanding.left
                    ? Icons.logout_rounded
                    : Icons.schedule_rounded,
                size: radius * 0.62,
                color: standing == ParticipantStanding.left
                    ? AppColors.textV2Secondary
                    : AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

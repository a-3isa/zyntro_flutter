import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_theme.dart';

/// Setup-phase waiting chip in the session header (Z-ARCH-002).
class SessionSetupWaitingChip extends StatelessWidget {
  const SessionSetupWaitingChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceV2Active),
      ),
      child: const Text(
        'Waiting for workout plans',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textV2Secondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Invite declined/expired attention chip (Z-ARCH-002).
class SessionInviteAttentionChip extends StatelessWidget {
  const SessionInviteAttentionChip({super.key, required this.status});

  final WorkoutInvitationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      WorkoutInvitationStatus.declined => AppColors.errorV2,
      WorkoutInvitationStatus.expired => Colors.orange,
      _ => AppColors.textV2Secondary,
    };
    final label = switch (status) {
      WorkoutInvitationStatus.declined =>
        'Friend declined — train solo or invite someone else',
      WorkoutInvitationStatus.expired =>
        'Invite expired — train solo or invite someone else',
      _ => 'Invite: ${status.value}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == WorkoutInvitationStatus.declined
                ? Icons.person_off_rounded
                : Icons.timer_off_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

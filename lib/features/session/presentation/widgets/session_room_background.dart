import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'session_room_animations.dart';

/// Ambient gradient/orb backdrop for the live session room (Z-ARCH-002).
class SessionRoomAnimatedBackground extends StatelessWidget {
  const SessionRoomAnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFF020617)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.signal.withValues(alpha: 0.05),
                Colors.transparent,
                AppColors.secondary.withValues(alpha: 0.03),
              ],
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -150,
          child: SessionPulse(
            duration: const Duration(seconds: 8),
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.signal.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -200,
          left: -200,
          child: SessionPulse(
            duration: const Duration(seconds: 12),
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

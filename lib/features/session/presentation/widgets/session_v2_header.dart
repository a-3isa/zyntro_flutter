import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/haptic_manager.dart';
import 'session_elapsed_timer_chip.dart';

/// C-style session top bar: avatars, elapsed timer, End (Z-ARCH-002).
class SessionV2Header extends StatelessWidget {
  const SessionV2Header({
    super.key,
    required this.elapsedListenable,
    required this.avatars,
    required this.onEnd,
  });

  final ValueNotifier<Duration> elapsedListenable;
  final Widget avatars;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final endButton = TextButton(
      onPressed: () {
        HapticManager.heavy();
        onEnd();
      },
      style: TextButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text(
        'End',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final timer = SessionElapsedTimerChip(elapsedListenable: elapsedListenable);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      color: AppColors.backgroundV2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactHeader = constraints.maxWidth < 420;
          if (isCompactHeader) {
            // Narrow: let the avatar/status cluster scroll horizontally rather
            // than squeeze, so the timer and End button stay put.
            return Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.42,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: avatars,
                  ),
                ),
                const Spacer(),
                timer,
                const Spacer(),
                const SizedBox(width: 8),
                endButton,
              ],
            );
          }
          return Row(
            children: [
              avatars,
              const Spacer(),
              timer,
              const Spacer(),
              const SizedBox(width: 8),
              endButton,
            ],
          );
        },
      ),
    );
  }
}

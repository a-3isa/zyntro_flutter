import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Compact elapsed-time chip for the session room header (Z-ARCH-002 /
/// Z-PERF-001). Isolated so timer ticks do not rebuild the whole header tree
/// beyond this [RepaintBoundary].
class SessionElapsedTimerChip extends StatelessWidget {
  const SessionElapsedTimerChip({super.key, required this.elapsedListenable});

  final ValueNotifier<Duration> elapsedListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: elapsedListenable,
      builder: (context, elapsed, _) {
        final h = elapsed.inHours;
        final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        final timeStr = h > 0 ? '$h:$m:$s' : '$m:$s';
        return RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 11,
                  color: AppColors.signal.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 5),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

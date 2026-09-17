import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Compact participant avatar in the session header (Z-ARCH-002).
class SessionHeaderAvatar extends StatelessWidget {
  const SessionHeaderAvatar({
    super.key,
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: active ? Border.all(color: AppColors.signal, width: 2) : null,
      ),
      padding: const EdgeInsets.all(2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.surfaceV2Active,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textV2Primary,
              ),
            ),
          ),
          if (active)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.accentEmerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.backgroundV2, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

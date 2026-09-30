import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// One participant's set column for an exercise in the progress board (Z-ARCH-002).
class SessionSetColumn extends StatelessWidget {
  const SessionSetColumn({
    super.key,
    required this.name,
    required this.active,
    required this.plannedSets,
    required this.loggedCount,
    required this.rowTexts,
  });

  final String name;
  final bool active;
  final int plannedSets;
  final int loggedCount;
  final List<String> rowTexts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: active
            ? AppColors.signal.withValues(alpha: 0.08)
            : AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppColors.signal.withValues(alpha: 0.4)
              : AppColors.borderDarkSecondary,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.accentEmerald
                      : AppColors.textV2Tertiary,
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active ? AppColors.signal : AppColors.textV2Primary,
                  ),
                ),
              ),
              Text(
                '${loggedCount.clamp(0, plannedSets)}/$plannedSets',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textV2Secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < plannedSets; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      'S${i + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textV2Tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      i < rowTexts.length ? rowTexts[i] : '—',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: i < loggedCount
                            ? AppColors.textV2Primary
                            : AppColors.textV2Tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

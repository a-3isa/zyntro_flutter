import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Side-by-side set columns under the session header (Z-ARCH-002).
class SessionProgressRow extends StatelessWidget {
  const SessionProgressRow({
    super.key,
    required this.exerciseName,
    required this.columns,
  });

  final String exerciseName;
  final List<Widget> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              exerciseName.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textV2Secondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: columns[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

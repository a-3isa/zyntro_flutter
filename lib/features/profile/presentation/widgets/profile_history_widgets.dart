import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/workout_type_visuals.dart';

/// Charts and lists for the profile's History tab.
///
/// Extracted from profile_page.dart, which had grown to 3,000 lines with these
/// three widgets accounting for roughly a third of it. They render session
/// history and depend on nothing from the page's state.

class WeeklyVolumeChart extends StatelessWidget {
  final List<Session> sessions;

  const WeeklyVolumeChart({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Build last 8 weeks: index 0 = oldest, index 7 = current week
    final List<int> weeklySets = List.filled(8, 0);
    final List<String> weekLabels = [];

    for (int w = 7; w >= 0; w--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + w * 7));
      final ws = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final we = ws.add(const Duration(days: 7));
      final idx = 7 - w;
      weeklySets[idx] = sessions
          .where((s) => s.startedAt.isAfter(ws) && s.startedAt.isBefore(we))
          .fold(0, (sum, s) => sum + (s.summary?.totalSets ?? 0));
      if (w == 0) {
        weekLabels.add('Now');
      } else if (w == 1) {
        weekLabels.add('W-1');
      } else {
        weekLabels.add('W-$w');
      }
    }
    // Reverse labels to match index order (oldest first)
    weekLabels.insertAll(0, List.generate(8, (i) => 'W-${7 - i}'));
    weekLabels.removeRange(8, weekLabels.length);
    weekLabels[7] = 'Now';

    final maxSets = weeklySets.fold(0, (m, v) => v > m ? v : m);

    // Week-over-week trend (last 2 weeks)
    final prevWeek = weeklySets[6];
    final currWeek = weeklySets[7];
    final trendStr = prevWeek == 0
        ? null
        : currWeek >= prevWeek
        ? '↑ ${(((currWeek - prevWeek) / prevWeek) * 100).round()}%'
        : '↓ ${(((prevWeek - currWeek) / prevWeek) * 100).round()}%';
    final trendColor = (currWeek >= prevWeek && prevWeek > 0)
        ? AppColors.signal
        : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SETS / WEEK',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              if (trendStr != null)
                Text(
                  trendStr,
                  style: AppTextStyles.h5.copyWith(
                    fontSize: 13,
                    color: trendColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(8, (i) {
                final isLast = i == 7;
                final isSecondLast = i == 6;
                final heightFactor = maxSets == 0
                    ? 0.05
                    : weeklySets[i] / maxSets;
                Color barColor;
                if (isLast) {
                  barColor = AppColors.signal;
                } else if (isSecondLast) {
                  barColor = AppColors.signal.withValues(alpha: 0.53);
                } else {
                  barColor = AppColors.surfaceV2Elevated;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: heightFactor.clamp(0.04, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekLabels[i],
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9,
                            fontWeight: isLast
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isLast
                                ? AppColors.signal
                                : AppColors.textV2Tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity Heatmap — real data
// ---------------------------------------------------------------------------

class ActivityHeatmap extends StatelessWidget {
  final List<Session> sessions;

  const ActivityHeatmap({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    const days = 7;
    final now = DateTime.now();

    // Build a set of dates that had at least one session
    final activeDates = <String>{};
    for (final s in sessions) {
      activeDates.add(DateFormat('yyyy-MM-dd').format(s.startedAt));
    }

    // Count sessions per day to determine intensity
    final Map<String, int> dayCounts = {};
    for (final s in sessions) {
      final key = DateFormat('yyyy-MM-dd').format(s.startedAt);
      dayCounts[key] = (dayCounts[key] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVITY — 12 WEEKS',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textV2Tertiary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day-of-week labels
              Column(
                children: List.generate(days, (d) {
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return SizedBox(
                    height: 13,
                    width: 10,
                    child: Center(
                      child: Text(
                        d.isEven ? labels[d] : '',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 8,
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 4),
              // Grid
              Expanded(
                child: Row(
                  children: List.generate(weeks, (w) {
                    // w=0 is oldest week, w=11 is current
                    final weeksAgo = weeks - 1 - w;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Column(
                          children: List.generate(days, (d) {
                            // Day 0 = Monday
                            final cellDate = now.subtract(
                              Duration(
                                days: now.weekday - 1 + weeksAgo * 7 - d,
                              ),
                            );
                            final dateKey = DateFormat(
                              'yyyy-MM-dd',
                            ).format(cellDate);
                            final count = dayCounts[dateKey] ?? 0;
                            final double alpha;
                            if (count == 0) {
                              alpha = 0.0;
                            } else if (count == 1) {
                              alpha = 0.4;
                            } else if (count == 2) {
                              alpha = 0.7;
                            } else {
                              alpha = 1.0;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 1.5,
                              ),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: alpha == 0.0
                                      ? AppColors.surfaceV2Elevated
                                      : AppColors.signal.withValues(
                                          alpha: alpha,
                                        ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '12 weeks ago',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              Text(
                'Today',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
              const SizedBox(width: 4),
              ...[0.0, 0.4, 0.7, 1.0].map(
                (a) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: a == 0.0
                        ? AppColors.surfaceV2Elevated
                        : AppColors.signal.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'More',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  color: AppColors.textV2Tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Sessions List — real data
// ---------------------------------------------------------------------------

class RecentSessionsList extends StatelessWidget {
  final List<Session> sessions;

  const RecentSessionsList({super.key, required this.sessions});

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(dt);
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return '';
    final d = end.difference(start);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          'No sessions yet',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textV2Tertiary,
          ),
        ),
      );
    }

    final recent = sessions.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT',
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textV2Tertiary,
          ),
        ),
        const SizedBox(height: 10),
        ...recent.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PressableRow(
              onTap: () => HapticFeedback.selectionClick(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundV2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        workoutTypeIcon(s.type),
                        size: 20,
                        color: AppColors.typeColor(s.type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title.isNotEmpty ? s.title : s.type,
                            style: AppTextStyles.h5.copyWith(
                              fontSize: 14,
                              color: AppColors.textV2Primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              _formatRelativeDate(s.startedAt),
                              if (s.endedAt != null)
                                _formatDuration(s.startedAt, s.endedAt),
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.textV2Secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${s.summary?.totalSets ?? 0}',
                          style: AppTextStyles.h5.copyWith(
                            fontSize: 14,
                            color: AppColors.textV2Primary,
                          ),
                        ),
                        Text(
                          'SETS',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9,
                            color: AppColors.textV2Tertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// Awards Tab
// ---------------------------------------------------------------------------

class PressableRow extends StatefulWidget {
  const PressableRow({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<PressableRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? AppAnimations.cardPressScale : 1.0,
        duration: AppDurations.fast,
        curve: AppCurves.press,
        child: widget.child,
      ),
    );
  }
}

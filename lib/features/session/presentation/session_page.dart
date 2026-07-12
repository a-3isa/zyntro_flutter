import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/navigation/app_router.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/zyntro_button.dart';
import '../../auth/auth_providers.dart';
import '../../../services/user_service.dart';
import '../../../services/session_service.dart';

// ── WorkoutType color map ────────────────────────────────────────────────────
Color _typeColor(WorkoutType t) {
  switch (t) {
    case WorkoutType.gym:
      return AppColors.userAccent;
    case WorkoutType.running:
      return const Color(0xFF38BDF8);
    case WorkoutType.cycling:
      return const Color(0xFF34D399);
    case WorkoutType.swimming:
      return const Color(0xFF22D3EE);
    case WorkoutType.yoga:
      return const Color(0xFFA78BFA);
    case WorkoutType.hiit:
      return const Color(0xFFFB923C);
    default:
      return AppColors.userAccent;
  }
}

IconData _typeIcon(WorkoutType t) {
  switch (t) {
    case WorkoutType.gym:
      return Icons.fitness_center_rounded;
    case WorkoutType.running:
      return Icons.directions_run_rounded;
    case WorkoutType.cycling:
      return Icons.directions_bike_rounded;
    case WorkoutType.swimming:
      return Icons.pool_rounded;
    case WorkoutType.yoga:
      return Icons.self_improvement_rounded;
    case WorkoutType.hiit:
      return Icons.timer_rounded;
    case WorkoutType.walking:
      return Icons.directions_walk_rounded;
    case WorkoutType.sports:
      return Icons.sports_soccer_rounded;
    default:
      return Icons.category_rounded;
  }
}

// Quick-start types shown in the 3-col grid (first 6)
const _quickStartTypes = [
  WorkoutType.gym,
  WorkoutType.running,
  WorkoutType.hiit,
  WorkoutType.cycling,
  WorkoutType.yoga,
  WorkoutType.swimming,
];

/// Train tab home screen.
class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);
    final uid = authState.value?.id;

    // Load recent sessions
    final recentAsync = uid != null
        ? ref.watch(_recentSessionsProvider(uid))
        : const AsyncValue<List<_RecentSession>>.data([]);

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Train',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ),

            // Body
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Weekly ring card
                  _WeeklyRingCard(uid: uid),
                  const SizedBox(height: 16),

                  // Start Session button — premium variant signals high-energy CTA.
                  ZyntroButton(
                    title: 'Start Session',
                    variant: ZyntroButtonVariant.premium,
                    size: ZyntroButtonSize.lg,
                    fullWidth: true,
                    leftIcon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () {
                      HapticManager.medium();
                      context.push(AppRoutes.startSession);
                    },
                  ),
                  const SizedBox(height: 28),

                  // QUICK START section
                  Text(
                    'QUICK START',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Tertiary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: _quickStartTypes.length,
                    itemBuilder: (context, i) {
                      final type = _quickStartTypes[i];
                      return GestureDetector(
                        onTap: () {
                          HapticManager.light();
                          context.push(
                            '${AppRoutes.startSession}?type=${type.value}',
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceV2,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceV2Elevated,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _typeIcon(type),
                                  size: 20,
                                  color: _typeColor(type),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                type.displayName,
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textV2Secondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Secondary CTA — links to full workout history (primary variant).
                  ZyntroButton(
                    title: 'Explore Workouts',
                    variant: ZyntroButtonVariant.primary,
                    size: ZyntroButtonSize.md,
                    fullWidth: true,
                    onPressed: () => context.push(AppRoutes.startSession),
                  ),
                  const SizedBox(height: 28),

                  // RECENT section
                  Text(
                    'RECENT',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Tertiary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  recentAsync.when(
                    data: (sessions) => sessions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No sessions yet. Start your first one!',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textV2Tertiary,
                              ),
                            ),
                          )
                        : Column(
                            children: sessions
                                .map((s) => _RecentSessionRow(session: s))
                                .toList(),
                          ),
                    loading: () => Column(
                      children: List.generate(
                        3,
                        (_) => const _RecentSessionSkeleton(),
                      ),
                    ),
                    error: (_, e) => const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent sessions provider ─────────────────────────────────────────────────

class _RecentSession {
  final WorkoutType type;
  final String label;
  final String dateLabel;
  final String duration;
  final int sets;

  const _RecentSession({
    required this.type,
    required this.label,
    required this.dateLabel,
    required this.duration,
    required this.sets,
  });
}

final _recentSessionsProvider =
    FutureProvider.family<List<_RecentSession>, String>((ref, uid) async {
  final sessions = await ref
      .watch(sessionServiceProvider)
      .getUserSessions(uid, limit: 10);
  return sessions.map((s) {
    final dur = s.endedAt != null
        ? s.endedAt!.difference(s.startedAt)
        : Duration.zero;
    final mins = dur.inMinutes;
    final durationLabel = mins >= 60
        ? '${dur.inHours}h ${mins.remainder(60)}m'
        : '${mins}m';
    final type = WorkoutType.values.firstWhere(
      (t) => t.value == s.type,
      orElse: () => WorkoutType.gym,
    );
    final sets = s.summary?.totalSets ?? 0;
    final dateLabel = _formatSessionDate(s.createdAt);
    return _RecentSession(
      type: type,
      label: s.title.isNotEmpty ? s.title : type.displayName,
      dateLabel: dateLabel,
      duration: durationLabel,
      sets: sets,
    );
  }).toList();
});

String _formatSessionDate(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}';
}

// ── Weekly ring card ─────────────────────────────────────────────────────────

class _WeeklyRingCard extends ConsumerWidget {
  final String? uid;
  const _WeeklyRingCard({this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync =
        uid != null ? ref.watch(userStreakProvider(uid!)) : null;
    final userStreak = streakAsync?.value;
    const goal = 5;
    final done = userStreak?.weeklyWorkouts ?? 0;
    final streak = userStreak?.currentStreak ?? 0;
    final total = userStreak?.totalWorkouts ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(108, 108),
                  painter: _RingPainter(
                    done: done,
                    total: goal,
                    trackColor: AppColors.surfaceV2Elevated,
                    progressColor: AppColors.userAccent,
                    strokeWidth: 5,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$done',
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    Text(
                      'of $goal',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THIS WEEK',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Tertiary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$done sessions',
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Primary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$streak',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                      Text(
                        'streak',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$total',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                      Text(
                        'total',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textV2Tertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int done;
  final int total;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _RingPainter({
    required this.done,
    required this.total,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - strokeWidth;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Track (full circle)
    canvas.drawCircle(Offset(cx, cy), r, trackPaint);

    // Progress arc: starts at -90 degrees (top)
    final sweep = total > 0 ? (done / total) * 2 * math.pi : 0.0;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.done != done || old.total != total;
}

// ── Recent session row ────────────────────────────────────────────────────────

class _RecentSessionRow extends StatelessWidget {
  final _RecentSession session;
  const _RecentSessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceV2, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _typeIcon(session.type),
              size: 20,
              color: _typeColor(session.type),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.label,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textV2Primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.dateLabel} · ${session.duration}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${session.sets} sets',
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSessionSkeleton extends StatelessWidget {
  const _RecentSessionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceV2, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 13, color: AppColors.surfaceV2),
                const SizedBox(height: 6),
                Container(width: 80, height: 10, color: AppColors.surfaceV2),
              ],
            ),
          ),
          Container(width: 40, height: 12, color: AppColors.surfaceV2),
        ],
      ),
    );
  }
}

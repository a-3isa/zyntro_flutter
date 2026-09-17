import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/zyntro_button.dart';
import '../../domain/gym_session_plan.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textV2Tertiary,
        letterSpacing: 2,
      ),
    );
  }
}

class StartSessionExercisePlanRow extends StatelessWidget {
  final PlannedExercise item;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<int> onSetsChanged;

  const StartSessionExercisePlanRow({
    required super.key,
    required this.item,
    required this.index,
    required this.onDelete,
    required this.onSetsChanged,
  });

  @override
  Widget build(BuildContext context) {
    const t1 = AppColors.textV2Primary;
    const t3 = AppColors.textV2Tertiary;
    const s1 = AppColors.surfaceV2;
    const s3 = AppColors.surfaceV2Active;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.errorV2,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: s1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              '${index + 1}',
              style: AppTextStyles.label.copyWith(fontSize: 13, color: t3),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: t1,
                ),
              ),
            ),
            // Sets pill picker 1–6
            Row(
              children: List.generate(6, (i) {
                final n = i + 1;
                final isActive = item.plannedSets == n;
                return GestureDetector(
                  onTap: () => onSetsChanged(n),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.signal : s3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.backgroundV2 : t3,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Icon(Icons.drag_handle, color: t3, size: 18),
          ],
        ),
      ),
    );
  }
}

class StartSessionRingPainter extends CustomPainter {
  final double progress;

  const StartSessionRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;
    const strokeWidth = 8.0;
    const startAngle = -math.pi / 2;
    const sweepFull = 2 * math.pi;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepFull,
      false,
      Paint()
        ..color = AppColors.progressTrack
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Progress arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepFull * progress,
        false,
        Paint()
          ..color = AppColors.accentLime
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(StartSessionRingPainter old) => old.progress != progress;
}

class StartSessionPastWorkoutsSheet extends StatefulWidget {
  const StartSessionPastWorkoutsSheet({super.key, required this.sessions});

  final List<Session> sessions;

  @override
  State<StartSessionPastWorkoutsSheet> createState() =>
      _StartSessionPastWorkoutsSheetState();
}

class _StartSessionPastWorkoutsSheetState
    extends State<StartSessionPastWorkoutsSheet> {
  int? _selected;

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Active,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Load a past workout?',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textV2Primary,
                fontSize: 20,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Pick a workout to load into your plan, then tweak or start it as-is.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textV2Secondary,
                height: 1.4,
              ),
            ),
          ),
          ...widget.sessions.asMap().entries.map((entry) {
            final i = entry.key;
            final session = entry.value;
            final exercises = session.summary?.exercises ?? [];
            final isSelected = _selected == i;
            return GestureDetector(
              onTap: () => setState(() => _selected = isSelected ? null : i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.signal.withValues(alpha: 0.1)
                      : AppColors.surfaceV2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.signal
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title.isNotEmpty
                                ? session.title
                                : 'Gym Session',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textV2Primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _relativeDate(session.createdAt),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textV2Secondary,
                            ),
                          ),
                          if (exercises.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              exercises.map((e) => e.name).join(' · '),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textV2Secondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.signal,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ZyntroButton(
              title: 'Load',
              fullWidth: true,
              variant: ZyntroButtonVariant.primary,
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(context, widget.sessions[_selected!]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: ZyntroButton(
              title: 'Start from scratch',
              fullWidth: true,
              variant: ZyntroButtonVariant.ghost,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

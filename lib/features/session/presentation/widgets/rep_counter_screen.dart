import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Full-screen tap-to-count rep counter.
///
/// The entire body is a [GestureDetector] that increments [_repCount] on each
/// tap. A pinned bottom "Done" button reports the final count via [onDone].
class RepCounterScreen extends StatefulWidget {
  final int initialCount;
  final void Function(int reps) onDone;

  const RepCounterScreen({
    super.key,
    this.initialCount = 0,
    required this.onDone,
  });

  @override
  State<RepCounterScreen> createState() => _RepCounterScreenState();
}

class _RepCounterScreenState extends State<RepCounterScreen>
    with SingleTickerProviderStateMixin {
  late int _repCount;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _repCount = widget.initialCount;
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _bounceAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    setState(() => _repCount += 1);
    _bounceController.forward(from: 0.0);
  }

  void _undo() {
    if (_repCount == 0) return;
    HapticFeedback.lightImpact();
    setState(() => _repCount -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final bool canFinish = _repCount > 0;

    return ColoredBox(
      color: AppColors.backgroundV2,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ScaleTransition(
                      scale: _bounceAnimation,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          color: _repCount == 0
                              ? AppColors.textV2Tertiary
                              : AppColors.accentLime,
                          fontSize: _repCount == 0 ? 40.0 : 108.0,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          letterSpacing: -4,
                        ),
                        child: Text(_repCount == 0 ? 'TAP' : '$_repCount'),
                      ),
                    ),
                    if (_repCount > 0) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'reps',
                        style: TextStyle(
                          color: AppColors.textV2Secondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: _repCount > 0
                      ? AppColors.surfaceV2
                      : AppColors.surfaceV2.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _undo,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.undo_rounded,
                            color: _repCount > 0
                                ? AppColors.textV2Secondary
                                : AppColors.textV2Tertiary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Undo',
                            style: TextStyle(
                              color: _repCount > 0
                                  ? AppColors.textV2Secondary
                                  : AppColors.textV2Tertiary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: canFinish ? () => widget.onDone(_repCount) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.surfaceV2Elevated,
                      foregroundColor: AppColors.backgroundV2,
                      disabledForegroundColor: AppColors.textV2Tertiary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      canFinish
                          ? 'Save — $_repCount ${_repCount == 1 ? "rep" : "reps"} ✓'
                          : 'Save reps',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }
}

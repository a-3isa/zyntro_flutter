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

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() => _repCount = 0);
  }

  @override
  Widget build(BuildContext context) {
    final bool canFinish = _repCount > 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
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
                      child: Text(
                        '$_repCount',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 180,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          letterSpacing: -4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'REPS',
                      style: TextStyle(
                        color: AppColors.textTertiaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Tap anywhere to count',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: AppColors.surfaceDark,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _reset,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: AppColors.textDark,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
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
                          AppColors.surfaceSecondaryDark,
                      foregroundColor: AppColors.backgroundDark,
                      disabledForegroundColor: AppColors.textTertiaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.check_rounded, size: 20),
                      ],
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

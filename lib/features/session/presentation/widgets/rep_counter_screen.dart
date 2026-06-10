import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/models.dart';

/// Full-screen tap-to-count rep counter.
///
/// The entire body is a [GestureDetector] that increments [_repCount] on each
/// tap. A pinned bottom "Done" button reports the final count via [onDone].
class RepCounterScreen extends StatefulWidget {
  final int initialCount;
  final void Function(int reps) onDone;
  final BotFriend? botFriend;

  const RepCounterScreen({
    super.key,
    this.initialCount = 0,
    required this.onDone,
    this.botFriend,
  });

  @override
  State<RepCounterScreen> createState() => _RepCounterScreenState();
}

class _RepCounterScreenState extends State<RepCounterScreen>
    with SingleTickerProviderStateMixin {
  late int _repCount;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late Animation<Color?> _repColorAnim;

  @override
  void initState() {
    super.initState();
    _repCount = widget.initialCount;
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    // CurveTween.transform(0.0) short-circuits to 0.0 in Flutter, which would
    // make the pre-filled count invisible (scale=0) until the first tap fires
    // forward(from:0). Starting at 1.0 keeps the number visible at rest.
    if (widget.initialCount > 0) {
      _bounceController.value = 1.0;
    }
    _bounceAnimation = _bounceController.drive(
      CurveTween(curve: const _RepBounceScaleCurve()),
    );
    _repColorAnim = ColorTween(
      begin: AppColors.textV2Primary,
      end: AppColors.accentLime,
    ).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
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
    final bot = widget.botFriend;

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
                    AnimatedBuilder(
                      animation: _bounceController,
                      builder: (BuildContext context, Widget? child) {
                        return Transform.scale(
                          scale: _bounceAnimation.value,
                          child: _repCount == 0
                              ? Text(
                                  'TAP',
                                  style: AppTextStyles.h1.copyWith(
                                    color: AppColors.textV2Tertiary,
                                    letterSpacing: -3,
                                    height: 1,
                                  ),
                                )
                              : Text(
                                  '$_repCount',
                                  style: AppTextStyles.display.copyWith(
                                    fontSize: 80,
                                    color: _repColorAnim.value ?? AppColors.textV2Primary,
                                    letterSpacing: -3,
                                    height: 1,
                                  ),
                                ),
                        );
                      },
                    ),
                    if (_repCount == 0) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        'tap to enter reps',
                        style: TextStyle(
                          color: AppColors.textV2Tertiary,
                          fontSize: 14,
                        ),
                      ),
                    ],
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
                    if (bot != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        'Bot completed ${bot.gymReps} reps @ ${_formatWeight(bot.gymWeightKg)} kg',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.accentLime,
                          fontWeight: FontWeight.w700,
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
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 64,
                    height: 56,
                    child: FilledButton(
                      onPressed: _repCount > 0 ? _undo : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceV2Elevated,
                        disabledBackgroundColor:
                            AppColors.surfaceV2Elevated.withValues(alpha: 0.4),
                        foregroundColor: AppColors.textV2Primary,
                        disabledForegroundColor: AppColors.textV2Tertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '-1',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: canFinish ? () => widget.onDone(_repCount) : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.surfaceV2Elevated,
                          foregroundColor: AppColors.backgroundV2,
                          disabledForegroundColor: AppColors.textV2Tertiary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          canFinish
                              ? 'Save $_repCount ${_repCount == 1 ? "rep" : "reps"}'
                              : 'Save reps',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(double weight) {
    if (weight == weight.truncateToDouble()) return weight.toInt().toString();
    return weight.toString();
  }
}

class _RepBounceScaleCurve extends Curve {
  const _RepBounceScaleCurve();

  @override
  double transformInternal(double t) {
    if (t <= 0.4) {
      return 1 + (Curves.easeOut.transform(t / 0.4) * 0.18);
    }

    return 1.18 - (Curves.easeOut.transform((t - 0.4) / 0.6) * 0.18);
  }
}

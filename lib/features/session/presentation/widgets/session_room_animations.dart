import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Animation and progress widgets used by the live session room.
///
/// These were declared at the bottom of session_room_page.dart, where three of
/// them collided by name with widgets in lib/widgets/: PulseAnimation and
/// BounceAnimation also exist in premium_animations.dart, and
/// AnimatedProgressBar also exists in session_widgets.dart — which the session
/// room imports. A locally declared class shadows an imported one, so editing
/// the shared AnimatedProgressBar would silently not affect this screen.
///
/// They are renamed here to session-specific names so nothing shadows anything.
/// The implementations are unchanged.

class SessionPulse extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const SessionPulse({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<SessionPulse> createState() => _SessionPulseState();
}

class _SessionPulseState extends State<SessionPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _fadeAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: widget.child),
        );
      },
    );
  }
}

/// Horizontal exercise-plan progress strip.
/// Shows labeled dots for up to [totalExercises] exercises;
/// dots for [completedExercises] are filled lime.
class PlanProgressBar extends StatelessWidget {
  final int completedExercises;
  final int totalExercises;

  const PlanProgressBar({
    super.key,
    required this.completedExercises,
    required this.totalExercises,
  });

  @override
  Widget build(BuildContext context) {
    if (totalExercises == 0) return const SizedBox.shrink();
    final completed = completedExercises.clamp(0, totalExercises);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppColors.surfaceV2,
      child: Row(
        children: [
          Text(
            'PLAN',
            style: TextStyle(
              color: AppColors.textV2Tertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: List.generate(totalExercises, (i) {
                final done = i < completed;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.userAccent
                            : (AppColors.surfaceV2Active),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$completed/$totalExercises',
            style: TextStyle(
              color: AppColors.userAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SessionProgressBar extends StatelessWidget {
  final double value;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;

  const SessionProgressBar({
    super.key,
    required this.value,
    this.backgroundColor = Colors.grey,
    this.foregroundColor = Colors.blue,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: constraints.maxWidth * value,
                height: height,
                decoration: BoxDecoration(
                  color: foregroundColor,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SessionBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  const SessionBounce({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<SessionBounce> createState() => _SessionBounceState();
}

class _SessionBounceState extends State<SessionBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) => _bounceController.forward();

  void _handleTapUp(TapUpDetails details) {
    _bounceController.reverse().then((_) => widget.onTap?.call());
  }

  void _handleTapCancel() => _bounceController.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: widget.child),
      ),
    );
  }
}

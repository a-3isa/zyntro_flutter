import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/models/models.dart';
import '../utils/haptic_manager.dart';
import '../utils/responsive_utils.dart';
import 'premium_effects.dart';

/// Reusable reaction buttons widget displaying 3 reaction types:
/// fire, strong, and clap.
class ReactionButtons extends StatefulWidget {
  final String postId;
  final ReactionType? currentReaction;
  final Map<ReactionType, int> reactionCounts;
  final Function(ReactionType) onReactionTap;
  final bool isLoading;

  const ReactionButtons({
    super.key,
    required this.postId,
    required this.currentReaction,
    required this.reactionCounts,
    required this.onReactionTap,
    this.isLoading = false,
  });

  @override
  State<ReactionButtons> createState() => _ReactionButtonsState();
}

class _ReactionButtonsState extends State<ReactionButtons>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  ReactionType? _animatingType;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation =
        Tween<double>(
          begin: 1.0,
          end: AppAnimations.reactionBounceScale,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.elasticOut,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap(ReactionType type) {
    if (widget.isLoading) return;

    // Trigger enhanced haptic feedback
    HapticManager.medium();

    // Animate the tapped button
    setState(() => _animatingType = type);
    _animationController.forward().then((_) {
      _animationController.reverse().then((_) {
        if (mounted) setState(() => _animatingType = null);
      });
    });

    // Trigger particle burst effect
    _showParticleBurst(type);

    widget.onReactionTap(type);
  }

  void _showParticleBurst(ReactionType type) {
    final colors = _getGradientColors(type);
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final center = position + Offset(size.width / 2, size.height / 2);

    final entry = OverlayEntry(
      builder: (context) => _ParticleBurst(
        center: center,
        color: colors.first,
        onComplete: () {},
      ),
    );

    overlay.insert(entry);

    // Remove after animation completes
    Future.delayed(const Duration(milliseconds: 600), () {
      entry.remove();
    });
  }

  // Get gradient colors for selected reaction
  List<Color> _getGradientColors(ReactionType type) {
    switch (type) {
      case ReactionType.fire:
        return [Colors.orange, Colors.deepOrange];
      case ReactionType.strong:
        return [Colors.purple, Colors.deepPurple];
      case ReactionType.clap:
        return [Colors.amber, Colors.orange];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Responsive sizing
    final isSmallScreen =
        MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
    final buttonPadding = isSmallScreen
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          )
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          );
    final emojiSize = isSmallScreen ? 18.0 : 20.0;
    final spacing = isSmallScreen ? AppSpacing.xs : AppSpacing.sm;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReactionButton(
            type: ReactionType.fire,
            emoji: '🔥',
            color: Colors.orange,
            label: 'Fire',
            isDark: isDark,
            buttonPadding: buttonPadding,
            emojiSize: emojiSize,
          ),
          SizedBox(width: spacing),
          _buildReactionButton(
            type: ReactionType.strong,
            emoji: '💪',
            color: Colors.purple,
            label: 'Strong',
            isDark: isDark,
            buttonPadding: buttonPadding,
            emojiSize: emojiSize,
          ),
          SizedBox(width: spacing),
          _buildReactionButton(
            type: ReactionType.clap,
            emoji: '👏',
            color: Colors.amber,
            label: 'Clap',
            isDark: isDark,
            buttonPadding: buttonPadding,
            emojiSize: emojiSize,
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButton({
    required ReactionType type,
    required String emoji,
    required Color color,
    required String label,
    required bool isDark,
    required EdgeInsets buttonPadding,
    required double emojiSize,
  }) {
    final isSelected = widget.currentReaction == type;
    final count = widget.reactionCounts[type] ?? 0;
    final isAnimating = _animatingType == type;

    Widget button = GestureDetector(
      onTap: () => _handleTap(type),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final scale = isAnimating ? _scaleAnimation.value : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: buttonPadding,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.neonGreen.withValues(alpha: 0.14),
                      AppColors.neonGreen.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(
              color: isSelected
                  ? AppColors.neonGreen
                  : AppColors.gray400.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: TextStyle(
                  fontSize: emojiSize,
                  color: isSelected ? color : null,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                AnimatedCounter(
                  value: count,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? color
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      label: '$label reaction${count > 0 ? ', $count reactions' : ''}',
      button: true,
      selected: isSelected,
      child: button,
    );
  }
}

/// Lightweight particle burst animation for reaction feedback.
class _ParticleBurst extends StatefulWidget {
  final Offset center;
  final Color color;
  final VoidCallback onComplete;

  const _ParticleBurst({
    required this.center,
    required this.color,
    required this.onComplete,
  });

  @override
  State<_ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<_ParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Particle positions (8 particles radiating outward)
  static const int _particleCount = 8;
  static const double _maxRadius = 30.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: List.generate(_particleCount, (index) {
            final angle = (index / _particleCount) * 2 * 3.14159;
            final radius = _animation.value * _maxRadius;
            final opacity = 1.0 - _animation.value;

            return Positioned(
              left: widget.center.dx + radius * cos(angle) - 4,
              top: widget.center.dy + radius * sin(angle) - 4,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double cos(double radians) => _cos(radians);
  double sin(double radians) => _sin(radians);

  // Lightweight trig without importing dart:math
  static double _cos(double x) {
    x = x % (2 * 3.14159);
    return 1 -
        (x * x) / 2 +
        (x * x * x * x) / 24 -
        (x * x * x * x * x * x) / 720;
  }

  static double _sin(double x) {
    x = x % (2 * 3.14159);
    return x -
        (x * x * x) / 6 +
        (x * x * x * x * x) / 120 -
        (x * x * x * x * x * x * x) / 5040;
  }
}

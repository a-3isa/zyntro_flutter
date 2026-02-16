import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/user_service.dart';
import '../utils/haptic_manager.dart';
import '../utils/responsive_utils.dart';
import 'premium_effects.dart';
import 'premium_animations.dart';

/// Streak card widget matching React Native StreakCard.
/// Shows user's workout streak with animated flame icon and friend comparisons.
class StreakCard extends StatefulWidget {
  final int days;
  final List<FriendStreakComparison>? comparisons;
  final bool showComparison;
  final VoidCallback? onTap;

  const StreakCard({
    super.key,
    required this.days,
    this.comparisons,
    this.showComparison = true,
    this.onTap,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap != null) {
      HapticManager.success();
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final comparisonData = widget.comparisons;
    final hasComparison =
        widget.showComparison &&
        comparisonData != null &&
        comparisonData.isNotEmpty;

    // Find current user rank
    String? rankText;
    if (hasComparison) {
      final currentUser = comparisonData.firstWhere(
        (c) => c.isCurrentUser,
        orElse: () => comparisonData.first, // Fallback
      );
      if (currentUser.isCurrentUser) {
        rankText = "You're #${currentUser.rank} of ${comparisonData.length}";
      }
    }

    // Responsive padding
    final isSmallScreen =
        MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
    final cardPadding = isSmallScreen ? AppSpacing.md : AppSpacing.lg;
    final comparisonHeight = isSmallScreen ? 70.0 : 80.0;

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          // Premium streak gradient background
          gradient: AppGradients.streak(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(color: AppColors.warmBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryGlow.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Streak',
                        style: TextStyle(
                          fontSize: isSmallScreen
                              ? AppFontSize.xs
                              : AppFontSize.sm,
                          color: AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Gradient text for days count
                          GradientText(
                            text: '${widget.days}',
                            colors: AppColors.streakGradient,
                            style: TextStyle(
                              fontSize: isSmallScreen
                                  ? AppFontSize.xl
                                  : AppFontSize.xxl,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' Days 🔥',
                            style: TextStyle(
                              fontSize: isSmallScreen
                                  ? AppFontSize.xl
                                  : AppFontSize.xxl,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Animated flame icon with pulsing glow
                PulsingGlow(
                  glowColor: AppColors.secondaryGlow,
                  minRadius: 8,
                  maxRadius: 20,
                  duration: const Duration(milliseconds: 1800),
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: isSmallScreen ? 48 : 56,
                      height: isSmallScreen ? 48 : 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.action.withValues(alpha: 0.2),
                            AppColors.action.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '🔥',
                          style: TextStyle(fontSize: isSmallScreen ? 28 : 32),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Comparison Section
            if (hasComparison) ...[
              const Divider(height: 24),
              if (rankText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: GradientText(
                    text: rankText,
                    colors: AppColors.primaryGradient,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ),
              SizedBox(
                height: comparisonHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: comparisonData.length,
                  separatorBuilder: (c, i) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = comparisonData[index];
                    return SlideInAnimation.fromBottom(
                      index: index,
                      duration: const Duration(milliseconds: 300),
                      delay: const Duration(milliseconds: 80),
                      child: _buildComparisonItem(item, isSmallScreen),
                    );
                  },
                ),
              ),
            ] else
              // Fallback footer
              Row(
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    "You're on fire! Keep it up!",
                    style: TextStyle(
                      fontSize: isSmallScreen ? AppFontSize.xs : AppFontSize.sm,
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(FriendStreakComparison item, bool isSmallScreen) {
    final avatarRadius = isSmallScreen ? 18.0 : 20.0;
    final containerWidth = isSmallScreen ? 52.0 : 60.0;

    if (item.isCurrentUser) {
      return GradientBorder(
        gradientColors: AppColors.primaryGradient,
        borderWidth: 2,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        padding: EdgeInsets.all(isSmallScreen ? 4 : AppSpacing.xs),
        child: Container(
          width: containerWidth,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.md - 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'You',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 9 : 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.currentStreak}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: avatarRadius,
          backgroundImage: item.photoURL != null
              ? NetworkImage(item.photoURL!)
              : null,
          backgroundColor: AppColors.primaryMuted,
          child: item.photoURL == null
              ? Text(
                  item.displayName[0].toUpperCase(),
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          '${item.currentStreak} 🔥',
          style: TextStyle(
            fontSize: isSmallScreen ? 9 : 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

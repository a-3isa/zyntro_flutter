import 'package:flutter/material.dart';

import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../services/user_service.dart';
import '../utils/haptic_manager.dart';
import '../utils/responsive_utils.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late AnimationController _countController;
  late Animation<int> _countAnim;

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

    _countController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _countAnim = IntTween(begin: 0, end: widget.days).animate(
      CurvedAnimation(parent: _countController, curve: AppCurves.premium),
    );
    _countController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _countController.dispose();
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
              color: const Color(0x2E000000),
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
                          color: AppColors.textV2Secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AnimatedBuilder(
                            animation: _countAnim,
                            builder: (context, _) => Text(
                              '${_countAnim.value}',
                              style: AppTextStyles.display.copyWith(
                                fontSize: 52,
                                color: const Color(0xFFFF8C00),
                                letterSpacing: -2,
                                height: 1,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4, left: 4),
                            child: Text('🔥', style: TextStyle(fontSize: 32)),
                          ),
                        ],
                      ),
                      Text(
                        'day streak',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textV2Tertiary,
                          letterSpacing: 0.04,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildWeekDots(),
                    ],
                  ),
                ),
                // Animated flame icon with pulsing glow
                AnimatedBuilder(
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
                        color: AppColors.action.withValues(alpha: 0.15),
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
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Comparison Section
            if (hasComparison) ...[
              const Divider(height: 24),
              if (rankText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    rankText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.sm,
                      color: AppColors.accentLime,
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
                    return _buildComparisonItem(item, isSmallScreen);
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
                      color: AppColors.textV2Secondary,
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

  Widget _buildWeekDots() {
    final now = DateTime.now();
    final weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = now.weekday - 1; // 0=Mon, 6=Sun
    final streakDays = widget.days.clamp(0, 7);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isPast = i < todayIndex;
        final isToday = i == todayIndex;
        final isDone = isPast && (todayIndex - i) <= streakDays;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + i * 40),
          curve: AppCurves.spring,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isToday
                  ? const Color(0xFFFF8C00)
                  : isDone
                      ? const Color(0x33FF8C00)
                      : AppColors.surfaceV2Elevated,
            ),
            child: Center(
              child: Text(
                weekdayLabels[i],
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday
                      ? Colors.black
                      : isDone
                          ? const Color(0xFFFF8C00)
                          : AppColors.textV2Tertiary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildComparisonItem(FriendStreakComparison item, bool isSmallScreen) {
    final avatarRadius = isSmallScreen ? 18.0 : 20.0;
    final containerWidth = isSmallScreen ? 52.0 : 60.0;

    if (item.isCurrentUser) {
      return Container(
        width: containerWidth,
        padding: EdgeInsets.all(isSmallScreen ? 4 : AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.accentLime.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppColors.accentLime, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'You',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 9 : 10,
                color: AppColors.accentLime,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.currentStreak}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 12 : 14,
                color: AppColors.textV2Primary,
              ),
            ),
          ],
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

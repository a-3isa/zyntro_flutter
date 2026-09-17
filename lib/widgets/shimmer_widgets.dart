import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../utils/animation_utils.dart';

/// Basic shimmer effect widget
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const Shimmer({
    super.key,
    required this.child,
    this.baseColor = AppColors.surfaceV2Elevated, // v2 elevated surface
    this.highlightColor = AppColors.surfaceV2Active, // v2 active (lighter)
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PerformanceMonitor.shouldReduceMotion(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
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
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: const [0.1, 0.3, 0.4],
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Shimmer loading skeleton for a buddy list item
/// Shimmer loading skeleton for a buddy list item
class BuddyListItemSkeleton extends StatelessWidget {
  const BuddyListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: AppColors.surfaceV2Elevated,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Avatar
            Shimmer(
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.backgroundV2,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer(
                    child: Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundV2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Shimmer(
                    child: Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundV2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for a post card
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const ShimmerItem(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerItem(width: 120, height: 14),
                    SizedBox(height: 6),
                    ShimmerItem(width: 80, height: 12),
                  ],
                ),
              ],
            ),
          ),
          // Image
          const ShimmerItem(
            width: double.infinity,
            height: 300,
            borderRadius: BorderRadius.zero,
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerItem(width: 100, height: 30),
                ShimmerItem(width: 60, height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton for a list of sessions
class SessionListSkeleton extends StatelessWidget {
  const SessionListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: const ShimmerItem(
            width: double.infinity,
            height: 100,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}

/// Generic Shimmer Item Helper
class ShimmerItem extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerItem({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.backgroundV2,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Shimmer skeleton for session room participants
class ParticipantRowSkeleton extends StatelessWidget {
  const ParticipantRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 4,
        separatorBuilder: (_, index) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, index) => Column(
          children: [
            const ShimmerItem(
              width: 64,
              height: 64,
              borderRadius: BorderRadius.all(Radius.circular(32)),
            ),
            const SizedBox(height: AppSpacing.sm),
            const ShimmerItem(width: 60, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for session timeline item
class TimelineItemSkeleton extends StatelessWidget {
  const TimelineItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          Column(
            children: [
              const ShimmerItem(width: 40, height: 12),
              const SizedBox(height: 4),
              Container(
                width: 2,
                height: 40,
                color: AppColors.surfaceV2Elevated,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          // Event card
          Expanded(
            child: Shimmer(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2,
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const ShimmerItem(
                          width: 24,
                          height: 24,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const ShimmerItem(width: 100, height: 14),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const ShimmerItem(width: 150, height: 14),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const ShimmerItem(width: 60, height: 12),
                        const SizedBox(width: 16),
                        const ShimmerItem(width: 60, height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full Session Room Loading Skeleton
class SessionRoomSkeleton extends StatelessWidget {
  const SessionRoomSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            color: AppColors.surfaceV2,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceV2Elevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 16),
                const ShimmerItem(width: 120, height: 18),
                const Spacer(),
                const ShimmerItem(
                  width: 32,
                  height: 32,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ],
            ),
          ),
          // Participants Area
          const SizedBox(height: AppSpacing.md),
          const ParticipantRowSkeleton(),
          const SizedBox(height: AppSpacing.lg),

          // Timeline Area
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: 5,
              itemBuilder: (_, index) => const TimelineItemSkeleton(),
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.surfaceV2,
            child: Row(
              children: [
                const ShimmerItem(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: ShimmerItem(width: double.infinity, height: 40),
                ),
                const SizedBox(width: AppSpacing.md),
                const ShimmerItem(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


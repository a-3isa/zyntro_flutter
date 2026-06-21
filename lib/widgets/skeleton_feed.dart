import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SkeletonFeedWidget extends StatefulWidget {
  const SkeletonFeedWidget({super.key});

  @override
  State<SkeletonFeedWidget> createState() => _SkeletonFeedWidgetState();
}

class _SkeletonFeedWidgetState extends State<SkeletonFeedWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (ctx, idx) => _SkeletonCard(opacity: _opacity.value),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double opacity;
  const _SkeletonCard({required this.opacity});

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.surfaceV2.withValues(alpha: opacity);
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceV2,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                _block(width: 36, height: 36, radius: 18, color: baseColor),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block(width: 100, height: 12, color: baseColor),
                    const SizedBox(height: 6),
                    _block(width: 60, height: 10, color: baseColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Title
            _block(width: double.infinity, height: 14, color: baseColor),
            const SizedBox(height: 8),
            _block(width: 200, height: 12, color: baseColor),
            const SizedBox(height: 14),
            // Stats row
            Row(
              children: [
                _block(width: 60, height: 10, color: baseColor),
                const SizedBox(width: 16),
                _block(width: 60, height: 10, color: baseColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _block({
    required double width,
    required double height,
    required Color color,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

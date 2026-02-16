import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Animation cache to reuse animation controllers and reduce memory allocation.
class AnimationCache {
  static final Map<String, AnimationController> _cache = {};

  /// Get or create a cached animation controller.
  static AnimationController getController({
    required String key,
    required Duration duration,
    required TickerProvider vsync,
  }) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final controller = AnimationController(duration: duration, vsync: vsync);
    _cache[key] = controller;
    return controller;
  }

  /// Dispose a specific cached controller.
  static void dispose(String key) {
    _cache[key]?.dispose();
    _cache.remove(key);
  }

  /// Dispose all cached controllers.
  static void disposeAll() {
    for (final controller in _cache.values) {
      controller.dispose();
    }
    _cache.clear();
  }
}

/// Performance monitor to detect low-end devices and adjust animation complexity.
class PerformanceMonitor {
  static bool? _isLowEndDevice;
  static bool? _shouldReduceMotion;

  /// Check if the device should use reduced animations.
  static bool get isLowEndDevice {
    if (_isLowEndDevice != null) return _isLowEndDevice!;

    // Heuristic: simplified check for low-end device detection
    // In production, could use SchedulerBinding for frame timing analysis
    // This is a simplified check; in production, you'd want more sophisticated detection
    _isLowEndDevice = false; // Default to full animations

    return _isLowEndDevice!;
  }

  /// Check system accessibility setting for reduced motion.
  static bool shouldReduceMotion(BuildContext context) {
    if (_shouldReduceMotion != null) return _shouldReduceMotion!;

    final mediaQuery = MediaQuery.of(context);
    _shouldReduceMotion = mediaQuery.disableAnimations;

    return _shouldReduceMotion!;
  }

  /// Reset cached values (call when device settings change).
  static void reset() {
    _isLowEndDevice = null;
    _shouldReduceMotion = null;
  }
}

/// Animation configuration that respects device capabilities and accessibility settings.
class AnimationConfig {
  final Duration duration;
  final Curve curve;
  final double scale;
  final bool enabled;

  const AnimationConfig({
    required this.duration,
    this.curve = Curves.easeInOut,
    this.scale = 1.0,
    this.enabled = true,
  });

  /// Get appropriate animation config based on device performance.
  factory AnimationConfig.adaptive({
    required Duration fullDuration,
    required Duration reducedDuration,
    Curve fullCurve = Curves.easeInOutCubic,
    Curve reducedCurve = Curves.linear,
    required BuildContext context,
  }) {
    final shouldReduce =
        PerformanceMonitor.shouldReduceMotion(context) ||
        PerformanceMonitor.isLowEndDevice;

    if (shouldReduce) {
      return AnimationConfig(
        duration: reducedDuration,
        curve: reducedCurve,
        enabled: !PerformanceMonitor.shouldReduceMotion(context),
      );
    }

    return AnimationConfig(
      duration: fullDuration,
      curve: fullCurve,
      enabled: true,
    );
  }

  /// Standard micro-interaction config.
  static AnimationConfig microInteraction(BuildContext context) {
    return AnimationConfig.adaptive(
      fullDuration: AppAnimations.microInteraction,
      reducedDuration: const Duration(milliseconds: 50),
      context: context,
    );
  }

  /// Card hover animation config.
  static AnimationConfig cardHover(BuildContext context) {
    return AnimationConfig.adaptive(
      fullDuration: AppAnimations.cardHover,
      reducedDuration: const Duration(milliseconds: 100),
      context: context,
    );
  }

  /// Page transition config.
  static AnimationConfig pageTransition(BuildContext context) {
    return AnimationConfig.adaptive(
      fullDuration: AppAnimations.pageTransition,
      reducedDuration: const Duration(milliseconds: 200),
      context: context,
    );
  }
}

/// Mixin for widgets that should respect reduced motion settings.
mixin AccessibleAnimationMixin<T extends StatefulWidget> on State<T> {
  /// Check if animations should be reduced.
  bool get shouldReduceMotion => PerformanceMonitor.shouldReduceMotion(context);

  /// Get animation duration respecting accessibility settings.
  Duration getAccessibleDuration(Duration fullDuration) {
    if (shouldReduceMotion) {
      // Return 10% of the duration for reduced motion
      return Duration(
        milliseconds: (fullDuration.inMilliseconds * 0.1).round().clamp(0, 100),
      );
    }
    return fullDuration;
  }

  /// Get animation curve respecting accessibility settings.
  Curve getAccessibleCurve(Curve fullCurve) {
    if (shouldReduceMotion) {
      return Curves.linear;
    }
    return fullCurve;
  }
}

/// Widget that conditionally applies animations based on accessibility settings.
class AccessibleAnimatedBuilder extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget child, double value)
  builder;

  const AccessibleAnimatedBuilder({
    super.key,
    required this.child,
    required this.animation,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final shouldReduce = PerformanceMonitor.shouldReduceMotion(context);

    if (shouldReduce) {
      // Return static child without animation
      return child;
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => builder(context, child!, animation.value),
      child: child,
    );
  }
}

/// Staggered animation helper for lists.
class StaggeredAnimationHelper {
  /// Calculate delay for a staggered animation based on index.
  static Duration getDelay({
    required int index,
    Duration baseDelay = const Duration(milliseconds: 50),
    int maxStagger = 10,
  }) {
    final clampedIndex = index.clamp(0, maxStagger);
    return Duration(milliseconds: baseDelay.inMilliseconds * clampedIndex);
  }

  /// Get opacity for a staggered fade-in animation.
  static double getOpacity({
    required double progress,
    required int index,
    int totalItems = 10,
  }) {
    final itemProgress = (progress * totalItems) - index;
    return itemProgress.clamp(0.0, 1.0);
  }
}

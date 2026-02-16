import 'package:flutter/material.dart';

/// Responsive breakpoints for adaptive layouts.
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1440;
}

/// Extension on BuildContext for responsive utilities.
extension ResponsiveSize on BuildContext {
  /// Get the current screen width.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get the current screen height.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Check if the current screen is mobile size.
  bool get isMobile => screenWidth < ResponsiveBreakpoints.mobile;

  /// Check if the current screen is tablet size.
  bool get isTablet =>
      screenWidth >= ResponsiveBreakpoints.mobile &&
      screenWidth < ResponsiveBreakpoints.desktop;

  /// Check if the current screen is desktop size.
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.desktop;

  /// Check if the current screen is large desktop size.
  bool get isLargeDesktop => screenWidth >= ResponsiveBreakpoints.largeDesktop;

  /// Check if the device is in landscape mode.
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  /// Check if the device is in portrait mode.
  bool get isPortrait =>
      MediaQuery.of(this).orientation == Orientation.portrait;

  /// Get responsive grid columns.
  int responsiveColumns({int mobile = 1, int tablet = 2, int desktop = 4}) {
    if (isMobile) return mobile;
    if (isTablet) return tablet;
    return desktop;
  }

  /// Get responsive padding based on screen size.
  EdgeInsets responsivePadding({
    double mobile = 8,
    double tablet = 12,
    double desktop = 16,
  }) {
    if (isMobile) return EdgeInsets.all(mobile);
    if (isTablet) return EdgeInsets.all(tablet);
    return EdgeInsets.all(desktop);
  }

  /// Get responsive horizontal padding.
  EdgeInsets responsiveHorizontalPadding({
    double mobile = 12,
    double tablet = 16,
    double desktop = 24,
  }) {
    if (isMobile) return EdgeInsets.symmetric(horizontal: mobile);
    if (isTablet) return EdgeInsets.symmetric(horizontal: tablet);
    return EdgeInsets.symmetric(horizontal: desktop);
  }

  /// Get responsive font size multiplier.
  double get responsiveFontMultiplier {
    if (isMobile) return 0.9;
    if (isTablet) return 1.0;
    return 1.1;
  }

  /// Get responsive font size based on base size.
  double responsiveFontSize(double baseSize) {
    return baseSize * responsiveFontMultiplier;
  }

  /// Get responsive icon size.
  double responsiveIconSize({
    double mobile = 20,
    double tablet = 24,
    double desktop = 28,
  }) {
    if (isMobile) return mobile;
    if (isTablet) return tablet;
    return desktop;
  }

  /// Get responsive spacing multiplier.
  double get spacingMultiplier {
    if (isMobile) return 0.85;
    if (isTablet) return 1.0;
    return 1.15;
  }

  /// Get responsive value based on screen size.
  T responsive<T>({required T mobile, T? tablet, required T desktop}) {
    if (isMobile) return mobile;
    if (isTablet) return tablet ?? mobile;
    return desktop;
  }

  /// Get adaptive font size based on scale.
  double adaptiveFontSize(double scale) => scale * responsiveFontMultiplier;

  /// Get safe area padding.
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;

  /// Get keyboard height (viewInsets.bottom).
  double get keyboardHeight => MediaQuery.of(this).viewInsets.bottom;
}

/// Adaptive spacing values based on screen size.
class AdaptiveSpacing {
  final BuildContext context;

  AdaptiveSpacing(this.context);

  /// Extra small spacing (4px base).
  double get xs => 4 * context.spacingMultiplier;

  /// Small spacing (8px base).
  double get sm => 8 * context.spacingMultiplier;

  /// Medium spacing (12px base).
  double get md => 12 * context.spacingMultiplier;

  /// Large spacing (16px base).
  double get lg => 16 * context.spacingMultiplier;

  /// Extra large spacing (24px base).
  double get xl => 24 * context.spacingMultiplier;

  /// Extra extra large spacing (32px base).
  double get xxl => 32 * context.spacingMultiplier;

  /// Extra extra extra large spacing (48px base).
  double get xxxl => 48 * context.spacingMultiplier;
}

/// Widget that rebuilds when orientation or screen size changes.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  )
  builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < ResponsiveBreakpoints.mobile;
        final isTablet =
            width >= ResponsiveBreakpoints.mobile &&
            width < ResponsiveBreakpoints.desktop;
        final isDesktop = width >= ResponsiveBreakpoints.desktop;

        return builder(context, constraints, isMobile, isTablet, isDesktop);
      },
    );
  }
}

/// Widget that provides different layouts based on screen size.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) return desktop;
    if (context.isTablet) return tablet ?? mobile;
    return mobile;
  }
}

/// Centered content with max width constraints for responsive layouts.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 800,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? context.responsiveHorizontalPadding(),
          child: child,
        ),
      ),
    );
  }
}

/// Minimum touch target size wrapper for accessibility.
class TouchTarget extends StatelessWidget {
  final Widget child;
  final double minSize;
  final VoidCallback? onTap;

  const TouchTarget({
    super.key,
    required this.child,
    this.minSize = 48, // Material guidelines recommend 48dp minimum
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: Center(child: child),
      ),
    );
  }
}

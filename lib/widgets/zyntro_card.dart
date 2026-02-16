import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/haptic_manager.dart';
import '../utils/responsive_utils.dart';

/// Card variants for premium design.
enum ZyntroCardVariant { elevated, outlined, filled, glass }

/// Card padding options.
enum ZyntroCardPadding { none, sm, md, lg }

/// Premium Card widget with glassmorphism and refined shadows.
class ZyntroCard extends StatefulWidget {
  final Widget child;
  final ZyntroCardVariant variant;
  final ZyntroCardPadding padding;
  final VoidCallback? onTap;
  final bool disabled;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? customPadding;
  final List<Color>? gradientColors;
  final bool showGlow;
  final Color? glowColor;
  final bool hapticFeedback;
  final String? semanticLabel;

  const ZyntroCard({
    super.key,
    required this.child,
    this.variant = ZyntroCardVariant.elevated,
    this.padding = ZyntroCardPadding.md,
    this.onTap,
    this.disabled = false,
    this.backgroundColor,
    this.customPadding,
    this.gradientColors,
    this.showGlow = false,
    this.glowColor,
    this.hapticFeedback = true,
    this.semanticLabel,
  });

  @override
  State<ZyntroCard> createState() => _ZyntroCardState();
}

class _ZyntroCardState extends State<ZyntroCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: AppDurations.fast,
      vsync: this,
    );
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: AppAnimations.cardPressScale).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
        );
    _rotationAnimation =
        Tween<double>(begin: 0.0, end: AppAnimations.microRotation).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
        );
    _elevationAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  EdgeInsets _getPadding(BuildContext context) {
    if (widget.customPadding != null) {
      // Safely resolve EdgeInsetsGeometry to EdgeInsets using text direction
      return widget.customPadding!.resolve(Directionality.of(context));
    }

    // Apply responsive padding adjustments
    final isSmallScreen =
        MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
    final paddingMultiplier = isSmallScreen ? 0.85 : 1.0;

    switch (widget.padding) {
      case ZyntroCardPadding.none:
        return EdgeInsets.zero;
      case ZyntroCardPadding.sm:
        return EdgeInsets.all(AppSpacing.md * paddingMultiplier);
      case ZyntroCardPadding.md:
        return EdgeInsets.all(AppSpacing.lg * paddingMultiplier);
      case ZyntroCardPadding.lg:
        return EdgeInsets.all(AppSpacing.xl * paddingMultiplier);
    }
  }

  double _getBorderRadius(BuildContext context) {
    // Scale border radius on smaller screens
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < ResponsiveBreakpoints.mobile) {
      return AppBorderRadius.lg;
    }
    return AppBorderRadius.xl;
  }

  BoxDecoration _getDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = _getBorderRadius(context);

    // Dynamic glow shadow based on pressed state and elevation animation
    List<BoxShadow>? boxShadow;
    if (widget.showGlow) {
      boxShadow = [
        BoxShadow(
          color: (widget.glowColor ?? AppColors.primaryGlow).withValues(
            alpha: _isPressed ? 0.15 : 0.25,
          ),
          blurRadius: 20 * _elevationAnimation.value,
          offset: Offset(0, 8 * _elevationAnimation.value),
        ),
      ];
    }

    switch (widget.variant) {
      case ZyntroCardVariant.elevated:
        return BoxDecoration(
          color:
              widget.backgroundColor ??
              (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark
                ? AppColors.borderDark.withValues(alpha: 0.5)
                : AppColors.borderLight,
          ),
          boxShadow:
              boxShadow ??
              [
                BoxShadow(
                  color: const Color(0x1A000000),
                  offset: Offset(0, 4 * _elevationAnimation.value),
                  blurRadius: 12 * _elevationAnimation.value,
                ),
              ],
        );
      case ZyntroCardVariant.outlined:
        return BoxDecoration(
          color:
              widget.backgroundColor ??
              (isDark
                  ? AppColors.surfaceDark.withValues(alpha: 0.5)
                  : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.5,
          ),
          boxShadow: boxShadow,
        );
      case ZyntroCardVariant.filled:
        return BoxDecoration(
          gradient: widget.gradientColors != null
              ? LinearGradient(
                  colors: widget.gradientColors!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: widget.gradientColors == null
              ? (widget.backgroundColor ??
                    (isDark
                        ? AppColors.surfaceSecondaryDark
                        : AppColors.surfaceSecondaryLight))
              : null,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow,
        );
      case ZyntroCardVariant.glass:
        return BoxDecoration(
          color:
              widget.backgroundColor ??
              (isDark
                  ? AppColors.surfaceDark.withValues(alpha: 0.6)
                  : AppColors.surfaceLight.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
          ),
          boxShadow: boxShadow,
        );
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.disabled && widget.onTap != null) {
      setState(() => _isPressed = true);
      _animController.forward();

      // Trigger haptic feedback based on variant
      if (widget.hapticFeedback) {
        if (widget.variant == ZyntroCardVariant.glass) {
          HapticManager.medium();
        } else {
          HapticManager.light();
        }
      }
    }
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animController.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.disabled && widget.onTap != null) {
      setState(() => _isPressed = false);
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = _getBorderRadius(context);

    Widget content = AnimatedBuilder(
      animation: _elevationAnimation,
      builder: (context, child) {
        return Container(
          padding: _getPadding(context),
          decoration: _getDecoration(context),
          child: widget.child,
        );
      },
    );

    // Apply glassmorphism blur for glass variant
    if (widget.variant == ZyntroCardVariant.glass) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _isPressed ? 8 : 10,
            sigmaY: _isPressed ? 8 : 10,
          ),
          child: content,
        ),
      );
    }

    // Wrap with animation
    content = AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: child,
          ),
        );
      },
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: widget.disabled ? 0.5 : 1.0,
        child: content,
      ),
    );

    // Add semantic label for accessibility
    if (widget.semanticLabel != null) {
      content = Semantics(
        label: widget.semanticLabel,
        button: widget.onTap != null,
        child: content,
      );
    }

    if (widget.onTap != null && !widget.disabled) {
      return Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: () {
            widget.onTap?.call();
            // Ensure animation resets if onTapUp doesn't fire (e.g. accessibility tap)
            Future.delayed(AppDurations.fast, () {
              if (mounted && _isPressed) {
                setState(() => _isPressed = false);
                _animController.reverse();
              }
            });
          },
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          splashColor: (widget.glowColor ?? AppColors.primary).withValues(
            alpha: 0.1,
          ),
          highlightColor: (widget.glowColor ?? AppColors.primary).withValues(
            alpha: 0.05,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}

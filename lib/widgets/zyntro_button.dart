import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/haptic_manager.dart';
import '../utils/responsive_utils.dart';

/// Button variants matching premium design system.
enum ZyntroButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
  premium,
}

/// Button sizes.
enum ZyntroButtonSize { sm, md, lg }

/// Premium Button widget with gradient fills and glow effects.
class ZyntroButton extends StatefulWidget {
  final String title;
  final VoidCallback? onPressed;
  final ZyntroButtonVariant variant;
  final ZyntroButtonSize size;
  final bool disabled;
  final bool loading;
  final bool fullWidth;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final bool enableHaptics;
  final String? semanticLabel;

  const ZyntroButton({
    super.key,
    required this.title,
    this.onPressed,
    this.variant = ZyntroButtonVariant.primary,
    this.size = ZyntroButtonSize.md,
    this.disabled = false,
    this.loading = false,
    this.fullWidth = false,
    this.leftIcon,
    this.rightIcon,
    this.enableHaptics = true,
    this.semanticLabel,
  });

  @override
  State<ZyntroButton> createState() => _ZyntroButtonState();
}

class _ZyntroButtonState extends State<ZyntroButton>
    with TickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _iconController;
  late Animation<double> _iconBounceAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: AppDurations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: AppCurves.press),
    );

    // Icon bounce animation
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _iconController, curve: Curves.easeOut));

    // Shimmer animation for loading state
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    if (widget.loading) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(ZyntroButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if (!widget.loading && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _iconController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // v2: flat fill for primary (no gradient)
  Color _getFillColor() {
    switch (widget.variant) {
      case ZyntroButtonVariant.primary:
        return _isPressed ? AppColors.userAccentDim : AppColors.userAccent;
      case ZyntroButtonVariant.secondary:
        return AppColors.surfaceV2;
      case ZyntroButtonVariant.premium:
        return AppColors.surfaceV2Elevated;
      case ZyntroButtonVariant.destructive:
        return AppColors.errorV2;
      case ZyntroButtonVariant.outline:
      case ZyntroButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _getForegroundColor() {
    switch (widget.variant) {
      case ZyntroButtonVariant.primary:
        return AppColors.backgroundV2;
      case ZyntroButtonVariant.secondary:
        return AppColors.textV2Primary;
      case ZyntroButtonVariant.destructive:
        return Colors.white;
      case ZyntroButtonVariant.premium:
        // Premium uses textDark on the navy premiumGradient background.
        return AppColors.textDark;
      case ZyntroButtonVariant.outline:
        return AppColors.userAccent;
      case ZyntroButtonVariant.ghost:
        return AppColors.textV2Secondary;
    }
  }

  List<BoxShadow>? _getBoxShadow() {
    if (widget.variant == ZyntroButtonVariant.primary && !_isPressed) {
      return [
        BoxShadow(
          color: AppColors.userAccent.withValues(alpha: 0.30),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
      ];
    }
    return null;
  }

  Border? _getBorder() {
    if (widget.variant == ZyntroButtonVariant.outline) {
      return Border.all(color: AppColors.userAccent, width: 1);
    }
    if (widget.variant == ZyntroButtonVariant.ghost) {
      return Border.all(color: AppColors.surfaceV2Active, width: 1);
    }
    return null;
  }

  EdgeInsets _getPadding(BuildContext context) {
    // Apply responsive adjustments
    final isSmallScreen =
        MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
    final multiplier = isSmallScreen ? 0.85 : 1.0;

    switch (widget.size) {
      case ZyntroButtonSize.sm:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.lg * multiplier,
          vertical: AppSpacing.sm * multiplier,
        );
      case ZyntroButtonSize.md:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.xl * multiplier,
          vertical: AppSpacing.md * multiplier,
        );
      case ZyntroButtonSize.lg:
        return EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl * multiplier,
          vertical: AppSpacing.lg * multiplier,
        );
    }
  }

  double _getMinHeight(BuildContext context) {
    // Ensure minimum touch target size of 48 for accessibility
    final baseHeight = switch (widget.size) {
      ZyntroButtonSize.sm => 40.0,
      ZyntroButtonSize.md => 52.0,
      ZyntroButtonSize.lg => 60.0,
    };
    return baseHeight.clamp(48.0, double.infinity); // Min 48 for accessibility
  }

  double _getFontSize(BuildContext context) {
    final isSmallScreen =
        MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
    final multiplier = isSmallScreen ? 0.9 : 1.0;

    return switch (widget.size) {
      ZyntroButtonSize.sm => AppFontSize.sm * multiplier,
      ZyntroButtonSize.md => AppFontSize.md * multiplier,
      ZyntroButtonSize.lg => AppFontSize.lg * multiplier,
    };
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.disabled && !widget.loading) {
      setState(() => _isPressed = true);
      _scaleController.forward();

      // Animate icon if present
      if (widget.leftIcon != null || widget.rightIcon != null) {
        _iconController.forward(from: 0);
      }

      // Trigger haptic feedback based on variant
      if (widget.enableHaptics) {
        switch (widget.variant) {
          case ZyntroButtonVariant.primary:
          case ZyntroButtonVariant.secondary:
          case ZyntroButtonVariant.premium:
            HapticManager.medium();
            break;
          case ZyntroButtonVariant.outline:
          case ZyntroButtonVariant.ghost:
            HapticManager.light();
            break;
          case ZyntroButtonVariant.destructive:
            HapticManager.heavy();
            break;
        }
      }
    }
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  Widget _buildLoadingContent(Color foregroundColor) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_shimmerAnimation.value - 1, 0),
              end: Alignment(_shimmerAnimation.value, 0),
              colors: [
                foregroundColor.withValues(alpha: 0.5),
                foregroundColor,
                foregroundColor.withValues(alpha: 0.5),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.loading;
    final foregroundColor = _getForegroundColor();
    final fillColor = _getFillColor();
    final boxShadow = _getBoxShadow();
    final border = _getBorder();
    final gradient = widget.variant == ZyntroButtonVariant.premium
        ? const LinearGradient(colors: AppColors.premiumGradient)
        : null;

    Widget content = Semantics(
      label: widget.semanticLabel ?? widget.title,
      button: true,
      enabled: !isDisabled,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedOpacity(
            duration: AppDurations.fast,
            opacity: isDisabled ? 0.4 : 1.0,
            child: AnimatedContainer(
              duration: AppAnimations.microInteraction,
              width: widget.fullWidth ? double.infinity : null,
              constraints: BoxConstraints(minHeight: _getMinHeight(context)),
              padding: _getPadding(context),
              decoration: BoxDecoration(
                color: gradient == null ? fillColor : null,
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                border: border,
                boxShadow: boxShadow,
              ),
              child: Row(
                mainAxisSize: widget.fullWidth
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.loading)
                    _buildLoadingContent(foregroundColor)
                  else ...[
                    if (widget.leftIcon != null) ...[
                      AnimatedBuilder(
                        animation: _iconBounceAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _iconBounceAnimation.value,
                            child: IconTheme(
                              data: IconThemeData(
                                color: foregroundColor,
                                size: 20,
                              ),
                              child: widget.leftIcon!,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: _getFontSize(context),
                        fontWeight: FontWeight.w700,
                        color: foregroundColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (widget.rightIcon != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      AnimatedBuilder(
                        animation: _iconBounceAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _iconBounceAnimation.value,
                            child: IconTheme(
                              data: IconThemeData(
                                color: foregroundColor,
                                size: 20,
                              ),
                              child: widget.rightIcon!,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return content;
  }
}

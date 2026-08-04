import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_text_styles.dart';

/// A consistent, polished empty-state for use across the app.
///
/// Replaces the per-screen hand-rolled empty states so that "nothing here yet"
/// always feels calm, on-brand, and reassuring rather than like an error.
///
/// A soft accent halo frames the icon, the title uses the display type scale,
/// and an optional call-to-action gives the user a clear next step. The whole
/// block fades and rises gently on first build for a touch of delight.
/// The error counterpart to [AppEmptyState].
///
/// Screens were rendering `Center(child: Text('Error: $e'))`, which shows the
/// raw exception to the user — unreadable, and capable of leaking internal
/// detail. It also left them stuck, because nothing offered a way to try again.
///
/// This keeps the same visual language as the empty state, states the problem
/// in plain language, and always offers a retry when the caller can provide
/// one. The underlying exception is deliberately never rendered; it belongs in
/// crash reporting, not on screen.
class AppErrorState extends StatelessWidget {
  /// Short headline, e.g. "Couldn't load your posts".
  final String title;

  /// Optional supporting line explaining what the user can do.
  final String? message;

  /// Called when the user taps retry. When null, no retry button is shown.
  final VoidCallback? onRetry;

  /// Whether to play the entrance animation. Disable inside tests if needed.
  final bool animate;

  const AppErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.cloud_off_rounded,
      title: title,
      message: message ?? 'Check your connection and try again.',
      accentColor: AppColors.warnV2,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
      animate: animate,
    );
  }
}

class AppEmptyState extends StatefulWidget {
  /// Glyph shown inside the accent halo.
  final IconData icon;

  /// Short, positive headline (e.g. "All clear", "No posts yet").
  final String title;

  /// Optional supporting line that explains what will appear here.
  final String? message;

  /// Accent used for the halo and icon. Defaults to the user's accent.
  final Color? accentColor;

  /// Optional CTA label. When provided with [onAction], renders a button.
  final String? actionLabel;

  /// Called when the CTA is tapped.
  final VoidCallback? onAction;

  /// Whether to play the entrance animation. Disable inside tests if needed.
  final bool animate;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accentColor, // defaults to the user's accent at build time
    this.actionLabel,
    this.onAction,
    this.animate = true,
  });

  @override
  State<AppEmptyState> createState() => _AppEmptyStateState();
}

class _AppEmptyStateState extends State<AppEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDurations.slow);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _rise = Tween<double>(
      begin: 16,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.premium));
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAction = widget.actionLabel != null && widget.onAction != null;
    final accentColor = widget.accentColor ?? AppColors.userAccent;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          ),
          child: Icon(widget.icon, size: 56, color: accentColor),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.h3.copyWith(
            fontSize: 22,
            color: AppColors.textV2Primary,
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textV2Secondary,
            ),
          ),
        ],
        if (hasAction) ...[
          const SizedBox(height: AppSpacing.xl),
          TextButton(
            onPressed: widget.onAction,
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
              ),
            ),
            child: Text(widget.actionLabel!, style: AppTextStyles.label),
          ),
        ],
      ],
    );

    // Scrollable so the block still fits at large accessibility text sizes.
    // Centred while it fits, scrolls once it does not — without this the icon,
    // title, message and action overflowed the viewport at 2x text.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, _rise.value),
                    child: child,
                  ),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

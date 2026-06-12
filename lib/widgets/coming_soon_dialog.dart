import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'zyntro_button.dart';

/// A dialog showing that a feature is coming soon.
///
/// Designed to be used with [showModalBottomSheet] as specified in the
/// feature flags plan.
class ComingSoonDialog extends StatelessWidget {
  final String featureName;
  final String? description;

  const ComingSoonDialog({
    super.key,
    required this.featureName,
    this.description,
  });

  /// Shows the coming soon dialog as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String featureName,
    String? description,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ComingSoonDialog(featureName: featureName, description: description),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Active,
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
            ),

            // Icon
            Icon(
              Icons
                  .rocket_launch_rounded, // Using rounded variant if available, or just rocket_launch
              size: 64,
              color: AppColors.userAccent,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Coming Soon!',
              style: TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.bold,
                color: AppColors.textV2Primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Feature Name
            Text(
              featureName,
              style: TextStyle(
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.w600,
                color: AppColors.userAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),

            // Description
            Text(
              description ??
                  'This feature is currently under development. Stay tuned for updates!',
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: AppColors.textV2Secondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Notify Me Button (Placeholder for now)
            ZyntroButton(
              title: 'Notify Me',
              variant: ZyntroButtonVariant.primary,
              // Full width is handled by ZyntroButton usually, or we wrap in SizedBox/Expanded if needed.
              // Assuming ZyntroButton expands or behaves like a button.
              // If it doesn't expand, we might need a width constraint.
              onPressed: () {
                // Placeholder action
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Got It Button
            ZyntroButton(
              title: 'Got It',
              variant: ZyntroButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

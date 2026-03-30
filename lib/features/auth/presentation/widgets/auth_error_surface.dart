import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class AuthErrorSurface extends StatelessWidget {
  final String message;
  final String? suggestion;
  final VoidCallback? onDismiss;

  const AuthErrorSurface({
    super.key,
    required this.message,
    this.suggestion,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'auth-error-surface',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (suggestion != null && suggestion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      suggestion!,
                      style: TextStyle(
                        color: AppColors.error.withValues(alpha: 0.95),
                        fontSize: AppFontSize.xs,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
                tooltip: 'Dismiss error',
              ),
          ],
        ),
      ),
    );
  }
}

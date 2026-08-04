import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Compact side-by-side social sign-in buttons.
///
/// The email form is the primary path, so the providers collapse to a single
/// icon row instead of two stacked full-width buttons — this keeps the whole
/// screen inside one viewport on small phones.
class SocialAuthRow extends StatelessWidget {
  const SocialAuthRow({
    super.key,
    required this.onGoogle,
    required this.onFacebook,
    required this.loadingProvider,
    required this.enabled,
  });

  final VoidCallback onGoogle;
  final VoidCallback onFacebook;

  /// 'google' | 'facebook' | null
  final String? loadingProvider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            label: 'Google',
            loading: loadingProvider == 'google',
            onTap: enabled ? onGoogle : null,
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.g_mobiledata,
                size: 20,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            label: 'Facebook',
            loading: loadingProvider == 'facebook',
            onTap: enabled ? onFacebook : null,
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.brandFacebook,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.facebook, size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceV2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceV2Elevated),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.textV2Primary,
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    // Flexible + ellipsis: "Facebook" does not fit beside the
                    // icon at the narrowest supported width.
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

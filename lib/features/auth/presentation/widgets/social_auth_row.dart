import 'package:flutter/foundation.dart';
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
    required this.onApple,
    required this.loadingProvider,
    required this.enabled,
  });

  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onApple;

  /// 'google' | 'facebook' | 'apple' | null
  final String? loadingProvider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Guideline 4.8: third-party login on iOS must include Sign in with Apple.
    final showApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final buttons = <Widget>[
      if (showApple)
        Expanded(
          child: _SocialButton(
            label: 'Apple',
            loading: loadingProvider == 'apple',
            onTap: enabled ? onApple : null,
            icon: const Icon(Icons.apple, size: 20, color: Colors.white),
          ),
        ),
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
    ];

    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          buttons[i],
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                      // Flexible + ellipsis: labels do not fit beside the icon
                      // at the narrowest supported width with three providers.
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
      ),
    );
  }
}

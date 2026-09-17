import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/zyntro_back_button.dart';

/// Public Meta / GDPR-style data deletion instructions (Z-AUTH-004).
///
/// Reachable without sign-in so Meta App Review can open the URL from the
/// Facebook Login dashboard without an account.
class DataDeletionPage extends StatelessWidget {
  const DataDeletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          Container(
            padding: AppSpacing.headerPadding(context),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                const ZyntroBackButton(),
                const SizedBox(width: 16),
                Text(
                  'Data Deletion',
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to delete your Zyntro data',
                    style: TextStyle(
                      fontSize: AppFontSize.xxl,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Effective Date: September 2026',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _section(
                    'In the app',
                    '1. Open Zyntro and sign in.\n'
                        '2. Go to Settings → Delete account.\n'
                        '3. Confirm deletion. This permanently removes your '
                        'profile, workouts, posts, follows, and media we store '
                        'for your account.',
                  ),
                  _section(
                    'If you signed in with Facebook',
                    'You can also remove Zyntro\'s access from Facebook Settings '
                        '→ Apps and Websites. To erase data Zyntro already stored, '
                        'use Delete account in the app or email privacy@zyntro.app '
                        'from the address on your Facebook-linked account.',
                  ),
                  _section(
                    'Email request',
                    'Email privacy@zyntro.app with subject "Data deletion request" '
                        'and the email or Facebook user id tied to your account. '
                        'We process verified requests within 30 days.',
                  ),
                  _section(
                    'What we delete',
                    '• Account profile and username\n'
                        '• Workout history and session participation\n'
                        '• Posts, comments, reactions, and uploaded photos\n'
                        '• Follow / block edges and notification prefs\n'
                        '• Profile photos in storage\n\n'
                        'Aggregated analytics that cannot identify you may be retained.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}
